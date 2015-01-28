/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
**  ConsolePanel.m
**
**  Copyright (c) 2011
**
**  Author: Andreas Schik <andreas@schik.de>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "ConsolePanel.h"
#include "Constants.h"

NSString *_ConsoleMessage = @"ConsoleMessage";

static ConsolePanel *consolePanel = nil;


void releaseSharedConsole()
{
	TEST_RELEASE(consolePanel);
	consolePanel = nil;
}


void logToConsole(NSString *priority, NSString *theMessage)
{
	// create console if not already done
	[ConsolePanel consolePanel];

	[[NSNotificationCenter defaultCenter]
		postNotificationName: _ConsoleMessage
		object: nil
		userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
									priority, @"Priority",
									theMessage, @"Message", nil]];
}

@implementation ConsolePanel

- (id) init
{
    [self initWithWindowNibName: @"Console"];
    return self;
}


- (id) initWithWindowNibName: (NSString *) windowNibName
{
    if (consolePanel) {
        [self dealloc];
    } else {
	    self = [super initWithWindowNibName: windowNibName];
		consolePanel = self;

		// The array is used to temporarily store the messages and is emptied
		// by a timer.
		// We need this to decouple the GUI action from the actual posting
		// of the output, as this might have happend in a separate thread.
		// And as we all know, is -gui not thread-safe...
		logMessages = [NSMutableArray new];

		[[self window] setFrameAutosaveName: @"ConsoleWindow"];
		[[self window] setFrameUsingName: @"ConsoleWindow"];
    }
    return consolePanel;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self
						   name: _ConsoleMessage
						   object: nil];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self
						   name: ExternalToolOutput
						   object: nil];

	[appendLock release];
	[logMessages release];
	[super dealloc];
}


- (void) awakeFromNib
{
	[outputWindow setRichText: YES];
	[[outputWindow textContainer] setWidthTracksTextView: YES];
}



//
// delegate methods
//
- (void) windowWillClose: (NSNotification *) not
{
  // Do nothing
}


//
//
//
- (void) windowDidLoad
{
	appendLock = [NSLock new];

	[[NSNotificationCenter defaultCenter] addObserver: self
						   selector: @selector(messageWasReceived:)
						   name: _ConsoleMessage
						   object: nil];

	[[NSDistributedNotificationCenter defaultCenter] addObserver: self
						   selector: @selector(messageWasReceived:)
						   name: ExternalToolOutput
						   object: nil];

	// This timer process the message array.
	[NSTimer scheduledTimerWithTimeInterval: 0.5
								target: self
							  selector: @selector(appendOutput:)
				 			  userInfo: nil
							   repeats: NO];
}


//
// other methods
//
- (void) messageWasReceived: (id) not
{
	NSString *priority;
	NSString *message;
	NSMutableAttributedString *output;
	NSDictionary *attributes = nil;

	// extract the output string from the message
	message = [[not userInfo] objectForKey: @"Message"];
	if (message == nil)
		message = [[not userInfo] objectForKey: @"Output"];

	if (message == nil) {
		return;
	}

	// get the priority
	priority = [[not userInfo] objectForKey: @"Priority"];
	if (priority == nil)
		priority = MessageStatusToolOutput;

	// check for empty lines
	if (([message length] == 0) ||
			[message isEqualToString: @"\n"] || [message isEqualToString: @"\r"] ||
			[message isEqualToString: @"\r\n"] || [message isEqualToString: @"\n\r"]) {
		// we want only one empty line
		if (lastLineWasEmpty == YES) {
			return;
		}
		lastLineWasEmpty = YES;
	} else
		lastLineWasEmpty = NO;

	// take care of line break
	if (![message hasSuffix: @"\n"] && ![message hasSuffix: @"\r"])
		message = [message stringByAppendingString: @"\n"];

	// set color for the message due to priority
	if ([priority isEqualToString: MessageStatusToolOutput]) {
		attributes= [NSDictionary dictionaryWithObjectsAndKeys:
						    [NSColor darkGrayColor], NSForegroundColorAttributeName,
						    NULL];
	} else if ([priority isEqualToString: MessageStatusInfo]) {
		attributes= [NSDictionary dictionaryWithObjectsAndKeys:
						    [NSColor blackColor], NSForegroundColorAttributeName,
						    NULL];
	} else if ([priority isEqualToString: MessageStatusWarning]) {
		attributes= [NSDictionary dictionaryWithObjectsAndKeys:
						    [NSColor blueColor], NSForegroundColorAttributeName,
						    NULL];
	} else if ([priority isEqualToString: MessageStatusError]) {
		attributes= [NSDictionary dictionaryWithObjectsAndKeys:
						    [NSColor redColor], NSForegroundColorAttributeName,
						    NULL];
	}

	output = [NSMutableAttributedString new];

	// append message to output
	[output appendAttributedString: [[[NSAttributedString new] initWithString: message
												 attributes: attributes] autorelease]];

	// add to message array
	[appendLock lock];
	[logMessages addObject: output];
	[appendLock unlock];

	[output release];
}


- (void) appendOutput: (id)timer
{
	BOOL mustScroll = NO;
	int i;
   	NSRange range;

	// lock the output window for a moment
	[appendLock lock];

	for (i = 0; i < [logMessages count]; i++) {
		mustScroll = YES;
		// extract message from timer data and append it to output window
   		range = NSMakeRange ([[outputWindow string] length], 0);
	   	[outputWindow replaceCharactersInRange: range
						  withAttributedString: (NSAttributedString*)[logMessages objectAtIndex: i]];
	}
	[logMessages removeAllObjects];

	[appendLock unlock];

	if (mustScroll) {
	   	range = NSMakeRange ([[outputWindow string] length], 0);
		[outputWindow scrollRangeToVisible: range];
	}

	[NSTimer scheduledTimerWithTimeInterval: 0.5
								target: self
							  selector: @selector(appendOutput:)
				 			  userInfo: nil
							   repeats: NO];
}

+ (id) consolePanel
{
    if (consolePanel == nil) {
        consolePanel = [[ConsolePanel alloc] init];
    }

    return consolePanel;
}


@end
