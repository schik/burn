/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	BurnCDHelper.m
 *
 *	Copyright (c) 2002-2005, 2011
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

#include "BurnCDHelper.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"
#include "Project.h"
#include "AppController.h"

#include "Burn/ExternalTools.h"



@implementation BurnCDHelper

- (id) initWithController: (BurnProgressController *)aController
{
    self = [super init];
    if (self) {
        controller = aController;
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (BOOL) isMediumInserted
{
	BOOL isInserted = NO;
    NSString *device = [[AppController appController] currentDevice];
    id writer = [[AppController appController] currentWriterBundle];

	if ([device isEqualToString: NOT_FOUND]) {
		return NO;
	}

	// We check first, whether we have the right CD and then rip the stuff.
	while (isInserted == NO) {
		if (![writer isWritableMediumInDevice: device
                                   parameters: [controller burnParameters]]) {
			int result = NSRunInformationalAlertPanel(APP_NAME,
				_(@"BurnCDHelper.insertCD"),
				_(@"Common.OK"), _(@"Common.cancel"), nil);
			if (result == NSAlertAlternateReturn) {
				if (NSRunAlertPanel(APP_NAME, _(@"GrabAudioCDHelper.reallyStop"),
							_(@"Common.no"), _(@"Common.yes"), nil) == NSAlertAlternateReturn) {
					break;
				}
			}
		} else {
			isInserted = YES;
		}
	};

	return isInserted;
}

- (enum StartHelperStatus) start: (NSString *) isoImageFile audioTracks: (NSArray *) audioTracks
{
	int i, count;
	NSMutableArray *burnTracks = [NSMutableArray arrayWithCapacity: 5];
	NSMutableArray *missingTracks = [NSMutableArray arrayWithCapacity: 5];
	NSMutableDictionary * threadObject;
	NSFileManager *fileMan = [NSFileManager defaultManager];

	currentTool = [[AppController appController] currentWriterBundle];
	if (nil == currentTool) {
        NSRunAlertPanel(APP_NAME,
						[NSString stringWithFormat: @"%@\n%@",
									_(@"BurnCDHelper.noProgram"),
									_(@"Common.stopProcess")],
						_(@"Common.OK"), nil, nil);
        return Failed;
	}

	// collect the tracks we must burn
	count = [audioTracks count];
	for (i = 0; i < count; i++) {
		Track *track = [audioTracks objectAtIndex: i];
		NSString *burnFile = [track storage];

		// if the file does not exist we add it it to the missing list
		if (![fileMan fileExistsAtPath: burnFile]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat: _(@"Common.fileNotFound"), burnFile]);
			[missingTracks addObject: burnFile];
		} else {
			[burnTracks addObject: track];
		}
	}

	if ([missingTracks count] != 0) {
		NSRunAlertPanel(APP_NAME,
						[NSString stringWithFormat: @"%@\n%@\n%@",
								_(@"BurnCDHelper.noFiles"),
								[missingTracks componentsJoinedByString: @"\n"],
								_(@"Common.stopProcess")],
						 _(@"Common.OK"), nil, nil);
		
		return Failed;
	}

	[controller setTitle: _(@"BurnCDHelper.title")];
    [controller setTrackProgress: 0. andLabel: @""];
    [controller hideTrackProgress: YES];
    [controller setEntireProgress: 0. andLabel: _(@"BurnCDHelper.settingUp")];

    if (![self isMediumInserted]) {
		return Failed;
    }

	threadObject = AUTORELEASE([[NSMutableDictionary alloc] initWithCapacity: 2]);

	[threadObject setObject: burnTracks forKey: @"tracks"];
    if (isoImageFile != nil)
    	[threadObject setObject: isoImageFile forKey: @"image"];
    if (audioTracks != nil)
    	[threadObject setObject: audioTracks forKey: @"audio"];


	[NSThread detachNewThreadSelector: @selector(burnTrackThread:)
							 toTarget: self
						   withObject: threadObject];

	[NSTimer scheduledTimerWithTimeInterval: 0.2
									 target: self
								   selector: @selector(updateStatus:)
								   userInfo: threadObject
									repeats: NO];

    return Started;
}

- (void) stop: (BOOL) immediately
{
    if (currentTool != nil) {
        [(id<BurnTool>)currentTool stop: immediately];
		logToConsole(MessageStatusError, _(@"Common.cancelled"));
    }
}


