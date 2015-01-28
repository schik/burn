/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	GeneralParameters.m
 *
 *	Copyright (c) 2004-2005, 2011
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
#include "GeneralParameters.h"
#include "AppController.h"
#include "Constants.h"
#include "Functions.h"
#include <Burn/ExternalTools.h>


static GeneralParameters *singleInstance = nil;


@implementation GeneralParameters

- (id) init
{
	return [self initWithNibName: @"GeneralParams"];
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

            alwaysKeepISO = NO;

            [[NSNotificationCenter defaultCenter] addObserver: self
						   selector: @selector(alwaysKeepISO:)
						   name: AlwaysKeepISOImages
						   object: nil];
	        [self initializeFromDefaults];
			singleInstance = self;
		}
	}

	return singleInstance;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self
						   name: AlwaysKeepISOImages
						   object: nil];
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
					[aBundle pathForResource: @"iconGeneral" ofType: @"tiff"]]);
}

- (NSString *) title
{
	return _(@"GeneralParameters.title");
}

- (NSView *) view
{
	return view;
}

- (BOOL) hasChangesPending
{
	return YES;
}



- (void) initializeFromDefaults
{
	NSString *temp;
	id object;
	NSDictionary *params =
        [[NSUserDefaults standardUserDefaults]
                        dictionaryForKey: @"SessionParameters"];

	[self getAvailableDrives];

	[speedPopUp removeAllItems];
	[speedPopUp addItemsWithTitles: [NSArray arrayWithObjects:
		@"1",@"2",@"4",@"6",@"8",@"10",@"12",@"16",@"20",@"24",
		@"30",@"32",@"36",@"40",@"44",@"48",@"52",@"60",@"72",nil]];

	object = [params objectForKey: @"Speed"];
	if (object) {
		[speedPopUp selectItemWithTitle: object];
	} else {
		[speedPopUp selectItemWithTitle: @"1"];
	}

	[overburnCheckBox setState: [[params objectForKey: @"Overburn"] intValue]];

	[ejectCheckBox setState: [[params objectForKey: @"EjectCD"] intValue]];

	[testCheckBox setState: [[params objectForKey: @"TestOnly"] intValue]];

	[keepISOCheckBox setState: [[params objectForKey: @"KeepISOImage"] intValue]];

	[keepWavCheckBox setState: [[params objectForKey: @"KeepTempWavs"] intValue]];

	[openConsoleCheckBox setState: [[params objectForKey: @"OpenConsole"] intValue]];

	temp = [params objectForKey: @"TempDirectory"];
	if (temp) {
		[tempDirField setStringValue: temp];
	} else {
		[tempDirField setStringValue: [NSString stringWithFormat: @"%@/tmp", NSHomeDirectory()]];
	}
}

- (void) saveChanges
{
    NSDictionary *params = [[NSUserDefaults standardUserDefaults]
       dictionaryForKey: @"SessionParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    [mutableParams setObject: [speedPopUp titleOfSelectedItem] forKey: @"Speed"];
    [mutableParams setObject: [NSNumber numberWithInt: [overburnCheckBox state]]
                      forKey: @"Overburn"];
    [mutableParams setObject: [NSNumber numberWithInt: [ejectCheckBox state]]
                      forKey: @"EjectCD"];
    [mutableParams setObject: [NSNumber numberWithInt: [testCheckBox state]]
                      forKey: @"TestOnly"];
    [mutableParams setObject: [NSNumber numberWithInt: [keepWavCheckBox state]]
                      forKey: @"KeepTempWavs"];
    [mutableParams setObject: [NSNumber numberWithInt: [keepISOCheckBox state]]
                      forKey: @"KeepISOImage"];
    [mutableParams setObject: [NSNumber numberWithInt: [openConsoleCheckBox state]]
                      forKey: @"OpenConsole"];

	[mutableParams setObject: [tempDirField stringValue] forKey: @"TempDirectory"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"SessionParameters"];
    RELEASE(mutableParams);

    params = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey: @"SelectedTools"];
    
    if (nil == params) {
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

	[mutableParams setObject: [devicePopUp titleOfSelectedItem]
                      forKey: @"BurnDevice"];
    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"SelectedTools"];
    RELEASE(mutableParams);

    [[NSUserDefaults standardUserDefaults] synchronize];
}

//
// action methods
//
- (void) chooseClicked: (id) sender
{
  /* insert your code here */
	NSArray *fileToOpen;
	NSOpenPanel *oPanel;
	NSString *dirName;
	int result;

	dirName = [tempDirField stringValue];

	oPanel = [NSOpenPanel openPanel];
	[oPanel setAllowsMultipleSelection: NO];
	[oPanel setCanChooseDirectories: YES];
	[oPanel setCanChooseFiles: NO];

	result = [oPanel runModalForDirectory:dirName file:@"" types:nil];
  
	if (result == NSOKButton) {
		fileToOpen = [oPanel filenames];

		if ([fileToOpen count] > 0) {
			dirName = [fileToOpen objectAtIndex:0];
			[tempDirField setStringValue: dirName];
		}
	}
}


//
//notification methods
//
- (void) alwaysKeepISO: (id) not
{
    [keepISOCheckBox setState: NSOnState];
    [keepISOCheckBox setEnabled: NO];
    alwaysKeepISO = YES;
}

//
// other methods
//
- (void) getAvailableDrives
{
	NSString *temp;
	NSArray *drives = nil;

	[devicePopUp removeAllItems];

	drives = getAvailableDrives();

	if (drives && [drives count]) {
		int i;
		for (i = 0; i < [drives count]; i++) {
			[devicePopUp addItemWithTitle: [drives objectAtIndex: i]];
		}
	} else {
		/*
		 * If we didn't find or get any burner devices, we put a
		 * dummy entry into the popup.
		 */
		[devicePopUp addItemWithTitle: NOT_FOUND];
	}

	temp = [[[NSUserDefaults standardUserDefaults]
        dictionaryForKey: @"SelectedTools"]
            objectForKey: @"BurnDevice"];
	if ([temp length]) {
		[devicePopUp selectItemWithTitle: temp];
	} else {
		[devicePopUp selectItemAtIndex: 0];
	}
}


//
// class methods
//
+ (id) singleInstance
{
	if (!singleInstance) {
		singleInstance = [[GeneralParameters alloc] init];
	}

	return singleInstance;
}


@end
