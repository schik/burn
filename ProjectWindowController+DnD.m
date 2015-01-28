/* vim: set ft=objc ts=4 sw=4 et nowrap: */
/*
 *	ProjectWindowController+DnD.m
 *
 *	Copyright (c) 2002
 *
 *	Author: Andreas Heppel <aheppel@web.de>
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include "ProjectWindowController.h"

#include "Constants.h"
#include "Functions.h"
#include "AppController.h"
#include "Project.h"

#include <Burn/ExternalTools.h>
#include "ExtendedOutlineView.h"


@implementation ProjectWindowController (DragAndDrop)

- (NSArray *) getSourcePaths: (NSPasteboard *)pBoard
{
	NSArray *sourcePaths = nil;

	// We retrieve property list of files from paste board
	sourcePaths = [pBoard propertyListForType: NSFilenamesPboardType];

	if (!sourcePaths) {
		NSData *pbData = [pBoard dataForType: NSFilenamesPboardType];

		if (pbData) {
			sourcePaths = [NSUnarchiver unarchiveObjectWithData: pbData];
		}
	}
	return sourcePaths;
}

- (IBAction) copy: (id)info
{
	NSNumber *row;
	NSMutableArray *items = [NSMutableArray new];
	NSEnumerator *rowEnumerator;
	NSPasteboard *pboard;
	int selRow, audioRow, dataRow, cdRow;

	selRow = [trackView selectedRow];
	audioRow = [trackView rowForItem: audioRoot];
	dataRow = [trackView rowForItem: dataRoot];
	cdRow = [trackView rowForItem: cdRoot];

	if (([trackView numberOfSelectedRows] == 0) ||
		(([trackView numberOfSelectedRows] == 1) &&
		((selRow == audioRow) || (selRow == dataRow) || (selRow == cdRow)))) {
		NSBeep();
		return;
	}

	pboard = [NSPasteboard generalPasteboard];
	rowEnumerator = [trackView selectedRowEnumerator];
	while ((row = [rowEnumerator nextObject])) {
		id item = [trackView itemAtRow: [row intValue]];
		if ((item != audioRoot) && (item != dataRoot) && (item != cdRoot))
			[items addObject: item];
	}

	/*
	 * We use the same method here for starting a drag operation.
	 * Since this operation maintains a list of tracks to be deleted
	 * from the project (in case we move the tracks only up or downward),
	 * we must release this list.
	 */
	[self outlineView: trackView writeItems: items toPasteboard: pboard];
	[items release];
	[self removeMovedTracks: NO];
}

- (IBAction) cut: (id)info
{
	int i;
	int selRow, audioRow, dataRow, cdRow;

	selRow = [trackView selectedRow];
	audioRow = [trackView rowForItem: audioRoot];
	dataRow = [trackView rowForItem: dataRoot];
	cdRow = [trackView rowForItem: cdRoot];

	if (([trackView numberOfSelectedRows] == 0) ||
		(([trackView numberOfSelectedRows] == 1) &&
		((selRow == audioRow) || (selRow == dataRow) || (selRow == cdRow)))) {
		NSBeep();
		return;
	}

	[self copy: nil];

	/*
	 * We iterate backwards through the field since we need to
	 * remove objects using their index and thus change the array.
	 */
	for (i = [trackView numberOfRows]-1; i > audioRow; i--) {
		if ([trackView isRowSelected: i]) {
			[[self document] deleteTrackOfType: TrackTypeAudio atIndex: i-audioRow-1];
		}
	}
	for (i = audioRow-1; i > dataRow; i--) {
		if ([trackView isRowSelected: i]) {
			[[self document] deleteTrackOfType: TrackTypeData atIndex: i-dataRow-1];
		}
	}

	[trackView reloadData];
	[trackView deselectAll: self];

	[self displayTotalTime];
}

- (IBAction) paste: (id)info
{
	int index, audioRow, dataRow;
	NSArray *allTypes;
	NSPasteboard *pboard;
	id item;

	pboard = [NSPasteboard generalPasteboard];

	index = [trackView selectedRow];
	audioRow = [trackView rowForItem: audioRoot];
	dataRow = [trackView rowForItem: dataRoot];

	if (index >= audioRow) {
		index -= audioRow;
		item = audioRoot;
	} else if (index >= dataRow) {
		item = dataRoot;
		index -= dataRow;
	} else {
		return;
	}

	allTypes = [pboard types];

	if ([allTypes containsObject: BurnTrackPboardType]) {
		[self acceptBurnTracks: pboard forIndex: index andItem: item];
	} else if ([allTypes containsObject: AudioCDPboardType]) {
		[self acceptAudioCDTracks: pboard forIndex: index andItem: item];
	} else {
		return;
	}
  
	return;
}


