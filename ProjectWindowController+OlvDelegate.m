/* vim: set ft=objc ts=4 nowrap: */
/*
 *	ProjectWindowController.m
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


@implementation ProjectWindowController (OutlineViewDelegation)

//
// outline view delegate methods
//
- (id) outlineView: (NSOutlineView *)outlineView
			 child: (int)index
			ofItem: (id)item
{
	// root object
	if (!item) {
		return cdRoot;
	}

	if (item == cdRoot) {
		return (index==0)?dataRoot:audioRoot;
	}
 
	if (item == audioRoot) {
		return 	[[self document] trackOfType: TrackTypeAudio atIndex: index];
	}
 
	if (item == dataRoot) {
		return 	[[self document] trackOfType: TrackTypeData atIndex: index];
	}

	return nil;
}

- (BOOL) control: (id) control textShouldBeginEditing: (NSText *)textObject
{
	if ([[textObject string] isEqual: _(@"ProjectWindowController.audioTracks")] ||
		[[textObject string] isEqual: _(@"ProjectWindowController.dataTracks")]) {
		return NO;
	}
	return YES;
}

- (BOOL) outlineView: (NSOutlineView *)outlineView
	isItemExpandable: (id) item
{
	if (item == cdRoot || item == audioRoot || item == dataRoot) {
		return YES;
	}

	return NO;
}

/**
 * Format the text in the cell
 */
- (void) outlineView: (NSOutlineView *)outlineView
     willDisplayCell: (id)aCell
      forTableColumn: (NSTableColumn *)tableColumn
                item: (id)item
{
	if (item == cdRoot || item == audioRoot || item == dataRoot){
		[aCell setFont: [NSFont boldSystemFontOfSize: 0]];
	} else {
		[aCell setFont: [NSFont systemFontOfSize: 0]];
	}

}

/**
 * Provide an image for the cell
 */
- (void) outlineView: (NSOutlineView *)outlineView
     willDisplayOutlineCell: (id)aCell
      forTableColumn: (NSTableColumn *)tableColumn
                item: (id)item
{
	if ([item isKindOfClass: [Track class]]) {
		if ([[tableColumn identifier] isEqual: @"Track"]) {
			if ([[(Track *)item type] isEqual: @"audio:cd"]) {
				[aCell setImage: [[NSImage imageNamed: @"iconAudioCDSm.tiff"] copy]];
			} else {
				NSImage *image;

				image = [[[NSWorkspace sharedWorkspace] iconForFile:
										[(Track *)item source]] copy];
				[image setScalesWhenResized: YES];
				[image setSize: NSMakeSize(16,16)];
				[aCell setImage: image];
				RELEASE(image);
			}
		}
		return;
	}
}

- (int) outlineView: (NSOutlineView *)outlineView 
		numberOfChildrenOfItem: (id)item
{
	if (!item) {
		return 1;
	}
	// Root, always two elements.
	if (item == cdRoot) {
		[trackView expandItem: cdRoot];
		return 2;
	}
	if (item == audioRoot) {
		return [[self document] numberOfAudioTracks];
	}
	if (item == dataRoot) {
		return [[self document] numberOfDataTracks];
	}
	return 0;
}

- (id) outlineView: (NSOutlineView *)outlineView 
	objectValueForTableColumn: (NSTableColumn *)tableColumn 
					   byItem: (id)item
{
	if (item == cdRoot) {
//		if ([[tableColumn identifier] isEqual: @"Index"])
//			return nil;
		if ([[tableColumn identifier] isEqual: @"Length"]) {
			double size;

			size = framesToSize([[self document] totalLength]);

			if (size < (1024.*1024.*0.25))
				return [NSString stringWithFormat: _(@"Common.kB"), size/1024.];
			return [NSString stringWithFormat: _(@"Common.MB"), size/1024./1024.];
		}
		return [[self document] volumeId];
	}

	if (item == audioRoot) {
//		if ([[tableColumn identifier] isEqual: @"Index"])
//			return nil;
		if ([[tableColumn identifier] isEqual: @"Length"]) {
			long totalTime;		// Frames
			totalTime = [[self document] audioLength];
			return framesToString(totalTime);
		}
		return _(@"ProjectWindowController.audioTracks");
	}
	if (item == dataRoot) {
//		if ([[tableColumn identifier] isEqual: @"Index"])
//			return nil;
		if ([[tableColumn identifier] isEqual: @"Length"]) {
			double size;

			size = [[self document] dataSize];

			if (size < (1024.*1024.*0.25))
				return [NSString stringWithFormat: _(@"Common.kB"), size/1024.];
			return [NSString stringWithFormat: _(@"Common.MB"), size/1024./1024.];
		}

		return _(@"ProjectWindowController.dataTracks");
	}

	if ([item isKindOfClass: [Track class]]) {
#if 0
		if ([[tableColumn identifier] isEqual: @"Index"]) {
			int audioRow = [outlineView rowForItem: audioRoot];
			int dataRow = [outlineView rowForItem: dataRoot];
			int myRow = [outlineView rowForItem: item];
			if (myRow < audioRow)
				return [NSString stringWithFormat: @"%d", myRow - dataRow];

			return [NSString stringWithFormat: @"%d", myRow - audioRow];
		}
#endif
		if ([[tableColumn identifier] isEqual: @"Length"]) {
			if ([[(Track*)item type] isEqual: @"data"] || [[(Track*)item type] isEqual: @"dir"]){
				double size = [(Track*)item size];

				if (size < (1024.*1024.*0.25))
					return [NSString stringWithFormat: _(@"Common.kB"), size/1024.];
				return [NSString stringWithFormat: _(@"Common.MB"), size/1024./1024.];
			} else {
				return framesToString([(Track*)item duration]);
			}
		}
		return [(Track*)item description];
	}

	return nil;
}

- (void) outlineView: (NSOutlineView *)outlineView
	setObjectValue: (id) newObjectValue
	forTableColumn: (NSTableColumn *)tableColumn
			byItem: (id)item
{
	if (item == cdRoot) {
		[[self document] setVolumeId: newObjectValue];
		return;
	}
	if ([item isKindOfClass: [Track class]]) {
		[(Track*)item setDescription: newObjectValue];

		[[self document] updateChangeCount:NSChangeDone];
	}
}

@end


