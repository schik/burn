/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  BurnCDHelper.h
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef BURNCDHELPER_H_INC
#define BURNCDHELPER_H_INC

#include <AppKit/AppKit.h>

#include "BurnProgressController.h"
#include "Burn/ExternalTools.h"

@interface BurnCDHelper : NSObject
{
    BurnProgressController *controller;

	id<BurnTool> currentTool;
}

- (id) initWithController: (BurnProgressController *)aController;

- (enum StartHelperStatus) start: (NSString *) isoImageFile audioTracks: (NSArray *) audioTracks;
- (void) stop: (BOOL) immediately;

//
// private methods
//
- (void) cleanUp: (BOOL) success;


- (void) burnTrackThread: (id) anObject;
- (void) updateStatus: (id) timer;

@end


#endif