//
// NSOutlineDataSource Drag and drop
//
- (NSDragOperation) outlineView: (NSOutlineView *)outlineView
				   validateDrop: (id <NSDraggingInfo>)info
				   proposedItem: (id)item
			 proposedChildIndex: (int)index

{
	NSDragOperation sourceDragMask;
	NSArray *allTypes;

    // Don't accept drops if we are currently processing
    // files in the background
    if (workerThreadRunning)
		goto out_none;

	if (item == nil)
		goto out_none;

	if ((item == cdRoot) && (index == 0))
		goto out_none;

	sourceDragMask = [info draggingSourceOperationMask];

	/*
	 * We don't allow to copy inside the same CD compilation.
	 * Only move.
	 */
	if (([info draggingSource] == trackView) &&
			(sourceDragMask == NSDragOperationCopy))
		goto out_none;

	allTypes = [[info draggingPasteboard] types];

	if ([allTypes containsObject: BurnTrackPboardType]) {
		int i, count;
		int trackType = TrackTypeNone;
		NSDictionary *propertyList;
		NSArray *trackProperties;

		// We retrieve property list of cds/tracks from paste board
		propertyList = [[info draggingPasteboard] propertyListForType: BurnTrackPboardType];

		if (!propertyList)
			goto out_none;

		trackProperties = [propertyList objectForKey: @"tracks"];

		// we need at least tracks
		if (!trackProperties)
			goto out_none;

		// adjust the index according to the section
		if (item == audioRoot) {
			trackType = TrackTypeAudio;
		} else if (item == dataRoot)  {
			trackType = TrackTypeData;
		} else if (item == cdRoot) {
			switch (index) {
			case 1:
				trackType = TrackTypeData;
				break;
			case 2:
				trackType = TrackTypeAudio;
				break;
			}
		}
		// we cannot insert CD tracks into the data section
		// or directories into the audio part
		count = [trackProperties count];
		for (i = count - 1; i >= 0; i--) {
			NSDictionary *aDictionary = (NSDictionary*)[trackProperties objectAtIndex: i];
			NSString *type = [aDictionary objectForKey: @"type"];

			if ([type isEqual: @"audio:cd"] && (trackType == TrackTypeData))
				goto out_none;

			if ([type isEqual: @"dir"] && (trackType != TrackTypeData))
				goto out_none;
		}
	} else if ([allTypes containsObject: AudioCDPboardType]) {
		/*
		 * Audio CD tracks can only be dragged to the audio section,
		 * and we don't allow copying (makes no sense).
		 */
		if ((item == dataRoot) || ((item == cdRoot) && (index <= 1))) {
			goto out_none;
		} else if (sourceDragMask & NSDragOperationCopy) {
			goto out_none;
		}
	} else if ([allTypes containsObject: NSFilenamesPboardType]) {
		/*
		 * We accept only .wav, .au and the registered audio types
		 * for the audio section.
		 */
		if ((item == audioRoot) || ((item == cdRoot) && (index == 2))) {
			int i, count;
			NSFileManager *fileMan = nil;
			NSArray *sourcePaths = [self getSourcePaths: [info draggingPasteboard]];
			if (!sourcePaths) {
				goto out_none;
			}

			fileMan = [NSFileManager defaultManager];
			count = [sourcePaths count];

			for (i = count - 1; i >= 0; i--) {
				NSString *sourceFile;
				BOOL isDir;

				sourceFile = [sourcePaths objectAtIndex: i];
				/*
				 * We bail out onthe first file without a known extension.
				 */
				if (![fileMan fileExistsAtPath: sourceFile isDirectory: &isDir]) {
					goto out_none;
				} else if (!isDir && !isAudioFile(sourceFile)) {
					goto out_none;
				}
			}
		}
	}

	if ((sourceDragMask & NSDragOperationPrivate) == NSDragOperationPrivate) {
		return NSDragOperationPrivate;
	} else if ((sourceDragMask & NSDragOperationCopy) == NSDragOperationCopy) {
		return NSDragOperationCopy;
	}		

out_none:
	return NSDragOperationNone;
}



