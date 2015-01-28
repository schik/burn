/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	GeneralParameters.h
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

#ifndef GENERALPARAMS_H_INC
#define GENERALPARAMS_H_INC

#include <AppKit/AppKit.h>

#include <Burn/PreferencesModule.h>

@interface GeneralParameters : NSObject <PreferencesModule>
{
/*
 * Outlets
 */
    id devicePopUp;
	id overburnCheckBox;
	id ejectCheckBox;
	id openConsoleCheckBox;
	id speedPopUp;
	id testCheckBox;
	id window;
	id view;
	id keepWavCheckBox;
	id keepISOCheckBox;
	id tempDirField;
    BOOL alwaysKeepISO;
}

- (id) init;

//
// action methods
//

- (void) chooseClicked: (id) sender;

//
//notification methods
//
- (void) alwaysKeepISO: (id) not;

//
// other methods
//
- (void) getAvailableDrives;

@end


#endif
