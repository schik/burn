/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  TrackInspector.m
 *
 *  Copyright (c) 2002-2005, 2011
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
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "AppController.h"
#include "TrackInspector.h"
#include "Functions.h"
#include "Constants.h"

#include <unistd.h>
#include <sys/types.h>


@implementation TrackInspector

// we need to keep the track info even is the inspector
// is closed
static NSArray *allTracks = nil;


- (id)init
{
	self = [super init];
	
	if(self) {
		// load the gui...
		if (![NSBundle loadNibNamed: @"TrackInspector" owner: self]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
								_(@"Common.loadNibFail"), @"TrackInspector"]);
			[self dealloc];
			return nil;
		} else {
			// initialize all member variables...
    		fileIcon = [NSImage imageNamed: @"iconDelete.tiff"];
   			multiIcon = [NSImage imageNamed: @"iconMultiSelection.tiff"];
			RETAIN(multiIcon);
			[typeIcon setImage: fileIcon];

			trackCount = 1;

			[self setTracks: allTracks];

			[[NSNotificationCenter defaultCenter] addObserver: self
			   selector: @selector(tracksChanged:)
			   name: TrackSelectionChanged
			   object: nil];
		}
	}		
	return self;
}

- (void)dealloc
{

	[[NSNotificationCenter defaultCenter] removeObserver: self
							name: TrackSelectionChanged
							object: nil];
	RELEASE(multiIcon);
	[super dealloc];
}

- (void) tracksChanged: (id)notification
{
	[self setTracks: [[notification userInfo] objectForKey: @"Tracks"]];
}

- (void) removeTracks
{
	if (allTracks != nil) {
		[allTracks release];
		allTracks = nil;
	}
	fileIcon = [NSImage imageNamed: @"iconDelete.tiff"];
	[typeIcon setImage: fileIcon];

	[nameField setStringValue: _(@"Common.noTracks")];
	[sourceField setStringValue: @""];
	[sizeField setStringValue: @""];
	[durationField setStringValue: @""];
	[typeField setStringValue: @""];
	[modifiedField setStringValue: @""];
    [openButton setEnabled: NO];
}

- (void) setTracks: (NSArray *)tracks
{
	if (!tracks || [tracks count] == 0) {
		[self removeTracks];
		return;
	}

	// if we got a new track array we get rid of the old one
	if(![tracks isEqualToArray: allTracks]) {
		[allTracks release];
		allTracks = [tracks retain];
	}

	trackCount = [allTracks count];

	curTrack = [allTracks objectAtIndex: 0];

	if (trackCount == 1) {   // Single Selection
		NSFileManager *fm = [NSFileManager defaultManager];
		NSDictionary *attrs = [fm fileAttributesAtPath: [curTrack source]
										  traverseLink: NO];
		NSDate *date = [attrs objectForKey: NSFileModificationDate];
		NSDateFormatter *df = AUTORELEASE([NSDateFormatter new]); 
		long duration = [curTrack duration];
		double size = [curTrack size];
		NSString *sizeFormat;
        BOOL enableOpen = YES;

		// calculate the size in kB or MB
		if (size < (1024.*1024.*0.25)) {
			size = size/1024.;
			sizeFormat = _(@"Common.kB");
		} else {
			size = size/1024./1024.;
			sizeFormat = _(@"Common.MB");
		}

		[nameField setStringValue: [curTrack description]];
		[sourceField setStringValue: [curTrack source]];
		[sizeField setStringValue: [NSString stringWithFormat: sizeFormat, size]];
		[durationField setStringValue: framesToString(duration)];

		[df setDateStyle: NSDateFormatterMediumStyle];
		[df setTimeStyle: NSDateFormatterMediumStyle];
		[modifiedField setStringValue: [df stringFromDate: date]];

		// set the type information according to the track type
		if ([[curTrack type] isEqual: @"audio:cd"]) {
			[typeField setStringValue: @"CD Audio"];
            enableOpen = NO;
		} else if ([[curTrack type] isEqual: @"audio:wav"]) {
			[typeField setStringValue: @"Audio (wav)"];
		} else if ([[curTrack type] isEqual: @"audio:au"]) {
			[typeField setStringValue: @"Audio (au)"];
		} else if ([[curTrack type] isEqual: @"data"]) {
			[typeField setStringValue: _(@"Common.data")];
		} else if ([[curTrack type] isEqual: @"dir"]) {
			[typeField setStringValue: _(@"Common.data")];
		} else {
			NSString *s = [curTrack type];
			NSRange r = [s rangeOfString: @":"];
			if (r.location != NSNotFound) {
				[typeField setStringValue:
					[NSString stringWithFormat: @"Audio (%@)",
							[s substringFromIndex: r.location+1]]];
			} else {
				[typeField setStringValue: _(@"Common.data")];
			}
		}
        [openButton setEnabled: enableOpen];
	} else {	   // Multiple Selection
		int i;
		long duration = 0;
		double size = 0.;
		NSString *sizeFormat;

		// if more than one track is selected, we display the total size
		// and time. Track type selection/display will not be possible
		[nameField setStringValue: [NSString stringWithFormat: _(@"Common.nrTracks"), trackCount]];
		[sourceField setStringValue: @""];

		for (i = 0; i < trackCount; i++) {
			duration += [(Track*)[allTracks objectAtIndex: i] duration];
			size += [(Track*)[allTracks objectAtIndex: i] size];
		}

		// calculate the size in kB or MB
		if (size < (1024.*1024.*0.25)) {
			size = size/1024.;
			sizeFormat = _(@"Common.kB");
		} else {
			size = size/1024./1024.;
			sizeFormat = _(@"Common.MB");
		}

		[sizeField setStringValue: [NSString stringWithFormat: sizeFormat, size]];
		[durationField setStringValue: framesToString(duration)];
		[typeField setStringValue: @""];
		[modifiedField setStringValue: @""];
        [openButton setEnabled: NO];
	}
	[self setImage];
}

- (void) setImage
{
	if (trackCount == 1) {   // Single Selection
		if ([[curTrack type] isEqual: @"audio:cd"])
			fileIcon = [NSImage imageNamed: @"iconAudioCD.tiff"];
		else
			fileIcon = [[NSWorkspace sharedWorkspace] iconForFile: [curTrack source]];
	} else {	   // Multiple Selection
		fileIcon = multiIcon;
	}
	[typeIcon setImage: fileIcon];
}

- (void)deactivate: (NSView *)view
{
	/* This gives the view back to its original parent */
	[(NSWindow*)window setContentView: view];
}

- (NSString *)inspectorName
{
	return _(@"TrackInspector.name");
}

- (NSString *)winname
{
	return [window title];
}

- (id) window
{
	return window;
}

- (void) openFile: (id) sender
{
	if (trackCount == 1) {   // Single Selection
		if (![[curTrack type] isEqual: @"audio:cd"])
			[[NSWorkspace sharedWorkspace] openFile: [curTrack source]];
	}
}

@end
