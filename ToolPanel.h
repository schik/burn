/* vim: set ft=objc ts=4 nowrap: */
/*
 *	ToolPanel.h
 *
 *	Copyright (c) 2002-2005, 2011, 2016
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

#ifndef TOOLPANEL_H_INC
#define TOOLPANEL_H_INC

#include <AppKit/AppKit.h>

#include <Burn/PreferencesModule.h>

@interface ToolPanel : NSObject <PreferencesModule>
{
  id panel;
  id view;
  id burnToolPopUp;
  id isoToolPopUp;
  id toolTable;
}

- (id) init;

- (void) toolChanged: (id) sender;

//
// class methods
//

@end


#endif
