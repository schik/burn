/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	GeneralPrefs.m
 *
 *	Copyright (c) 2004, 2011
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
#include "GeneralPrefs.h"
#include "AppController.h"
#include "Functions.h"
#include "Constants.h"
#include <Burn/ExternalTools.h>

static GeneralPrefs *singleInstance = nil;


@implementation GeneralPrefs

- (id) init
{
	return [self initWithNibName: @"GeneralPrefs"];
}

- (id) initWithNibName: (NSString *) nibName
{
	if (singleInstance) {
		[self dealloc];
	} else {
		self = [super init];

		if (![NSBundle loadNibNamed: nibName owner: self]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
								_(@"Common.loadNibFail"), nibName]);
			[self dealloc];
			return nil;
		} else {
			view = [window contentView];
			[view retain];

	        [self initializeFromDefaults];
			singleInstance = self;
		}
	}

	return singleInstance;
}


- (void) dealloc
{
	singleInstance = nil;
	RELEASE(view);

	[super dealloc];
}



//
// access methods
//

- (NSImage *) image
{
	NSBundle *aBundle;
	
	aBundle = [NSBundle bundleForClass: [self class]];
	
	return AUTORELEASE([[NSImage alloc] initWithContentsOfFile:
					[aBundle pathForResource: @"iconGSburn" ofType: @"tiff"]]);
}

- (NSString *) title
{
	return _(@"GeneralPrefs.title");
}

- (NSView *) view
{
	return view;
}

- (BOOL) hasChangesPending
{
	return YES;
}


//
//
//
- (void) initializeFromDefaults
{
	NSDictionary *parameters =
			[[NSUserDefaults standardUserDefaults] objectForKey: @"GeneralParameters"];

	if ([parameters objectForKey: @"OpenCompilationOnStartup"]) {
		[openCompCheckBox setState: [[parameters objectForKey: @"OpenCompilationOnStartup"] intValue]];
    } else {
        // default is YES
        [openCompCheckBox setState: 1];
    }
	[closeOnLastWindow setState: [[parameters objectForKey: @"CloseOnLastWindow"] intValue]];
}


- (void) saveChanges
{
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

	[parameters setObject: [NSNumber numberWithInt: [openCompCheckBox state]]
					forKey: @"OpenCompilationOnStartup"];
	[parameters setObject: [NSNumber numberWithInt: [closeOnLastWindow state]]
					forKey: @"CloseOnLastWindow"];
	[[NSUserDefaults standardUserDefaults] setObject: parameters forKey: @"GeneralParameters"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


//
// class methods
//
+ (id) singleInstance
{
	if (!singleInstance) {
		singleInstance = [[GeneralPrefs alloc] init];
	}

	return singleInstance;
}

@end
