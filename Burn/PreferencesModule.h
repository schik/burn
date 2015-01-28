/* vim: set ft=objc ts=4:nowrap: */
/*
 *  PreferencesModule.h
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef PREFERENCESMODULE_H_INC
#define PREFERENCESMODULE_H_INC

#include <AppKit/AppKit.h>

@protocol PreferencesModule

/**
 * <p><init /></p>
 */
- (id) initWithNibName: (NSString *) theName;
- (void) dealloc;

/**
 * <p>Returns an image that is used for the NSButton that brings this
 * PreferencesModule's view to the front.</p>
 */
- (NSImage *) image;

/**
 * <p>Must return a unique title for the prefs view that is displayed in
 * the preferences panel.</p>
 */
- (NSString *) title;

/**
 * <p>Returns an NSView that is displayed if the user presses the
 * corresponding switch button for this module in the Preferences panel.</p>
 */
- (NSView *) view;

/**
 * <p>Returns a value telling the Preferences panel whether any settings in this
 * module have been changed by the user. Currently not used, thus return YES.</p>
 */
- (BOOL) hasChangesPending;

/**
 * <p>Initialises the view's controls from the defaults database. This method
 * is currently not explicitly called from the containing panel, but should be
 * used during the initialistion phase of the view.</p>
 */
- (void) initializeFromDefaults;

/**
 * <p>Saves all changes made by the user in the defaults database.
 * Is called whenever the user presses 'Apply' or 'OK'.</p>
 */
- (void) saveChanges;


//
// class methods
//
/**
 * <p>The preferences panel uses one single instance of the module and therefore
 * calls this class method. singleInstance must create the module and initialise it
 * if it does not exist, yet.
 * In any case the method returns a reference to the single instance of
 * the class.</p>
 */
+ (id) singleInstance;

@end

#endif
