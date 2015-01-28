/* vim: set ft=objc ts=4 nowrap: */
/*
 *  ExtendedOutlineView.h
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
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "ExtendedOutlineView.h"
#include "Track.h"
#include "Constants.h"
#include "Functions.h"
#include "ProjectWindowController.h"

@implementation ExtendedOutlineView

- (NSRect) frameOfOutlineCellAtRow: (NSInteger)row
{
	NSRect frameRect;
	int i;

	for (i = 0; i < _numberOfColumns; i++) {
		NSTableColumn *tb = [_tableColumns objectAtIndex: i];
		if ([[tb identifier] isEqual: @"Track"]) {
			break;
		}
	}
	frameRect = [self frameOfCellAtColumn: i row: row];
  
	if (_indentationMarkerFollowsCell) {
		frameRect.origin.x += _indentationPerLevel * [self levelForRow: row];
	}

	if (![self isExpandable: [self itemAtRow: row]]) {
		// These items are tracks, for which we display the workspace icon.
		// Drawing frame rect must adjusted accordingly.
		frameRect.origin.y += 5;
 	}

	return frameRect;
}

- (NSImage *) dragImageForRows: (NSArray *) dragRows
                         event: (NSEvent *) dragEvent 
               dragImageOffset: (NSPoint *) dragImageOffset
{
	if ([dragRows count] > 1) {
		int i;
		// if there is at least one data track we use the data icon
		for (i = 0; i < [dragRows count]; i++) {
			id item = [self itemAtRow: [[dragRows objectAtIndex: i] intValue]];
		if ([[(Track*)item type] isEqual: @"data"] || [[(Track*)item type] isEqual: @"dir"])
			return [NSImage imageNamed: @"iconDnDMulti.tiff"];
		}
		// otherwise we use the audio icon
		return [NSImage imageNamed: @"iconDnDAudioMulti.tiff"];
	} else {
		id item = [self itemAtRow: [[dragRows objectAtIndex: 0] intValue]];
		if ([[(Track*)item type] isEqual: @"data"] || [[(Track*)item type] isEqual: @"dir"])
			return [NSImage imageNamed: @"iconDnD.tiff"];
		else
			return [NSImage imageNamed: @"iconDnDAudio.tiff"];
	}

	return [super dragImageForRows: dragRows
					event: dragEvent 
					dragImageOffset: dragImageOffset];
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	/*
	 * Between our own windows we allow copy and move, but
	 * we do not allow to drag outside, other than to remove the item.
	 */
	if (isLocal == YES)
		return NSDragOperationCopy | NSDragOperationPrivate;
	else
		return NSDragOperationNone;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	[super draggingEntered: sender];
	return [self validateDragging: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	[super draggingUpdated: sender];
	return [self validateDragging: sender];
}

- (NSDragOperation) validateDragging: (id <NSDraggingInfo>)sender
{
	NSDragOperation sourceDragMask;
	NSArray *allTypes;

	sourceDragMask = [sender draggingSourceOperationMask];
	
	/*
	 * We don't allow to copy inside the same project.
	 * Only move.
	 */
	if (([sender draggingSource] == self) &&
			(sourceDragMask == NSDragOperationCopy))
		return NSDragOperationNone;

	/*
	 * We need at least one file in the selection otherwise we refuse.
	 */
	allTypes = [[sender draggingPasteboard] types];

	if ([allTypes containsObject: NSFilenamesPboardType]) {
		// We retrieve property list of files from paste board
		NSArray *sourcePaths = [[sender draggingPasteboard] propertyListForType: NSFilenamesPboardType];

		if (!sourcePaths) {
			NSData *pbData = [[sender draggingPasteboard] dataForType: NSFilenamesPboardType];
			if (pbData) {
				sourcePaths = [NSUnarchiver unarchiveObjectWithData: pbData];
			}
		}
		if (0 == [sourcePaths count]) {
			return NSDragOperationNone;
		}
	}	

	if ((sourceDragMask & NSDragOperationPrivate) == NSDragOperationPrivate) {
		return NSDragOperationPrivate;
	} else if ((sourceDragMask & NSDragOperationCopy) == NSDragOperationCopy) {
		return NSDragOperationCopy;
	}
	return NSDragOperationNone;
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
    BOOL result = [super performDragOperation: sender];

    if ([[self dataSource] respondsToSelector: @selector(expandAllItems)]) {
        [[self dataSource] expandAllItems];
    }

    return result;
}

- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
	id dragSource;
	NSDragOperation sourceDragMask;
	
	sourceDragMask = [sender draggingSourceOperationMask];
	dragSource = [sender draggingSource];

	/*
	 * If this dnd operation was internal we need to check
	 * whether it was a move or a copy.
	 */
	if (![dragSource isKindOfClass: [self class]])
		return;

	if ([[dragSource dataSource] respondsToSelector: @selector(removeMovedTracks:)]) {
		[[dragSource dataSource] removeMovedTracks:
			(sourceDragMask & NSDragOperationPrivate) == NSDragOperationPrivate];
	}
}

@end

