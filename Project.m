/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  Project.m
 *
 *  Copyright (c) 2002
 *
 *  Author: Andreas Heppel <aheppel@web.de>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <AppKit/AppKit.h>

#include "AppController.h"
#include "Constants.h"
#include "Functions.h"
#include "Project.h"
#include "ProjectWindowController.h"
#include "PreferencesWindowController.h"
#include "BurnProgressController.h"

#include <Burn/ExternalTools.h>



static NSString *version = @"2.0";

@interface Project (Private)

- (BOOL) loadDataRepresentationForBurnprj: (NSData *)data;

@end

/**
 * <p>The class Project represents a project for compiling and
 * burning CDs.</p>
 * <p>It is derived from class NSDocument.</p>
 */


@implementation Project

- (id) init
{
	self = [super init];
	if (self) {
		volumeId = [[NSString alloc] initWithFormat: @"CD%@", [[NSDate date]
						descriptionWithCalendarFormat: @"%y%m%d%H%M%S" timeZone: nil locale: nil]];

		audioTracks = [[NSMutableArray alloc] init];
		dataTracks = [[NSMutableArray alloc] init];
		allCDs = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (id) initWithContentsOfFile: (NSString*)fileName ofType: (NSString*)fileType
{
	if ([fileType isEqualToString: @"isoimg"]) {
        BOOL isDir = NO;
        NSFileManager *fileMan = [NSFileManager defaultManager];

	    if ([fileName length] == 0) {
		    logToConsole(MessageStatusError, _(@"Project.noFilename"));
            goto isoimgExit;
	    }
        if (![fileMan fileExistsAtPath: fileName isDirectory: &isDir]) {
            logToConsole(MessageStatusError, [NSString stringWithFormat:
                             _(@"Project.notExist"),
                             fileName]);
            goto isoimgExit;
        }
        if (isDir) {
            logToConsole(MessageStatusError, [NSString stringWithFormat:
                             _(@"Project.isDir"),
                             fileName]);
            goto isoimgExit;
        }

        [[NSUserDefaults standardUserDefaults] setObject: fileName forKey: @"LastImage"];

        [[AppController appController] burnIsoImage: fileName];
        
isoimgExit:
        DESTROY(self);
    }else
        self = [super initWithContentsOfFile: fileName ofType: fileType];

    return self;
}

- (void) dealloc
{
	RELEASE(volumeId);
	RELEASE(audioTracks);
	RELEASE(dataTracks);
	RELEASE(allCDs);

	[super dealloc];
}


//
// access/mutation methods
//

- (NSString *) volumeId
{
	return [volumeId copy];
}

- (void) setVolumeId: (NSString *)newVolId
{
	RELEASE(volumeId);
	volumeId = [newVolId copy];
	[self updateChangeCount:NSChangeDone];
}

- (unsigned long) totalLength
{
	return (audioLength + dataLength);
}

- (int) numberOfTracks
{
	return ([audioTracks count] + [dataTracks count]);
}

- (Track *) trackOfType: (int)type atIndex: (int)index
{
	Track *track = nil;

	switch (type) {
	case TrackTypeAudio:
		track = [audioTracks objectAtIndex: index];
		break;
	case TrackTypeData:
		track = [dataTracks objectAtIndex: index];
		break;
	}

	return track;
}

- (BOOL) insertTrack: (Track *)track
			  asType: (int)type
		  atPosition: (int)pos
{
	NSString *source;
	NSString *cddbId;
	NSMutableDictionary *cdInfo;

	if (track) {
		// check whether it's an audio or data track
		if (type == TrackTypeNone) {
			if ([[track type] isEqual: @"data"] || [[track type] isEqual: @"dir"])
				type = TrackTypeData;
			else
				type = TrackTypeAudio;
		}
		if (type == TrackTypeData) {
			if ((pos < 0) || (pos > [dataTracks count]))
				pos = [dataTracks count];

			[dataTracks insertObject: track atIndex: pos];

			dataLength += [track duration];
			dataSize += [track size];
		} else {
			if ((pos < 0) || (pos > [audioTracks count]))
				pos = [audioTracks count];

			[audioTracks insertObject: track atIndex: pos];

			audioLength += [track duration];
		}

		/*
		 * Check whether the track's source is a CD.
		 * If it is, we add the CD info if we haven't done so already.
		 * If the info already exists, we increase the track count.
		 */
		if ([[track type] isEqual: @"audio:cd"]) {
			source = [track source];
			cddbId = [[source componentsSeparatedByString: @"/"] objectAtIndex: 0];
			cdInfo = [allCDs objectForKey: cddbId];
			if (!cdInfo) {
				[allCDs setObject: [NSMutableDictionary dictionaryWithObjectsAndKeys:
										_(@"Common.unknown"), @"artist",
										_(@"Common.unknown"), @"title",
										[NSNumber numberWithInt: 1], @"numberOfTracks",
										@"", @"cddbQuery",
										nil]
						forKey: cddbId];
			} else {
				NSNumber *num = [cdInfo objectForKey: @"numberOfTracks"];
				[cdInfo setObject: [NSNumber numberWithInt: [num intValue] + 1]
						forKey: @"numberOfTracks"];
			}
		}

		[track setOwner: self];
		[self updateChangeCount:NSChangeDone];

		return YES;
	}

	return NO;
}

- (BOOL) insertTrackFromFile: (NSString *)file
					  asType: (int)type
				  atPosition: (int)pos
{
	BOOL ret = NO;
	Track  *newTrack = nil;

	switch (type) {
	case TrackTypeNone:
		newTrack = [[Track alloc] initWithFile: file];
		break;
	case TrackTypeAudio:
		newTrack = [[Track alloc] initWithAudioFile: file];
		break;
	case TrackTypeData:
		newTrack = [[Track alloc] initWithDataFile: file];
		break;
	}

	if (newTrack) {
		ret = [self insertTrack: newTrack asType: type atPosition: pos];
		AUTORELEASE(newTrack);
	} else {
		logToConsole(MessageStatusError, [NSString stringWithFormat:
								_(@"Project.addingTrackFail"), file]);
	}

	return ret;
}

- (BOOL) insertTracksFromDirectory: (NSString *)directory
							asType: (int)type
						atPosition: (int)pos
						 recursive: (BOOL)rec
{
	NSFileManager *fileMan = [NSFileManager defaultManager];
	BOOL isDir;
	BOOL ret = YES;

	/*
	 * Check whether this is really a directory.
	 */
	if ([fileMan fileExistsAtPath: directory isDirectory: &isDir] && isDir) {
		NSEnumerator *enumerator;
		NSString *filePath;
		NSArray *files;

		if (rec == YES)
			enumerator = [fileMan enumeratorAtPath: directory];
		else {
			files = [fileMan directoryContentsAtPath: directory];
			enumerator = [files objectEnumerator];
		}
		/*
		 * Now walk the files/directories in the given directory. All files
		 * will be inserted as a track in the order we find them.
		 * We insert as many as possible and don't stop on errors.
		 */
		ret = NO;
		while((filePath = [enumerator nextObject])) {
			filePath = [directory stringByAppendingPathComponent: filePath];
			[fileMan fileExistsAtPath: filePath isDirectory: &isDir];
			/*
			 * If we insert directories recursively, we only insert their contents,
			 * but not the recursive directories themselves!
			 */
			if (!rec || !isDir)
				if ([self insertTrackFromFile: filePath asType: type atPosition: pos])
					// If at least on file can be inserted we report success
					ret = YES;
		}
	} else {
		return NO;
	}

	return ret;
}

- (BOOL) addTrackFromFile: (NSString *)file
{
	return [self insertTrackFromFile: file asType: TrackTypeNone atPosition: [audioTracks count]];
}


- (void) deleteTrack: (Track *)track
{
	NSString *source;
	NSString *type;
	NSString *cddbId;
	NSMutableDictionary *cdInfo;

	/*
	 * Check whether the track's source is a CD.
	 * If it is, we decrease the number of tracks in the corresponding CD info
	 * and delete the CD info if necessary.
	 */
	type = [track type];
	[track setOwner: nil];

	if ([type isEqual: @"audio:cd"]) {
		source = [track source];
		cddbId = [[source componentsSeparatedByString: @"/"] objectAtIndex: 0];
		cdInfo = [allCDs objectForKey: cddbId];
		if (cdInfo) {
			NSNumber *num = [cdInfo objectForKey: @"numberOfTracks"];
			if (([num intValue] - 1) == 0) {
				[allCDs removeObjectForKey: cddbId];
			} else {
				[cdInfo setObject: [NSNumber numberWithInt: [num intValue] - 1]
						forKey: @"numberOfTracks"];
			}
		}
	}

	if ([type isEqual: @"data"] || [type isEqual: @"dir"]) {
		unsigned index = [dataTracks indexOfObjectIdenticalTo: track];

		if (index != NSNotFound) {
			[dataTracks removeObjectAtIndex: index];
			dataLength -= [track duration];
			dataSize -= [track size];
		}
	} else {
		unsigned index = [audioTracks indexOfObjectIdenticalTo: track];

		if (index != NSNotFound) {
			[audioTracks removeObjectAtIndex: index];
			audioLength -= [track duration];
		}
	}

	[self updateChangeCount:NSChangeDone];
}

- (void) deleteTrackOfType: (int)type atIndex: (int)index
{
	Track *track = nil;

	NS_DURING
		switch (type) {
		case TrackTypeAudio:
			track = [audioTracks objectAtIndex: index];
			break;
		case TrackTypeData:
			track = [dataTracks objectAtIndex: index];
			break;
		}
	NS_HANDLER
		NS_VOIDRETURN;
	NS_ENDHANDLER

	if (track == nil)
		return;

	[track retain];
	[self deleteTrack: track];

	[track release];
}

- (void) trackTypeChanged: (Track *)track
{
	NSString *type = [track type];

    /*
     * If the track does not belong to this project/compilation,
     * we ignore the message.
     */
    if ([track owner] != self) {
        return;
    }

    /*
     * If the track is not already in the data section, it must
     * have been an audio track and vice versa. We simply move it
     * and update the time/size counters.
     */
	if ([type isEqual: @"data"] || [type isEqual: @"dir"]) {
		if ([dataTracks indexOfObjectIdenticalTo: track] == NSNotFound) {
			[dataTracks addObject: track];
			dataLength += [track duration];
			dataSize += [track size];
		    [audioTracks removeObjectIdenticalTo: track];
			audioLength -= [track duration];
        }
	} else {
		if ([audioTracks indexOfObjectIdenticalTo: track] == NSNotFound) {
			[audioTracks addObject: track];
			audioLength += [track duration];
    		[dataTracks removeObjectIdenticalTo: track];
			dataLength -= [track duration];
			dataSize -= [track size];
        }
	}
	[self updateChangeCount: NSChangeDone];
	[[[self windowControllers] objectAtIndex: 0] updateWindow];
}

//
// delegate methods
//

- (NSData *) dataRepresentationOfType: (NSString *)aType
{
	NSData *data;
	NSArray *dataArray;

	/* Remember: version must be the first data item!!! */
	dataArray = [NSArray arrayWithObjects: version, volumeId, allCDs, audioTracks, dataTracks, nil];

	data = [NSArchiver archivedDataWithRootObject: dataArray];

	return data;
}

- (BOOL) loadDataRepresentation: (NSData *)data ofType: (NSString *)aType 
{
	if ([aType isEqualToString: @"burnprj"])
		return [self loadDataRepresentationForBurnprj: data];

	NSRunAlertPanel(APP_NAME, _(@"Project.unknownType"), nil, nil, nil);
	return NO;
}

- (void)makeWindowControllers
{
	NSWindowController *projectWindowController =
		[[ProjectWindowController alloc] initWithWindowNibName: @"ProjectWindow"];

	// And we show the window...
	[[projectWindowController window] orderFrontRegardless];

	[self addWindowController: projectWindowController];

	RELEASE(projectWindowController);

	[[[self windowControllers] objectAtIndex: 0] updateWindow];
}

//
// action methods
//

//
// other methods
//

- (void) createCD: (BOOL) isoOnly
{
	BurnProgressController *apPanel;

	// save some things
	[PreferencesWindowController savePreferences];

	logToConsole(MessageStatusInfo, @"Start burning.");
	apPanel = [[BurnProgressController alloc] initWithVolumeId: volumeId
                                                    dataTracks: dataTracks
                                                   audioTracks: audioTracks
                                                        cdList: allCDs
                                                       isoOnly: isoOnly];
	if (apPanel != nil) {
		[[apPanel window] makeKeyAndOrderFront: self];
		[apPanel startProcess];
		/* If we get here we are finished. The burning however will only start. */
	}
}

//
// class methods
//

+ (NSArray*) readableTypes
{
    return [NSArray arrayWithObjects: @"burnprj", @"isoimg", nil];
}

+ (NSArray*) writableTypes
{
    return [NSArray arrayWithObjects: @"burnprj", nil];
}

+ (BOOL) isNativeType: (NSString*) aType
{
	if ([aType isEqualToString: @"burnprj"])
        return YES;
    return NO;
}

@end


@implementation Project (Private)

- (BOOL) loadDataRepresentationForBurnprj: (NSData *)data
{
	int i;
	NSArray *dataArray;
	NSString *fileVersion;

	dataArray = [NSUnarchiver unarchiveObjectWithData: data];

	/* Check version first, the decide what to do */
	fileVersion =  [dataArray objectAtIndex: 0];

	if ([fileVersion isEqual: version]) {
		RELEASE(volumeId);
		volumeId = [dataArray objectAtIndex: 1];
		RETAIN(volumeId);

		RELEASE(allCDs);
		allCDs = [dataArray objectAtIndex: 2];
		RETAIN(allCDs);

		RELEASE(audioTracks);
		audioTracks = [dataArray objectAtIndex: 3];
		RETAIN(audioTracks);

		RELEASE(dataTracks);
		dataTracks = [dataArray objectAtIndex: 4];
		RETAIN(dataTracks);

		audioLength = dataLength = dataSize = 0;
		for (i = [dataTracks count]-1; i >= 0; i--) {
			Track *track = [dataTracks objectAtIndex: i];

			dataLength += [track duration];
			dataSize += [track size];
			[track setOwner: self];
		}
		for (i = [audioTracks count]-1; i >= 0; i--) {
			Track *track = [audioTracks objectAtIndex: i];

			audioLength += [track duration];
			[track setOwner: self];
		}
	} else {
		NSRunAlertPanel(APP_NAME, _(@"Project.unknownVers"), nil, nil, nil);
		return NO;
	}

	return YES;
}


@end
