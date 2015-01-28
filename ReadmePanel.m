/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
**  ReadmePanel.m
**
**  Copyright (c) 2011
**
**  Author: Andreas Schik <andreas@schik.de>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <AppKit/AppKit.h>
#include "ReadmePanel.h"
#include "Functions.h"
#include "Constants.h"

static ReadmePanel *readmePanel = nil;


void releaseSharedReadme()
{
	TEST_RELEASE(readmePanel);
	readmePanel = nil;
}

@implementation ReadmePanel

- (id) init
{
    [self initWithWindowNibName: @"Readme"];
    return self;
}


- (id) initWithWindowNibName: (NSString *) windowNibName
{
    if (readmePanel) {
        [self dealloc];
    } else {
	    self = [super initWithWindowNibName: windowNibName];
        readmePanel = self;

        [[self window] setExcludedFromWindowsMenu: YES];

        [[self window] setFrameAutosaveName: @"ReadmePanel"];
        [[self window] setFrameUsingName: @"ReadmePanel"];
    }
    return readmePanel;
}

- (void) dealloc
{
    [super dealloc];
}

- (void) windowDidLoad
{
	NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString *path = [bundle pathForResource: @"README" ofType: @""];
    NSAttributedString *string = nil;

    if (nil == path) {
        string = [[NSAttributedString alloc] initWithString: @"README file not found."];
    } else {
        NSError *error;
        NSString *stringFromFileAtPath = [[NSString alloc]
            initWithContentsOfFile: path
                          encoding: NSUTF8StringEncoding
                             error: &error];
        if (nil == stringFromFileAtPath) {
            string = [[NSAttributedString alloc] initWithString: @"Could not read README file."];
        } else {
            string = [[NSAttributedString alloc] initWithString: stringFromFileAtPath];
        }
    }
    [[readmeTextField textStorage] setAttributedString: string];
    RELEASE(string);
}

+ (id) readmePanel
{
    if (readmePanel == nil) {
        readmePanel = [[ReadmePanel alloc] init];
    }

    return readmePanel;
}

@end