- (BOOL) outlineView: (NSOutlineView *)outlineView
		  acceptDrop: (id <NSDraggingInfo>)info
				item: (id)item
		  childIndex: (int)index
{
	BOOL ret = NO;
	NSArray *allTypes;

    // Don't accept drops if we are currently processing
    // files in the background
    if (workerThreadRunning)
		return ret;

	allTypes = [[info draggingPasteboard] types];

	if ([allTypes containsObject: NSFilenamesPboardType]) {
		ret = [self acceptFilenames: [info draggingPasteboard]
						byOperation: [info draggingSourceOperationMask]
						   forIndex: index andItem: item];
	} else if ([allTypes containsObject: AudioCDPboardType]) {
		ret = [self acceptAudioCDTracks: [info draggingPasteboard] forIndex: index andItem: item];
	} else if ([allTypes containsObject: BurnTrackPboardType]) {
		ret = [self acceptBurnTracks: [info draggingPasteboard] forIndex: index andItem: item];
	}
	return ret;
}

- (BOOL) acceptFilenames: (NSPasteboard *)pBoard
			 byOperation: (NSDragOperation)dragOperation
				forIndex: (int)index
				 andItem: (id)item
{
	BOOL ret = YES;
	int trackType = TrackTypeNone;

	// We retrieve property list of files from paste board
	NSArray *sourcePaths = [self getSourcePaths: pBoard];

	if (!sourcePaths) {
		return NO;
	}

	// adjust the index according to the section
	if (item == audioRoot) {
		trackType = TrackTypeAudio;
		if ((index < 0) || (index > [[self document] numberOfAudioTracks]))
			index = [[self document] numberOfAudioTracks];
	} else if (item == dataRoot)  {
		trackType = TrackTypeData;
		if ((index < 0) || (index > [[self document] numberOfDataTracks]))
			index = [[self document] numberOfDataTracks];
	} else if (item == cdRoot) {
		switch (index) {
		case 1:
			trackType = TrackTypeData;
			index = [[self document] numberOfDataTracks];
			break;
		case 2:
			trackType = TrackTypeAudio;
			index = [[self document] numberOfAudioTracks];
			break;
		default:
			trackType = TrackTypeData;
			index = [[self document] numberOfDataTracks];
			break;
		}
	} else {
		index = 0;
	}

	ret = [self addFiles: sourcePaths
                  ofType: trackType
                 atIndex: index
               recursive: (NSDragOperationCopy == dragOperation)];

	return ret;
}

- (BOOL) acceptAudioCDTracks: (NSPasteboard *)pBoard
                    forIndex: (int)index
                     andItem: (id)item
{
	NSDictionary *cds = nil;
    BOOL success = YES;

	// CD tracks can be added to audio only
	if ((item == dataRoot) || ((item == cdRoot) && (index == 1))) {
		return NO;
    }

	// We retrieve property list of files from paste board
	cds = [pBoard propertyListForType: AudioCDPboardType];

	if (!cds) {
		return NO;
	}

	// adjust the index according to the section
	// we accept CD tracks for the audio part only
	if ((item == cdRoot) || (item == nil))
		index = [[self document] numberOfAudioTracks];
	else if ((index < 0) || (index > [[self document] numberOfAudioTracks]))
		index = [[self document] numberOfAudioTracks];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                cds, @"cds",
                                [NSNumber numberWithInt: index], @"index",
                                nil];
    RETAIN(dict);

    [self runInThread: @selector(addAudioCDTracksThread:)
               target: self
             userData: dict
              message: _(@"ProjectWindowController.addingAudioCD")];
    success = [(NSNumber *)[dict objectForKey: @"returnValue"] boolValue];
    RELEASE(dict);

	[self expandAllItems];
	[self updateWindow];

	// update the audio CD panel
	if ([[self window] isKeyWindow])
		[self updateAudioCDPanel];

	return success;
}

