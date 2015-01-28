/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  WorkInProgress.m
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <AppKit/NSProgressIndicator.h>

#include "Functions.h"
#include "Constants.h"

#include "WorkInProgress.h"


static NSString *nibName = @"WorkInProgress";
#define PI_LENGTH 2

@implementation WorkInProgress

- (void) dealloc
{
    TEST_RELEASE (win);
    [super dealloc];
}

- (id) init
{
    self = [super init];

    if (self) {
        if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
            logToConsole(MessageStatusError, [NSString stringWithFormat:
                                _(@"Common.loadNibFail"), nibName]);
            DESTROY (self);
            return self;
        } else {
            NSRect wframe = [win frame];
            NSRect scrframe = [[NSScreen mainScreen] frame];
            NSRect winrect = NSMakeRect((scrframe.size.width - wframe.size.width) / 2,
                              (scrframe.size.height - wframe.size.height) / 2,
                               wframe.size.width,
                               wframe.size.height);
      
            [win setFrame: winrect display: NO];
        }			
    }
  
    return self;
}

- (void) startAnimationWithString: (NSString *) string
                          appName: (NSString *) appname;
{
    if (win) {
        [win setTitle: appname];
        [textField setStringValue: string];

        [progInd setAnimationDelay: 1./6.];
        [progInd startAnimation: self];

        if ([win isVisible] == NO) {
            [win orderFrontRegardless];
        }
    }
}

- (void) stopAnimation
{
    [progInd stopAnimation: self];
    [win close];
}

- (BOOL) windowShouldClose: (id) sender
{
    [progInd stopAnimation: self];
    return YES;
}

@end
