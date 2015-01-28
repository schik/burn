/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  MediaInspector.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "AppController.h"
#include "MediaInspector.h"
#include "Functions.h"
#include "Constants.h"

#include <Burn/ExternalTools.h>


@implementation MediaInspector


- (id)init
{	
	self = [super init];
  
	if(self) {
        media = nil;
		// load the gui...
		if (![NSBundle loadNibNamed: @"MediaInspector" owner: self]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
								_(@"Common.loadNibFail"), @"MediaInspector"]);
			[self dealloc];
			return nil;
		} else {
			// initialize all member variables...
            [self loadMedia: self];
		}
	}
	return self;
}

- (void) dealloc
{
    RELEASE(media);
    [super dealloc];
}

- (void)loadMedia: (id)sender
{
	id<Burner> burner = nil;
	NSDictionary *params = nil;
	NSDictionary *info = nil;

    DESTROY(media);
    media = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSDictionary dictionary], _(@"Common.pleaseWait"), nil];
    [mediaTable reloadData];

	burner = [[AppController appController] currentWriterBundle];
	if (nil != burner) {
		params = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
		RETAIN(params);
		info = [burner mediaInformation: params];
		RELEASE(params);
	}

	if (nil == info) {
		info = [NSDictionary dictionaryWithObjectsAndKeys: 
              [NSDictionary dictionary], NOT_FOUND, nil];
	}

    media = RETAIN(info);
    [mediaTable reloadData];
}

- (void)deactivate: (NSView *)view
{
	/* This gives the view back to its original parent */
	[(NSWindow*)window setContentView: view];
}

- (id) window
{
	return window;
}

- (NSString *)inspectorName
{
	return _(@"MediaInspector.name");
}

- (NSString *)winname
{
	return [window title];
}

//
// outline view delegate methods
//

- (int) outlineView: (NSOutlineView *) outlineView 
		numberOfChildrenOfItem: (id) item
{
    id o;

    if (nil == media) {
        return 0;
    }

    if (nil == item) {
        return [media count];
    }

    o = [media objectForKey: item];
    if (nil != o) {
        return [o count];
    }
    return 0;
}

- (id) outlineView: (NSOutlineView *) outlineView
			 child: (int) index
			ofItem: (id) item
{
    id o;

    if (nil == media) {
        return nil;
    }

    if (nil == item) {
        return [[media allKeys] objectAtIndex: index];
    }

    o = [media objectForKey: item];
    if (nil != o) {
        NSString *label = @"";
        id key = [[o allKeys] objectAtIndex: index];
        if ([key isEqualToString: @"type"]) {
            label = _(@"Common.type");
        }
        if ([key isEqualToString: @"vendor"]) {
            label = _(@"Common.vendor");
        }
        if ([key isEqualToString: @"speed"]) {
            label = _(@"Common.speed");
        }
        if ([key isEqualToString: @"capacity"]) {
            label = _(@"Common.capacity");
        }
        if ([key isEqualToString: @"empty"]) {
            label = _(@"MediaInspector.empty");
        }
        if ([key isEqualToString: @"remCapacity"]) {
            label = _(@"Common.remCapacity");
        }
        if ([key isEqualToString: @"sessions"]) {
            label = _(@"Common.sessions");
        }
        if ([key isEqualToString: @"appendable"]) {
            label = _(@"Common.appendable");
        }

        return [NSString stringWithFormat: @"%@: %@",
                label, [o objectForKey: key]];
    }
    return nil;
}

- (BOOL) outlineView: (NSOutlineView *) outlineView
	isItemExpandable: (id) item
{
    return (0 != [self outlineView: outlineView
      numberOfChildrenOfItem: item]);
}

- (id)            outlineView: (NSOutlineView *) outlineView 
    objectValueForTableColumn: (NSTableColumn *) tableColumn 
                       byItem: (id) item
{
    return item;
}

@end
