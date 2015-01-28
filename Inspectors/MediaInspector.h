/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  MediaInspector.h
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
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */
#ifndef MEDIAINSPECTOR_H_INC
#define MEDIAINSPECTOR_H_INC

#include <AppKit/AppKit.h>


@interface MediaInspector : NSObject
{
	id window;
    id mediaTable;
    NSDictionary *media;
}

- (void) deactivate: (NSView *)view;
- (NSString *) inspectorName;
- (NSString *) winname;
- (id) window;

- (void)loadMedia: (id)sender;

@end

#endif
