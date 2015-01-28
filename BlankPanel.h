/* vim: set ft=objc ts=4 nowrap: */
/*
 *  BlankPanel.h
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

#ifndef BLANKPANEL_H_INC
#define BLANKPANEL_H_INC

#include <AppKit/AppKit.h>

#include "Burn/ExternalTools.h"


@interface BlankPanel : NSObject
{
	id panel;
	id fastButton;
	id completeButton;
	id progressLabel;
	id progressBar;
	id writersPopup;
	BOOL running;
}

- (id) init;
- (id) initWithNibName: (NSString *) nibName;

- (BOOL) windowShouldClose: (id)sender;

- (void) activate;

//
// notifications
//
- (void) fastBlank: (id)sender;
- (void) completeBlank: (id)sender;
- (void) burnerInUse: (id)sender;

//
// other functions
//
- (void) blankThread: (id)anObject;

//
// class methods
//
+ (id) sharedPanel;

@end

#endif
