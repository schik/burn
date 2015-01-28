/* vim: set ft=objc ts=4 nowrap: */
/*
 *  InspectorsWin.h
 *
 *  Copyright (c) 2002-2004
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
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "InspectorsWin.h"
#include "AppController.h"
#include "TrackInspector.h"
#include "MediaInspector.h"
#include "AudioCDInspector.h"


static InspectorsWin *singleInstance = nil;

id sharedInspectorsWin()
{
	if (singleInstance == nil) {
		singleInstance = [[InspectorsWin alloc] init];
	}

	return singleInstance;
}

void releaseSharedInspectorsWin()
{
	TEST_RELEASE(singleInstance);
	singleInstance = nil;
}


@implementation InspectorsWin

- (void)dealloc
{
	RELEASE(inspectors);
	RELEASE(inspectorsPopUp);
	RELEASE(topView);
	[super dealloc];
}

- (id)init
{
	id inspector;
 	NSBox	*bar;

#define MAKE_INSPECTOR(i, n) \
inspector = [[i alloc] init];	\
[inspectorsPopUp addItemWithTitle: [inspector inspectorName]]; \
[inspectors addObject: inspector]; \
[(id)inspector release]
	
	self = [super initWithContentRect: NSMakeRect(0, 0, 272, 420)
							styleMask: NSTitledWindowMask | NSClosableWindowMask 
							  backing: NSBackingStoreRetained defer: NO];

	if (self) {
		[self setReleasedWhenClosed: NO];
		[self setHidesOnDeactivate: YES];

		topView = [[NSView alloc] init];			
		[topView setFrame: NSMakeRect(0, 390, 272, 30)];
		[[self contentView] addSubview: topView];
		
		inspectorsPopUp = [[NSPopUpButton alloc] initWithFrame: NSZeroRect pullsDown: NO];
		[inspectorsPopUp setFrame: NSMakeRect(60, 5, 152, 20)];
		[inspectorsPopUp setTarget: self];
		[inspectorsPopUp setAction: @selector(activateInspector:)];
		
		inspectors = [[NSMutableArray alloc] initWithCapacity: 1];
		currentInspector = nil;

		MAKE_INSPECTOR([TrackInspector class], 0);
		MAKE_INSPECTOR([MediaInspector class], 0);
		MAKE_INSPECTOR([AudioCDInspector class], 0);

		[topView addSubview: inspectorsPopUp];				      					
		[inspectorsPopUp selectItemAtIndex: 0];

		bar = [[NSBox alloc] initWithFrame: NSMakeRect (0, 0, 272, 2)];
		[bar setBorderType: NSGrooveBorder];
		[bar setTitlePosition: NSNoTitle];
		[bar setAutoresizingMask: NSViewWidthSizable|NSViewMinYMargin];
		[topView addSubview: bar];
		RELEASE(bar);

		[self setFrameUsingName: @"InspectorsWin"];
		[self setFrameAutosaveName: @"InspectorsWin"];
	}
	return self;
}

- (void)activateInspector: (id)sender
{
	NSString *inspectorName = [sender titleOfSelectedItem];
	[self activateInspectorWithTitle: inspectorName];
}

- (void)activateInspectorWithTitle: (id)title
{
	int i;

	// deactivate the currently displayed inspector
	if(currentInspector != nil) {
		if([[currentInspector inspectorName] isEqualToString: title] == YES) {
			return;
	    }
		[currentInspector deactivate: [[[self contentView] subviews] lastObject]];
	}

	// search the inspector with the selected name
	for (i = 0; i < [inspectors count]; i++) {
		id inspector = [inspectors objectAtIndex: i];		
		if([[inspector inspectorName] isEqualToString: title]) {
			currentInspector = inspector;
			break;
		}
	}

	// update our window
	[self setTitle: [[currentInspector window] title]];
	[inspectorsPopUp selectItemWithTitle: title];
	[[self contentView] addSubview: [[currentInspector window] contentView]];
	[self orderFrontRegardless];
	[[[currentInspector window] contentView] display];	
}

- (void)updateDefaults
{
	[self saveFrameUsingName: @"InspectorsWin"];
}

- (void)close
{
	[self updateDefaults];
	[super close];
	releaseSharedInspectorsWin();
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString *characters;
	unichar character;
	
	characters = [theEvent characters];
	character = 0;
		
	if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}
	  
	switch (character) {
	case NSLeftArrowFunctionKey:
		if ([theEvent modifierFlags] & NSControlKeyMask) {
      		int index = [inspectorsPopUp indexOfSelectedItem];

			if (index > 0) {        
				index--;
				[inspectorsPopUp selectItemAtIndex: index];
				[self activateInspector: inspectorsPopUp];            
			} else {
				[super keyDown: theEvent];
			}
		}
		return;

	case NSRightArrowFunctionKey:
		if ([theEvent modifierFlags] & NSControlKeyMask) {
			int index = [inspectorsPopUp indexOfSelectedItem];
			int items = [inspectorsPopUp numberOfItems];
        
			if (index < (items - 1)) {        
				index++;
				[inspectorsPopUp selectItemAtIndex: index];
				[self activateInspector: inspectorsPopUp];            
			} else {
				[super keyDown: theEvent];
			}
		}
		return;    
	}

	[super keyDown: theEvent];
}

- (BOOL)validateMenuItem:(id<NSMenuItem>)menuItem
{
	return YES;
}


//
// class methods
//

@end
