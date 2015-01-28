/* vim: set ft=objc ts=4 sw=4 et nowrap: */
/*
 *	ProjectWindowController.h
 *
 *	Copyright (c) 2002-2008
 *
 *	Author: Andreas Schik <andreas.schik@web.de>
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

#ifndef PROJECTWINDOWCONTROLLER_H_INC
#define PROJECTWINDOWCONTROLLER_H_INC

#include <AppKit/AppKit.h>


@class Project;
@class ProjectWindow;

@interface ProjectWindowController : NSWindowController
{
    // Outlets
	id trackView;
	id totalLength;

	id addDataButton;
	id addAudioButton;
	id removeButton;
	id createIsoButton;
	id burnIsoButton;
	id recordButton;
	id blankCdButton;
	id progress;
	id progressLabel;

	// Data
	NSMutableArray *movedTracks;

	NSString *cdRoot;
	NSString *audioRoot;
	NSString *dataRoot;

    BOOL workerThreadRunning;
}

- (id) init;
- (id) initWithWindowNibName: (NSString *) windowNibName;
- (void) dealloc;

//
// action methods
//
- (IBAction) deleteFile: (id) sender;

- (IBAction) runCDrecorder: (id) sender;
- (IBAction) createISOImage: (id) sender;
- (IBAction) createCD: (BOOL) isoOnly;
- (IBAction) burnISOImage: (id) sender;

- (IBAction) saveDocument: (id) sender;
- (IBAction) saveDocumentAs: (id) sender;
- (IBAction) saveDocumentTo: (id) sender;

- (void) burnerInUse: (id)sender;


//
// access / mutation methods
//

- (long) totalTime;
- (BOOL) workerThreadRunning;

//
// delegate methods
//
- (BOOL) windowShouldClose: (id) window;
- (void) awakeFromNib;
- (void) windowDidBecomeKey: (NSNotification *) not;

//
// Other methods
//
- (void) displayTotalTime;
- (void) updateWindow;
- (void) updateAudioCDPanel;
- (void) updateTrackInspector;

- (void) runInThread: (SEL) selector
              target: (id) target
            userData: (id) data
             message: (NSString *) message;

- (BOOL) addFiles: (NSArray *) files
           ofType: (int) type
          atIndex: (int) index
        recursive: (BOOL) recursive;

- (void) expandAllItems;

//
// class methods
//

@end

@interface ProjectWindowController (DragAndDrop)

- (IBAction) copy: (id) sender;
- (IBAction) cut: (id) sender;
- (IBAction) paste: (id) sender;

/**
 * Called by outline view to perform drop operation and returns YES if successful,
 * and NO otherwise.
 */
- (BOOL) outlineView: (NSOutlineView *) outlineView
		  acceptDrop: (id <NSDraggingInfo>) info
				item: (id) item
		  childIndex: (int) index;

/**
 * Starts the actual insertion of files into the compilation.
 */
- (BOOL) acceptFilenames: (NSPasteboard *) pBoard
             byOperation: (NSDragOperation) dragOperation
                forIndex: (int) index
                 andItem: (id) item;

/**
 * Starts the actual insertion of CD tracks dragged into the compilation.
 */
- (BOOL) acceptAudioCDTracks: (NSPasteboard *) pBoard
                    forIndex: (int) index
                     andItem: (id) item;

/**
 * Starts the actual insertion of tracks dragged from another compilation
 * into the current compilation.
 */
- (BOOL) acceptBurnTracks: (NSPasteboard *) pBoard
                 forIndex: (int) index
                  andItem: (id) item;

/**
 * Causes the outline view to write the specified items to the pastboard.
 */
- (BOOL) outlineView: (NSOutlineView *) outlineView
		  writeItems: (NSArray *) items
		toPasteboard: (NSPasteboard *) pboard;

- (id) validRequestorForSendType: (NSString *) sendType
                      returnType: (NSString *) returnType;

- (BOOL) readSelectionFromPasteboard: (NSPasteboard *) pboard;

/**
  * Remove tracks from the current compilation that have been moved
  * to another one.
  */
- (void) removeMovedTracks: (BOOL) flag;

@end


@interface ProjectWindowController (OutlineViewDelegation)

- (id) outlineView: (NSOutlineView *) outlineView
			 child: (int) index
			ofItem: (id) item;

- (BOOL) outlineView: (NSOutlineView *) outlineView
	isItemExpandable: (id) item;

- (void) outlineView: (NSOutlineView *) outlineView
     willDisplayCell: (id) aCell
      forTableColumn: (NSTableColumn *) tableColumn
                item: (id) item;

- (int) outlineView: (NSOutlineView *) outlineView 
		numberOfChildrenOfItem: (id) item;

- (id) outlineView: (NSOutlineView *) outlineView 
	objectValueForTableColumn: (NSTableColumn *) tableColumn 
					   byItem: (id) item;

- (void) outlineView: (NSOutlineView *) outlineView
      setObjectValue: (id) newObjectValue
      forTableColumn: (NSTableColumn *) tableColumn
              byItem: (id) item;

@end


#endif
