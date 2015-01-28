/* vim: set ft=objc ts=4 nowrap: */
/*
 *  ExtProgressIndicator.m
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

#ifndef EXTPROGRESSINDICATOR_H_INC
#define EXTPROGRESSINDICATOR_H_INC

#include <AppKit/NSProgressIndicator.h>
#include <AppKit/NSTextField.h>


@interface ExtProgressIndicator: NSProgressIndicator
{
	NSMutableArray *sections;
}

- (id) initWithFrame: (NSRect)frameRect;
- (void) dealloc;

//
// access mutation methods
//
- (void) addSection: (NSDictionary *)newSection;
- (void) removeLastSection;

//
// class methods
//

@end

@interface CDLengthIndicator : NSView
{
	ExtProgressIndicator *lengthIndicator;
	NSTextField *sizeLabel;

	NSDictionary *labelAttributes;
}

- (void) setDoubleValue: (double)doubleValue;


@end

#endif