- (void) cleanUp: (BOOL) success
{
    if (currentTool != nil) {
        [(id<BurnTool>)currentTool cleanUp];
    }
}

- (void) burnTrackThread: (id)anObject
{
	BOOL result;
	Track *isoImage = nil;
	id pool = [NSAutoreleasePool new];
	id<Burner> burner = (id<Burner>)currentTool;
	NSDictionary *burnParameters = [controller burnParameters];
    NSString *isoImageFile = [anObject objectForKey: @"image"];

	if (isoImageFile)
		isoImage = [[[Track alloc] initWithDataFile: isoImageFile] autorelease];

	result = [burner burnCDFromImage: isoImage
					  andAudioTracks: [anObject objectForKey: @"tracks"]
					  withParameters: burnParameters];

	RELEASE(pool);
	[NSThread exit];
}

- (void) updateStatus: (id)timer
{
	BOOL reFire = YES;
	id<BurnTool> burner = currentTool;
	ToolStatus status = [burner getStatus];
	static int processStatus = isStopped;
    NSString *isoImageFile = [[timer userInfo] objectForKey: @"image"];
    NSArray *audioTracks = [[timer userInfo] objectForKey: @"audio"];

	switch (status.processStatus) {
	case isWaiting:
		if (status.processStatus != processStatus) {
            [controller hideTrackProgress: YES];
            [controller makeEntireProgressIndeterminate: YES];
		}
		break;

	case isPreparing:
		if (status.processStatus != processStatus) {
    		[controller setEntireProgress: -1 andLabel: _(@"BurnCDHelper.settingUp")];
    		[controller setTrackProgress: -1 andLabel: @""];
			[controller setAbortEnabled: YES];
            [controller hideTrackProgress: YES];
            [controller makeEntireProgressIndeterminate: YES];
		}
    	[controller setEntireProgress: status.entireProgress andLabel: nil];
		[controller setMiniwindowToTrack: status.trackProgress Entire: status.entireProgress];
		break;

	case isBurning:
		if (status.processStatus != processStatus) {
            [controller hideTrackProgress: NO];
            [controller makeEntireProgressIndeterminate: NO];
    		[controller setEntireProgress: -1 andLabel: _(@"BurnCDHelper.CDTotal")];
		}

		if (!isoImageFile) {
   			[controller setTrackProgress: status.trackProgress andLabel: [NSString stringWithFormat: _(@"Common.trackTitle"),
													[[audioTracks objectAtIndex: status.trackNumber-1] description]]];
		} else {
			if (status.trackNumber == 1)
    			[controller setTrackProgress: status.trackProgress andLabel: [NSString stringWithFormat: _(@"Common.trackTitle"), isoImageFile]];
			else
    			[controller setTrackProgress: status.trackProgress andLabel: [NSString stringWithFormat: _(@"Common.trackTitle"),
													[[audioTracks objectAtIndex: status.trackNumber-2] description]]];
		}

    	[controller setEntireProgress: status.entireProgress andLabel: nil];
		[controller setMiniwindowToTrack: status.trackProgress Entire: status.entireProgress];
		break;

	case isFixating:
		if (status.processStatus != processStatus) {
            [controller hideTrackProgress: YES];
            [controller makeEntireProgressIndeterminate: YES];
		}
		[controller setAbortEnabled: NO];
   		[controller setEntireProgress: status.entireProgress andLabel: _(@"BurnCDHelper.fixatingCD")];
		[controller setMiniwindowToTrack: status.trackProgress Entire: status.entireProgress];
		break;

	default:
		// otherwise we are stopped
		reFire = NO;
    	[controller setTrackProgress: 0. andLabel: nil];
    	[controller setEntireProgress: 0. andLabel: nil];
        [controller hideTrackProgress: YES];
        [controller makeEntireProgressIndeterminate: NO];

		// did we stop by 'Cancel' or by terminated thread?
		if (status.processStatus == isCancelled) {
			[controller nextStage: NO];
		} else {
			[controller nextStage: YES];
		}
	}
	processStatus = status.processStatus;

	if (reFire) {
		// re-schedule the timer
		[NSTimer scheduledTimerWithTimeInterval: 0.2
										 target: self
									   selector: @selector(updateStatus:)
									   userInfo: [timer userInfo]
									    repeats: NO];
	}
}

@end
