/* vim: set ft=objc et sw=4 ts=4 nowrap: */
/*
 *  CdrdaoSettingsView.m
 *
 *  Copyright (c) 2002-2005
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <AppKit/AppKit.h>
#include "CdrdaoSettingsView.h"
#include "CdrdaoController.h"
#include "Functions.h"
#include "Constants.h"

#ifdef _
#undef _
#endif

#define _(X) \
    [[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

static CdrdaoSettingsView *singleInstance = nil;


@implementation CdrdaoSettingsView

- (id) init
{
    return [self initWithNibName: @"Settings"];
}

- (id) initWithNibName: (NSString *) nibName
{
    if (singleInstance) {
        [self dealloc];
    } else {
        self = [super init];

        if (![NSBundle loadNibNamed: nibName owner: self]) {
            NSLog (@"Cdrdao: Could not load nib \"%@\".", nibName);
            [self dealloc];
        } else {
            view = [window contentView];
            [view retain];

            writerDriverMap = [NSMutableDictionary new];
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
    RELEASE(writerDriverMap);

    [super dealloc];
}

- (void) awakeFromNib
{
    [drivesTable setAutoresizesAllColumnsToFit: YES];
    [drivesTable setUsesAlternatingRowBackgroundColors: YES];
    [[drivesTable tableColumnWithIdentifier: @"drivers"] setMaxWidth: 128];
}

- (void) chooseClicked: (id)sender
{
    NSArray *fileToOpen;
    NSOpenPanel *oPanel;
    NSString *dirName;
    NSString *fileName;
    int result;

    dirName = [programTextField stringValue];
    fileName = [dirName lastPathComponent];
    dirName = [dirName stringByDeletingLastPathComponent];

    oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection: NO];
    [oPanel setCanChooseDirectories: NO];
    [oPanel setCanChooseFiles: YES];

    result = [oPanel runModalForDirectory: dirName
                                     file: fileName
                                    types: nil];
  
    if (result == NSOKButton) {
        fileToOpen = [oPanel filenames];

        if ([fileToOpen count] > 0) {
            fileName = [fileToOpen objectAtIndex: 0];
            [programTextField setStringValue: fileName];
        }
    }
}


//
// access methods
//

- (NSImage *) image
{
    NSBundle *aBundle;
    
    aBundle = [NSBundle bundleForClass: [self class]];
    
    return AUTORELEASE([[NSImage alloc] initWithContentsOfFile:
                    [aBundle pathForResource: @"iconCdrdao" ofType: @"tiff"]]);
}

- (NSString *) title
{
    return _(@"cdrdao");
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
	int i;
	NSArray *drives = nil;
	NSArray *drivers = nil;
    NSPopUpButtonCell *cell = nil;
    NSString *temp;
    NSDictionary *parameters = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey: @"CdrdaoParameters"];

    temp = [parameters objectForKey: @"Program"];
    if (!temp) {
        temp = which(@"cdrdao");
    }
    if (temp) {
        [programTextField setStringValue: temp];
    }

	drivers = [[CdrdaoController singleInstance] drivers];

    cell = [NSPopUpButtonCell new];
	for (i = 0; i < [drivers count]; i++) {
		[cell addItemWithTitle: [drivers objectAtIndex: i]];
    }
    [[drivesTable tableColumnWithIdentifier: @"drivers"] setDataCell: cell];

    drives = [[CdrdaoController singleInstance] availableDrives];
    parameters = [[NSUserDefaults standardUserDefaults]
        objectForKey: @"Drivers"];

    for (i = 0; i < [drives count]; i++) {
        NSDictionary *d = [parameters objectForKey: [drives objectAtIndex: i]];
        NSString *driver = [d objectForKey: [[CdrdaoController singleInstance] name]];
        if (nil == driver) {
            driver = @"Default";
        }
        [writerDriverMap setObject: driver forKey: [drives objectAtIndex: i]];
    }
    [drivesTable reloadData];
}


/*
 * saveChanges checks the values for the programs and displays an alert panel
 * for any program not defined or not executable. The user may then decide
 * to either not save the missing program and thus keep the old value or to
 * save the invalid value anyway.
 */
- (void) saveChanges
{
    id writer;
    NSString *cdrdao;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CdrdaoParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    // Write the program path
    cdrdao = [programTextField stringValue];

    if (!checkProgram(cdrdao)) {
        NSRunAlertPanel(@"Cdrdao.burntool",
                        [NSString stringWithFormat:
                                _(@"Program for %@ not defined or not executable. %@ may not run correctly."),
                                @"cdrdao", @"Cdrdao.burntool"],
                        _(@"OK"), nil, nil);
    }

    [mutableParams setObject: cdrdao forKey: @"Program"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"CdrdaoParameters"];
    RELEASE(mutableParams);

    // Write the driver settings
    params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"Drivers"];
    
    if (nil == params) {
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    NSEnumerator *enumerator = [writerDriverMap keyEnumerator];
 
    while ((writer = [enumerator nextObject])) {
        NSString *driver = [writerDriverMap objectForKey: writer];
        if (nil != driver) {
            NSMutableDictionary *md = [[mutableParams objectForKey: writer] mutableCopy];
            if (nil == md) {
                md = [NSMutableDictionary new];
            }
            [md setObject: driver forKey: [[CdrdaoController singleInstance] name]];
            [mutableParams setObject: md forKey: writer];
            RELEASE(md);
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"Drivers"];
    RELEASE(mutableParams);

    [[NSUserDefaults standardUserDefaults] synchronize];
}

/*
 * Data Source methods
 */
- (int) numberOfRowsInTableView: (NSTableView *)tableView
{
	return [writerDriverMap count];
}


//
//
//
- (id)           tableView: (NSTableView *) tableView
 objectValueForTableColumn: (NSTableColumn *) tableColumn 
		               row: (int) rowIndex
{
    if ([[tableColumn identifier] isEqual: @"writers"]) {
        return [[writerDriverMap allKeys] objectAtIndex: rowIndex];
    }
    if ([[tableColumn identifier] isEqual: @"drivers"]) {
        NSArray *drivers = [[CdrdaoController singleInstance] drivers];
        NSUInteger index = [drivers indexOfObject: [[writerDriverMap allValues] objectAtIndex: rowIndex]];
        return [NSNumber numberWithInt: index];
    }

    return @"";
}

- (void) tableView: (NSTableView *) tableView
    setObjectValue: (id) object
    forTableColumn: (NSTableColumn *) tableColumn
               row: (int) rowIndex
{
    NSString *writer = [[writerDriverMap allKeys] objectAtIndex: rowIndex];
    NSArray *drivers = [[CdrdaoController singleInstance] drivers];
    NSString *driver = [drivers objectAtIndex: [object intValue]];
    [writerDriverMap setObject: driver
                        forKey: writer];
    [drivesTable reloadData];
}

//
// class methods
//
+ (id) singleInstance
{
    if (!singleInstance) {
        singleInstance = [[CdrdaoSettingsView alloc] initWithNibName: @"Settings"];
    }

    return singleInstance;
}


@end
