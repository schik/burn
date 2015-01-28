/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  PreferencesWindowController.m
 *
 *  Copyright (c) 2002
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
#include "PreferencesWindowController.h"

#include "AppController.h"
#include "Constants.h"
#include "Functions.h"

#include <Burn/PreferencesModule.h>
#include <Burn/ExternalTools.h>


/**
 * <p>standardModules contains the list of class names
 * for preferences classes. The preferences objects are created
 * and inserted into the panel in the order of their appearance
 * in standardModules.</p>
 */
static NSString *standardModules[] = {
    @"GeneralPrefs",
    @"ToolPanel",
    nil
};

static PreferencesWindowController *singleInstance = nil;

@interface PreferencesWindowController (Private)
- (void) save;
@end


@implementation PreferencesWindowController (Private)
- (void) save
{
	NSArray *allNames;
	id<PreferencesModule> aModule;
	int i;

	allNames = [allModules allKeys];

	for (i = 0; i < [allNames count]; i++) {
		aModule = [allModules objectForKey: [allNames objectAtIndex: i]];
		[aModule saveChanges];
	}

	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@implementation PreferencesWindowController


- (id) init
{
	[self initWithWindowNibName: @"PreferencesWindow"];
    return self;
}


- (id) initWithWindowNibName: (NSString *) nibName
{
	if (singleInstance) {
		[self dealloc];
	} else {
		self = [super initWithWindowNibName: nibName];
		singleInstance = self;
		if (![NSBundle loadNibNamed: nibName owner: self]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
								_(@"Common.loadNibFail"), nibName]);
		} else {
			[[self window] setExcludedFromWindowsMenu: YES];
	        [[self window] setHidesOnDeactivate: YES];
            [[self window] setTitle: _(@"PreferencesWindowController.title")];

  			[[self window] setFrameAutosaveName: @"PreferencesWindow"];
			[[self window] setFrameUsingName: @"PreferencesWindow"];
		}
	}
	return singleInstance;
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

    [namesPopup removeAllItems];

    // We initialize our matrix with the standard modules
    [self initializeWithStandardModules];

    // We then add our additional modules
    [self initializeWithOptionalModules];

	// We select the first cell in our matrix
	[namesPopup selectItemAtIndex: 0];
	[self moduleChanged: [namesPopup itemAtIndex: 0]];
}


//
//
//
- (void) windowWillClose: (NSNotification *)theNotification
{
	[self save];

//	AUTORELEASE(self);
	singleInstance = nil;
}


//
// action methods
//
- (void) moduleChanged: (id)sender
{	
	id aModule;

	aModule = [allModules objectForKey: [[namesPopup selectedItem] title]];

	if (aModule) {
		[self addModuleToView: aModule];
	} else {
		logToConsole(MessageStatusError, [NSString stringWithFormat:
					_(@"Common.loadBundleFail"),
                    [[namesPopup selectedItem] title]]);
	}
}


//
// other methods
//
- (void) addModuleToView: (id<PreferencesModule>)aModule
{	
	if (aModule == nil) {
		return;
	}

	if ([box contentView] != [aModule view]) {
		[box setContentView: [aModule view]];
		[box setTitle: [aModule title]];
		[moduleIcon setImage: [aModule image]];
	}
}


//
//
//
- (void) initializeWithStandardModules
{
    int i = 0;
    BOOL done = NO;

    while (!done) {
        NSString *className = standardModules[i++];

        if (className) {
            Class class = NSClassFromString(className);
        	id<PreferencesModule> module = [class singleInstance];

        	if (!module ) {
	        	logToConsole(MessageStatusError, [NSString stringWithFormat:
		        				_(@"Common.initModuleFail"), className]);
    		    return;
    	    }

	        [allModules setObject: module forKey: [module title]];

    	    [namesPopup addItemWithTitle: [module title]];

    	    RELEASE((id<NSObject>)module);
        } else {
            done = YES;
        }
    }
}



//
//
//
- (void) initializeWithOptionalModules
{
	int i;
	id<PreferencesModule> aModule;
	NSArray *bundles;

	bundles = [[AppController appController] allBundles];
	for (i = 0; i < [bundles count]; i++) {
		id aBundle;
      
		aBundle = [bundles objectAtIndex: i];

		// We get our Preferences module and we add it to our matrix.
		aModule = [aBundle preferences];
      
		if (aModule) {
			// We add our module
			[allModules setObject: aModule forKey: [aModule title]];
	  
			[namesPopup addItemWithTitle: [aModule title]];
		}
	}
}


//
// class methods
//
+ (id) singleInstance
{
	if (!singleInstance) {
		singleInstance = [[PreferencesWindowController alloc]
					initWithWindowNibName: @"PreferencesWindow"];
	} else {
		return nil;
	}

	return singleInstance;
}


+ (void) savePreferences
{
	if (singleInstance) {
        [singleInstance save];
    }
}

@end