- (BOOL) acceptBurnTracks: (NSPasteboard *)pBoard
				 forIndex: (int)index
				  andItem: (id)item
{
	int i, count;
	int trackType = TrackTypeNone;
	NSDictionary *propertyList;
	NSDictionary *cdProperties;
	NSArray *trackProperties;
	NSArray *cdKeys;
    BOOL success = YES;

	// We retrieve property list of cds/tracks from paste board
	propertyList = [pBoard propertyListForType: BurnTrackPboardType];

	if (!propertyList) {
		return NO;
	}

	cdProperties = [propertyList objectForKey: @"cdinfo"];
	trackProperties = [propertyList objectForKey: @"tracks"];

	// we need at least tracks
	if (!trackProperties || !cdProperties) {
		return NO;
	}

	// adjust the index according to the section
	if (item == audioRoot) {
		trackType = TrackTypeAudio;
		if ((index < 0) || (index > [[self document] numberOfAudioTracks]))
			index = [[self document] numberOfAudioTracks];
	} else if (item == dataRoot)  {
		trackType = TrackTypeData;
		if ((index < 0) || (index > [[self document] numberOfDataTracks]))
			index = [[self document] numberOfDataTracks];
	} else if (item == cdRoot) {
		switch (index) {
		case 1:
			trackType = TrackTypeData;
			index = [[self document] numberOfDataTracks];
			break;
		case 2:
			trackType = TrackTypeAudio;
			index = [[self document] numberOfAudioTracks];
			break;
		}
	} else {
		index = 0;
	}

	// we cannot insert CD tracks into the data section
	// or directories into the audio part
	count = [trackProperties count];
	for (i = count - 1; i >= 0; i--) {
		NSDictionary *aDictionary = (NSDictionary*)[trackProperties objectAtIndex: i];
		NSString *type = [aDictionary objectForKey: @"type"];

		if ([type isEqual: @"audio:cd"] && (trackType == TrackTypeData))
			return NO;

		if ([type isEqual: @"dir"] && (trackType != TrackTypeData))
			return NO;
	}

	// first, add the tracks
	count = [trackProperties count];
	for (i = count - 1; i >= 0; i--) {
		// We retrieve track from property list
		NSDictionary *aDictionary;
		Track *track;
		NSString *type;

		aDictionary = (NSDictionary*)[trackProperties objectAtIndex: i];
		type = [aDictionary objectForKey: @"type"];

		track = [[Track alloc] initWithProperties: [NSArray arrayWithObjects:
														[aDictionary objectForKey: @"description"],
														[aDictionary objectForKey: @"source"],
														[NSNumber numberWithInt: [[aDictionary objectForKey: @"duration"] intValue]],
														nil]
										  forKeys: [NSArray arrayWithObjects:
														@"description", @"source", @"duration", nil]];

		if (track != nil) {
			// now adjust the track type if necessary
			switch (trackType) {
			case TrackTypeAudio:
				// if the track is inserted as audio we need to change it only
				// if it was raw data
				if ([type isEqual: @"data"]) {
					NSString *ext = [[[aDictionary objectForKey: @"source"] pathExtension] lowercaseString];
					if (isAudioFile([aDictionary objectForKey: @"source"])) {
						NSString *s = [NSString stringWithFormat: @"audio:%@", ext];
						[track setType: s];
					} else {
						RELEASE(track);
						return NO;
					}
				} else
					[track setType: type];
				break;
			case TrackTypeData:
			case TrackTypeNone:
				[track setType: type];
				break;
			}

			if ([[self document] insertTrack: track asType: trackType atPosition: index] == NO) {
				logToConsole(MessageStatusError, [NSString stringWithFormat:
									_(@"ProjectWindowController.addTrackFail"), [track description]]);
                success = NO;
			}
		}
    }

	// now walk the list of CDs and update the project data
	cdKeys = [cdProperties allKeys];
	count = [cdKeys count];
	for (i = 0; i < count; i++) {
		NSDictionary *cdInfo = [cdProperties objectForKey: [cdKeys objectAtIndex: i]];
		[[self document] setCDInfo: [cdKeys objectAtIndex: i] : [cdInfo objectForKey: @"artist"]: [cdInfo objectForKey: @"title"]];
	}
 
    [trackView expandItem: cdRoot];
	if (trackType == TrackTypeAudio)
		[trackView expandItem: audioRoot];
	else if (trackType == TrackTypeData)
		[trackView expandItem: dataRoot];
	else {
		[trackView expandItem: audioRoot];
		[trackView expandItem: dataRoot];
	}
  
	// We refresh the table view
	[self updateWindow];

	return success;
}


