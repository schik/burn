/* vim: set ft=objc et sw=4 ts=4 nowrap: */
/*
 *    BlankPanel.m
 *
 *    Copyright (c) 2002
 *
 *    Author: Andreas Heppel <aheppel@web.de>
 *
 *    This program is free software; you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation; either version 2 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include "BlankPanel.h"

#include "Constants.h"
#include "Functions.h"
#include "AppController.h"

static BlankPanel *sharedPanel = nil;
static BOOL blanking = NO;


@implementation BlankPanel


- (id) init
{
    [self initWithNibName: @"BlankPanel"];
    return self;
}


- (id) initWithNibName: (NSString *) nibName;
{
    if (sharedPanel) {
        [self dealloc];
    } else {
        self = [super init];
        sharedPanel = self;
        if (![NSBundle loadNibNamed: nibName owner: self]) {
            logToConsole(MessageStatusError, [NSString stringWithFormat:
                                _(@"Common.loadNibFail"), nibName]);
        } else {
            [panel setExcludedFromWindowsMenu: YES];

            [[NSNotificationCenter defaultCenter] addObserver: self
                                   selector: @selector(burnerInUse:)
                                   name: BurnerInUse
                                   object: nil];

            [panel setFrameAutosaveName: @"BlankPanel"];
            [panel setFrameUsingName: @"BlankPanel"];
            running = NO;
        }
    }
    return sharedPanel;
}

- (void) awakeFromNib
{
	NSArray *drives = nil;

    [progressLabel setStringValue: _(@"BlankPanel.chooseMode")];
    [fastButton setTitle: _(@"BlankPanel.fastButton")];
    [completeButton setTitle: _(@"BlankPanel.completeButton")];

	[writersPopup removeAllItems];

	drives = getAvailableDrives();

	if (drives && [drives count]) {
		int i;
		for (i = 0; i < [drives count]; i++) {
			[writersPopup addItemWithTitle: [drives objectAtIndex: i]];
		}
	} else {
		/*
		 * If we didn't find or get any burner devices, we put a
		 * dummy entry into the popup.
		 */
		[writersPopup addItemWithTitle: NOT_FOUND];
        [fastButton setEnabled: NO];
        [completeButton setEnabled: NO];
	}
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                           name: BurnerInUse
                           object: nil];
    [super dealloc];
}


- (void) close
{
    [progressLabel setStringValue: @""];
}


- (void) activate
{
    [panel makeKeyAndOrderFront: self];
}

- (BOOL) windowShouldClose: (id) sender
{
    return !blanking;
}

- (void) wakeUpMainThreadRunloop: (id) arg
{
    running = NO;
}

//
// action methods
//
- (void) fastBlank: (id) sender
{
    running = YES;
    [progressBar startAnimation: self];

    [NSThread detachNewThreadSelector: @selector(blankThread:)
                            toTarget: self
                            withObject: fastButton];

    while (running) {
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                 beforeDate: [NSDate distantFuture]];
    }

    [progressBar stopAnimation: self];
}

- (void) completeBlank: (id) sender
{
    running = YES;
    [progressBar startAnimation: self];

    [NSThread detachNewThreadSelector: @selector(blankThread:)
                            toTarget: self
                            withObject: completeButton];

    while (running) {
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                 beforeDate: [NSDate distantFuture]];
    }

    [progressBar stopAnimation: self];
}

- (void) burnerInUse: (id)sender
{
    if ([[[sender userInfo] objectForKey: @"InUse"] isEqualToString: @"YES"]) {
        [fastButton setEnabled: NO];
        [completeButton setEnabled: NO];
    } else {
        [fastButton setEnabled: YES];
        [completeButton setEnabled: YES];
    }
}

- (void) blankThread: (id)anObject
{
    EBlankingMode value;
    id<Burner> writer;
    id pool;
    pool = [NSAutoreleasePool new];

    if (![[AppController appController] lockBurner]) {
        logToConsole(MessageStatusError, _(@"Common.burnerLocked"));
        goto blank_end;
    }

    blanking = YES;

    if (anObject == completeButton)
        value = fullBlank;
    else
        value = fastBlank;

    [progressLabel setTextColor: [NSColor blueColor]];
    [progressLabel setStringValue: _(@"BlankPanel.inProcess")];

    writer = [[AppController appController] currentWriterBundle];

    if (nil != writer) {
        if ([writer blankCDRW: value
                     inDevice: [[writersPopup selectedItem] title]
               withParameters: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]) {
            [progressLabel setTextColor: [NSColor blueColor]];
            [progressLabel setStringValue: _(@"BlankPanel.success")];
            logToConsole(MessageStatusInfo, _(@"BlankPanel.success"));
        } else {
            [progressLabel setTextColor: [NSColor redColor]];
            [progressLabel setStringValue: _(@"BlankPanel.error")];
            logToConsole(MessageStatusError, _(@"BlankPanel.error"));
        }
    }
    [[AppController appController] unlockBurner];

    blanking = NO;

blank_end:

    [self performSelectorOnMainThread: @selector(wakeUpMainThreadRunloop:)
                           withObject: nil
                        waitUntilDone: NO];
    RELEASE(pool);
    [NSThread exit];
}


//
// class methods
//
+ (id) sharedPanel
{
    if (sharedPanel == nil) {
        sharedPanel = [[BlankPanel alloc] init];
    }

    return sharedPanel;
}


@end
