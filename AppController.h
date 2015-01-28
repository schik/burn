/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	AppController.h
 *
 *	Copyright (c) 2002-2005, 2011
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

#ifndef APPCONTROLLER_H_INC
#define APPCONTROLLER_H_INC

#include <AppKit/AppKit.h>

#include <Burn/ExternalTools.h>

@class InspectorsWin;

@interface AppController : NSObject
{
	NSMutableDictionary *externalTools;
	NSMutableDictionary *audioConverters;

	NSString *currentWorkingPath;
	NSMutableArray *allProjectWindows;
	id lastProjectWindowOnTop;

	BOOL burnerInUse;
	NSLock *burnerLock;
}

+ (AppController *) appController;

- (id) init;
- (void) dealloc;

//
// delegate methods
//
- (void)applicationWillFinishLaunching: (NSNotification *) not;
- (void)applicationDidFinishLaunching: (NSNotification *) not;
- (BOOL)applicationShouldTerminate: (id) sender;

//
// action methods
//
- (void) showPrefPanel: (id) sender;
- (void) showConsole: (id) sender;
- (void) showInspector: (id) sender;
- (void) newProject: (id) sender;
- (void) openProject: (id) sender;
- (void) openRecentDoc: (id) sender;
- (void) closeProject: (id) sender;
- (void) blankCDRW: (id) sender;
- (void) showReadmePanel: (id) sender;
- (void) showBurnHelp: (id) sender;
- (void) displayWorkInProgress: (id) not;

//
// access methods
//
- (NSArray *) allBundles;
- (id) bundleForKey: (id) key;

- (NSArray *) registeredFileTypes;
- (NSArray *) bundlesForFileType: (NSString *) fileType;

/**
 * <p>Returns the CD writing bundle as selected by the user.
 * If the user did not select a bundle, yet, we return the
 * first one from the list or @c nil, if no bundles have
 * been found.</p>
 */
- (id) currentWriterBundle;

/**
 * <p>Returns the image generation bundle as selected by the user.
 * If the user did not select a bundle, yet, we return the
 * first one from the list or @c nil, if no bundles have
 * been found.</p>
 */
- (id) currentMkisofsBundle;

/**
 * <p>Returns the audio conversion bundle as selected by the user.
 * If the user did not select a bundle, yet, we return the
 * first one from the list or @c nil, if no bundles have
 * been found.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>fileType</term>
 * <desc>The file type for which the conversion bundle is needed.</desc>
 * </deflist>
  */
- (id) currentBundleForFileType: (NSString *) fileType;

/**
 * Returns the currently selected writing device. If the user has not
 * selected one, yet, returns the first one found by the current
 * writer bundle;
 */
- (NSString *) currentDevice;

- (NSArray *) allProjectWindows;
- (void) addProjectWindow: (id) theProjectWindow;
- (void) removeProjectWindow: (id) theProjectWindow;

- (id) lastProjectWindowOnTop;
- (void) setLastProjectWindowOnTop: (id) aWindow;

- (NSString *) currentWorkingPath;
- (void) setCurrentWorkingPath: (NSString *) thePath;

- (BOOL) lockBurner;
- (void) unlockBurner;
- (BOOL) burnerInUse;

//
// services methods
//

- (void) newProject: (NSPasteboard *) pboard
           userData: (NSString *) userData
              error: (NSString **) error;

- (void) addToProject: (NSPasteboard *) pboard
             userData: (NSString *) userData
                error: (NSString **) error;

//
// other methods
//

- (void) createMenu;
- (void) loadTools;

- (BOOL) burnIsoImage: (NSString *) imageFile;

@end

#endif
