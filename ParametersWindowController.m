/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  ParametersWindowController.m
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

#include <Foundation/Foundation.h>

#include "ParametersWindowController.h"

#include "AppController.h"
#include "Constants.h"
#include "Functions.h"
#include "ProjectWindowController.h"

#include <Burn/PreferencesModule.h>
#include <Burn/ExternalTools.h>

/**
 * <p>standardModules contains the list of class names
 * for preferences classes. The preferences objects are created
 * and inserted into the panel in the order of their appearance
 * in standardModules.</p>
 */
static NSString *standardModules[] = {
    @"GeneralParameters",
    nil
};


@interface ParametersWindowController (Private)

- (void) initializeWithStandardModules;
- (void) initializeWithOptionalModules;
- (void) addModule: (id<PreferencesModule>) module;

@end

@implementation ParametersWindowController (Private)

- (void) initializeWithStandardModules
{
    int i = 0;
    NSString *className;

    // When creating an ISO image we do not need the General parameters
    if (opMode == OperationModeCreateIso) {
        return;
    }

    while (nil != (className = standardModules[i++])) {
        Class class = NSClassFromString(className);
        id<PreferencesModule> module = [class singleInstance];

        if (nil == module) {
            logToConsole(MessageStatusError, [NSString stringWithFormat:
                                            _(@"Common.initModuleFail"), className]);
            return;
        }
        [self addModule: module];

        RELEASE((id<NSObject>)module);
    }
}



//
//
//
- (void) initializeWithOptionalModules
{
    // In ISO creation mode we do not need all the other panels.
    if ((opMode == OperationModeCreateIso)
           || (opMode & OperationModeBurnData)) {
        id bundle = [[AppController appController] currentMkisofsBundle];
        if (nil != bundle) {
    		id<PreferencesModule> module = [bundle parameters];
            [self addModule: module];
        }
    }
    if (opMode & OperationModeBurnAll) {
        id bundle = [[AppController appController] currentWriterBundle];
        if (nil != bundle) {
    		id<PreferencesModule> module = [bundle parameters];
            [self addModule: module];
        }
    }
    if (opMode & OperationModeBurnAudio) {
        NSArray *types = [[AppController appController] registeredFileTypes];
        NSEnumerator *e = [types objectEnumerator];
        id type;
        while ((type = [e nextObject])) {
            id bundle = [[AppController appController] currentBundleForFileType: (NSString *)type];
            if (nil != bundle) {
    		    id<PreferencesModule> module = [bundle parameters];
                [self addModule: module];
            }
        }
    }

	[matrix sizeToCells];
	[matrix setNeedsDisplay: YES];
}

- (void) addModule: (id<PreferencesModule>) module
{
    int column = [matrix numberOfColumns];

    if (nil != module) {
        NSButtonCell *aButtonCell;

        // We add our column
        [matrix addColumn];

        [allModules setObject: module forKey: [module title]];
	  
        aButtonCell = [matrix cellAtRow: 0 column: column];
	  
        [aButtonCell setTag: column];
        [aButtonCell setTitle: [module title]];
        [aButtonCell setFont: [NSFont systemFontOfSize: 8]];
        [aButtonCell setImage: [module image]];
    }
}

@end


@implementation ParametersWindowController

- (id) init
{
	[self initWithWindowNibName: @"ParametersWindow" operationMode: OperationModeBurnAll];
    return self;
}

- (id) initWithWindowNibName: (NSString *) nibName
               operationMode: (OperationMode) operationMode;
{
    self = [super initWithWindowNibName: nibName];
    if (nil != self) {
        opMode = operationMode;
        if (![NSBundle loadNibNamed: nibName owner: self]) {
            logToConsole(MessageStatusError, [NSString stringWithFormat:
                                        _(@"Common.loadNibFail"), nibName]);
        } else {
            [[self window] setExcludedFromWindowsMenu: YES];
            [[self window] setHidesOnDeactivate: YES];
            [[self window] setTitle: _(@"ParametersWindowController.title")];
            [okButton setTitle: _(@"ParametersWindowController.exec.title")];

            [[self window] setFrameAutosaveName: @"ParametersWindow"];
            [[self window] setFrameUsingName: @"ParametersWindow"];
        }
    }
	return self;
}


//
//
//
- (void) dealloc
{
	RELEASE(allModules);

	[super dealloc];
}

- (void) awakeFromNib
{
   	allModules = [[NSMutableDictionary alloc] initWithCapacity: 2];

    NSInteger numcols = [matrix numberOfColumns];
    while (--numcols >= 0) {
        [matrix removeColumn: numcols];
    }

    [matrix setCellSize: NSMakeSize(64,64)];

    // We initialize our matrix with the standard modules
    [self initializeWithStandardModules];

    // We then add our additional modules
    [self initializeWithOptionalModules];

	// We select the first cell in our matrix
	[matrix selectCellAtRow: 0 column: 0];
	[self handleCellAction: matrix];
}


//
// action methods
//
- (void) okClicked: (id) sender
{
	[self saveParameters];

    [NSApp stopModalWithCode: NSOKButton];
}


- (void) handleCellAction: (id)sender
{	
	id aModule;
	
	aModule = [allModules objectForKey: [[matrix selectedCell] title]];

	if (aModule) {
		[self addModuleToView: aModule];
	} else {
		logToConsole(MessageStatusError, [NSString stringWithFormat:
					_(@"Common.loadBundleFail"), [[matrix selectedCell] title]]);
	}
}

//
// other methods
//
- (void) saveParameters
{
	NSArray *allNames;
	id<PreferencesModule> aModule;
	int i;

	allNames = [allModules allValues];

	for (i = 0; i < [allNames count]; i++) {
		aModule = [allNames objectAtIndex: i];
		[aModule saveChanges];
	}

//	[[NSUserDefaults standardUserDefaults] synchronize];
}


- (void) addModuleToView: (id<PreferencesModule>)aModule
{	
	if (aModule == nil) {
		return;
	}

	if ([box contentView] != [aModule view]) {
		[box setContentView: [aModule view]];
		[box setTitle: [aModule title]];
	}
}


//
//
//


//
// access/mutation methods
//


//
// class methods
//

@end
