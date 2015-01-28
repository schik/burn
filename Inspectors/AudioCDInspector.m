/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  AudioCDInspector.m
 *
 *  Copyright (c) 2003, 2011
 *
 *  Author: Andreas Schik <andreas@schik.de>
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

#include <AppKit/AppKit.h>
#include "AudioCDInspector.h"
#include "Functions.h"
#include "Constants.h"
#include "Track.h"

@implementation AudioCDInspector


- (id)init
{
	self = [super init];

	if(self) {
        allCDs = nil;
        selected = [NSMutableArray new];
		// load the gui...
		if (![NSBundle loadNibNamed: @"AudioCDInspector" owner: self]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
								_(@"Common.loadNibFail"), @"AudioCDInspector"]);
			[self dealloc];
			return nil;
		} else {
			[[NSNotificationCenter defaultCenter] addObserver: self
			   selector: @selector(audioCDChanged:)
			   name: AudioCDMessage
			   object: nil];

			[[NSNotificationCenter defaultCenter] addObserver: self
			   selector: @selector(tracksChanged:)
			   name: TrackSelectionChanged
			   object: nil];
            [cdTable reloadData];
		}
	}		
	return self;
}

- (void)dealloc
{

	[[NSNotificationCenter defaultCenter] removeObserver: self
							name: AudioCDMessage
							object: nil];

	RELEASE(allCDs);
    RELEASE(selected);
	[super dealloc];
}

- (void) deactivate: (NSView *) view
{
	/* This gives the view back to its original parent */
	[(NSWindow*)window setContentView: view];
}

- (NSString *) inspectorName
{
	return _(@"AudioCDInspector.name");
}

- (NSString *) winname
{
	return [window title];
}

- (id) window
{
	return window;
}

- (void) audioCDChanged: (id) notification
{
	[allCDs release];

	if ([notification userInfo])
		allCDs = RETAIN([[notification userInfo] objectForKey: @"cds"]);
	else
		DESTROY(allCDs);

	[cdTable reloadData];
}

- (void) tracksChanged: (id) notification
{
    NSArray *tracks = [[notification userInfo] objectForKey: @"Tracks"];

    [selected removeAllObjects];

	if (tracks && [tracks count] > 0) {
        NSEnumerator *e = [tracks objectEnumerator];
        id o = nil;
        while (nil != (o = [e nextObject])) {
            Track *track = (Track *)o;
            [selected addObject: [[[track source] componentsSeparatedByString: @"/"]
                objectAtIndex: 0]];
        }
    }

	[cdTable reloadData];
}

//
// outline view delegate methods
//

- (int) outlineView: (NSOutlineView *) outlineView 
		numberOfChildrenOfItem: (id) item
{
    NSEnumerator *e;
    id o;

    if (nil == item) {
        if (0 == [allCDs count]) {
            return 1;
        }
        return [allCDs count];
    }

    if (nil == allCDs) {
        return 0;
    }

    e = [allCDs objectEnumerator];
    while (nil != (o = [e nextObject])) {
        if ([[o objectForKey: @"cddbId"] isEqualToString: item]) {
            // per CD always two elements: author, title
            return 2;
        }
    }
    return 0;
}

- (id) outlineView: (NSOutlineView *) outlineView
			 child: (int) index
			ofItem: (id) item
{
    NSEnumerator *e;
    id o;

    if (nil == item) {
        if (0 == [allCDs count]) {
            return NOT_FOUND;
        }
        return [[allCDs objectAtIndex: index] objectForKey: @"cddbId"];
    }

    if (nil == allCDs) {
        return nil;
    }

    e = [allCDs objectEnumerator];
    while (nil != (o = [e nextObject])) {
        if ([[o objectForKey: @"cddbId"] isEqualToString: item]) {
            if (0 == index) {
                return [NSString stringWithFormat: @"%@: %@",
                       _(@"Common.artist"),
                       [o objectForKey: @"artist"]];
            } else {
                return [NSString stringWithFormat: @"%@: %@",
                       _(@"Common.title"),
                        [o objectForKey: @"title"]];
            }
        }
    }
    return nil;
}

- (BOOL) outlineView: (NSOutlineView *) outlineView
	isItemExpandable: (id) item
{
    if ([item isEqualToString: NOT_FOUND]) {
        return NO;
    }
    return (0 != [self outlineView: outlineView
      numberOfChildrenOfItem: item]);
}

- (id)            outlineView: (NSOutlineView *) outlineView 
    objectValueForTableColumn: (NSTableColumn *) tableColumn 
                       byItem: (id) item
{
    return item;
}

- (void) outlineView: (NSOutlineView *) outlineView
     willDisplayCell: (id) aCell
      forTableColumn: (NSTableColumn *) tableColumn
                item: (id) item
{
    if ([selected containsObject: item]
            || [selected containsObject: [outlineView parentForItem: item]]) {
        [aCell setTextColor: [NSColor blueColor]];
        return;
    }
    [aCell setTextColor: [NSColor controlTextColor]];
}

@end
