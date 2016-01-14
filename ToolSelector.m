/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	ToolSelector.m
 *
 *	Copyright (c) 2002-2005, 2011, 2016
 *
 *	Author: Andreas Schik <andreas@schik.de>
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

#include <AppKit/AppKit.h>

#include "ToolSelector.h"

#include "AppController.h"
#include "Constants.h"
#include "Functions.h"

#define VMARGIN 6

@implementation ToolSelector

- (id) initWithFrame: (NSRect) frameRect
{
	NSTextField *text;

	self = [super initWithFrame: frameRect];
	if (self) {
		float height;
		NSRect frame;

		height = 2 * (TextFieldHeight + VMARGIN);
		frame = NSMakeRect(0, 0, frameRect.size.width, height);

		toolView = [[NSView alloc] initWithFrame: frame];
		[toolView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

		MAKE_LABEL(text, NSMakeRect(10, height - (TextFieldHeight+VMARGIN)+VMARGIN/2, 130, TextFieldHeight),
					_(@"Common.Burn"), 'l', YES, toolView);
		[text setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

		burnToolPopUp = [[NSPopUpButton alloc] initWithFrame: NSZeroRect pullsDown: NO];
		[burnToolPopUp setFrame: NSMakeRect(150, height - (TextFieldHeight+VMARGIN)+VMARGIN/2, 150, 20)];
		[burnToolPopUp setAutoenablesItems: NO];
		[burnToolPopUp setAutoresizingMask: NSViewWidthSizable | NSViewMinXMargin | NSViewMinYMargin];
		[toolView addSubview: burnToolPopUp];

		MAKE_LABEL(text, NSMakeRect(10, height - 2*(TextFieldHeight+VMARGIN)+VMARGIN/2, 130, TextFieldHeight),
					_(@"ToolSelector.createISO"), 'l', YES, toolView);
		[text setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

		isoToolPopUp = [[NSPopUpButton alloc] initWithFrame: NSZeroRect pullsDown: NO];
		[isoToolPopUp setFrame: NSMakeRect(150, height - 2*(TextFieldHeight+VMARGIN)+VMARGIN/2, 150, 20)];
		[isoToolPopUp setAutoenablesItems: NO];
		[isoToolPopUp setAutoresizingMask: NSViewWidthSizable | NSViewMinXMargin | NSViewMinYMargin];
		[toolView addSubview: isoToolPopUp];

		frame = NSMakeRect(0,0,frameRect.size.width,frameRect.size.height);
		scrollView = [[NSScrollView alloc] initWithFrame: frame];
		[scrollView setHasHorizontalScroller: NO];
		[scrollView setHasVerticalScroller: YES];
		[scrollView setDocumentView: toolView];
		[scrollView setBorderType: NSGrooveBorder];
		[scrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

		[self addSubview: scrollView];
	}
	return self;
}

- (void) dealloc
{
	[burnToolPopUp release];
	[isoToolPopUp release];
	[toolView release];
	[scrollView release];
	[super dealloc];
}

- (NSPopUpButton *) burnToolPopUp
{
	return burnToolPopUp;
}

- (NSPopUpButton *) isoToolPopUp
{
	return isoToolPopUp;
}


@end
