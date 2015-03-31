/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  CDrecordParametersView.m
 *
 *  Copyright (c) 2004
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <AppKit/AppKit.h>
#include "CDrecordController.h"
#include "CDrecordParametersView.h"
#include "Functions.h"
#include "Constants.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

static CDrecordParametersView *singleInstance = nil;


@implementation CDrecordParametersView

- (id) init
{
	return [self initWithNibName: @"Parameters"];
}

- (id) initWithNibName: (NSString *) nibName
{
	if (singleInstance) {
		[self dealloc];
	} else {
		self = [super init];

		if (![NSBundle loadNibNamed: nibName owner: self]) {
			NSLog (@"CDrecord: Could not load nib \"%@\".", nibName);
			[self dealloc];
		} else {
			view = [window contentView];
			[view retain];

			// We get our defaults for this panel
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
					[aBundle pathForResource: @"iconCDrecord" ofType: @"tiff"]]);
}

- (NSString *) title
{
    return @"cdrecord";
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
    NSString *temp;
	NSDictionary *parameters =
			[[NSUserDefaults standardUserDefaults]
                        dictionaryForKey: @"CDrecordParameters"];

    if ([parameters objectForKey: @"WriteMode"]) {
        [modePopup selectItemWithTag: [[parameters objectForKey: @"WriteMode"] intValue]];
    } else if ([[parameters objectForKey: @"TrackAtOnce"] boolValue] == NO) {
		[modePopup selectItemWithTag: SessionAtOnce];
    } else {
		[modePopup selectItemWithTag: TrackAtOnce];
    }

	temp = [parameters objectForKey: @"DriverOptions"];
	if (temp && [temp length]) {
		if ([temp rangeOfString: @"burnproof"].location != NSNotFound)
			[burnFreeCheckBox setState: 1];
		else
			[burnFreeCheckBox setState: 0];
	}
}


/*
 * saveChanges checks the values for the programs and displays an alert panel
 * for any program not defined or not executable. The user may then decide
 * to either not save the missing program and thus keep the old value or to
 * save the invalid value anyway.
 */
- (void) saveChanges
{
	NSMutableString *drvOpts = [[NSMutableString alloc] init];
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CDrecordParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

	[mutableParams setObject: [NSNumber numberWithInt: [[modePopup selectedItem] tag]]
                      forKey: @"WriteMode"];

    [mutableParams removeObjectForKey: @"TrackAtOnce"];

	if ([burnFreeCheckBox state]) {
		[drvOpts appendString: @"burnproof"];
    }

	[mutableParams setObject: drvOpts forKey: @"DriverOptions"];
    [[NSUserDefaults standardUserDefaults] setObject: mutableParams forKey: @"CDrecordParameters"];
	[[NSUserDefaults standardUserDefaults] synchronize];

    RELEASE(mutableParams);
	RELEASE(drvOpts);
}


//
// class methods
//
+ (id) singleInstance
{
	if (!singleInstance) {
		singleInstance = [[CDrecordParametersView alloc] initWithNibName: @"Parameters"];
	}

	return singleInstance;
}


@end