//
// NSTableDataSource Drag and drop
//
- (BOOL) outlineView: (NSOutlineView *)outlineView
		  writeItems: (NSArray *)items
		toPasteboard: (NSPasteboard *)pboard
{
	int i;
	NSMutableDictionary *propertyList;
	NSMutableArray *trackProperties;
	NSMutableDictionary *cdProperties;
 
	// check whether all items are valid
	for (i = 0; i < [items count]; i++) {
		id item = [items objectAtIndex: i];

		if ((item == audioRoot) || (item == dataRoot) || (item == cdRoot))
			return NO;
	}

	propertyList = [[NSMutableDictionary alloc] initWithCapacity: 2];
	cdProperties = [NSMutableDictionary dictionary];
	trackProperties = [[NSMutableArray alloc] initWithCapacity: [items count]];
	movedTracks = [[NSMutableArray alloc] initWithCapacity: [items count]];
 
	for (i = 0; i < [items count]; i++) {
		NSString *source;
		NSString *type;
		Track *track = (Track*)[items objectAtIndex: i];

		// For each implicated row, retrieve audio track and insert its
		// raw representation in a dictionary with keys: 'source', 'description' and 'duration'
		NSMutableDictionary *trackDict = [[NSMutableDictionary alloc] initWithCapacity: 4];

		source = [track source];
		type = [track type];
		if ([type isEqual: @"audio:cd"]) {
			// For each CD involved in this operation insert its representation
			// in a dictionary with keys: 'artist' and 'title'
			NSMutableDictionary *cdDict = [[NSMutableDictionary alloc] initWithCapacity: 2];

			NSString *cddbId = [[source componentsSeparatedByString: @"/"] objectAtIndex: 0];

			if ([cdProperties objectForKey: cddbId] == nil) {
				NSDictionary *cdInfo = [[self document] cdForKey: cddbId];
				[cdDict setObject: [cdInfo objectForKey: @"artist"] forKey: @"artist"];
				[cdDict setObject: [cdInfo objectForKey: @"title"] forKey: @"title"];
				[cdProperties setObject: cdDict forKey: cddbId];
				RELEASE(cdDict);
			}
		}

		[trackDict setObject: source forKey: @"source"];
		[trackDict setObject: type forKey: @"type"];
		[trackDict setObject: [track description] forKey: @"description"];
		[trackDict setObject: [[track propertyForKey: @"duration"] description] forKey: @"duration"];

		[trackProperties addObject: trackDict];

		// remember the original position in table
		[movedTracks addObject: track];

		RELEASE(trackDict);
    }

	// add properties for tracks and cd to proplist
	[propertyList setObject: cdProperties forKey: @"cdinfo"];
	[propertyList setObject: trackProperties forKey: @"tracks"];

	// Set property list of paste board
	[pboard declareTypes: [NSArray arrayWithObject: BurnTrackPboardType] owner: self];
	[pboard setPropertyList: propertyList forType: BurnTrackPboardType];
	RELEASE(propertyList);
  
	return YES;
}

- (id)validRequestorForSendType: (NSString *)sendType
                     returnType: (NSString *)returnType
{
	if (!sendType && [returnType isEqual: AudioCDPboardType]) {
		return self;
	}
	return nil;
}

- (BOOL)readSelectionFromPasteboard: (NSPasteboard *)pboard
{
    NSArray *types;

    types = [pboard types];
    if ([types containsObject: AudioCDPboardType] == NO) {
        return NO;
    }

    return [self acceptAudioCDTracks: pboard forIndex: -1 andItem: audioRoot];
}

- (void) removeMovedTracks: (BOOL)flag
{
	/*
	 * If the dragging source was our own track table, we perform
	 * a move operation, i.e. we remove the dragged tracks from their
	 * original position in the table.
	 */
	if (flag == YES) {
		int i;
		for (i = 0; i < [movedTracks count]; i++){
			[[self document] deleteTrack: [movedTracks objectAtIndex: i]];
		}
		[trackView deselectAll: self];
		[self updateWindow];
	}
	RELEASE(movedTracks);
	movedTracks = nil;
}

@end


