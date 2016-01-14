/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	ConvertAudioHelper.m
 *
 *	Copyright (c) 2005, 2011, 2016
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

#include "ConvertAudioHelper.h"

#include "Constants.h"
#include "Functions.h"
#include "AppController.h"
#include "Track.h"
#include "Project.h"

#include <AudioCD/AudioCDProtocol.h>
#include "Burn/ExternalTools.h"
#include <unistd.h>

/**
 * A private helper class to hold the data for one
 * conversion process.
 */
@interface ConvertProcess : NSObject
{
@public
    id tool;
    id data;
    NSMutableArray *tracks;
}
- (id) init;
- (void) setTool: (id) t;
- (void) setData: (id) d;
@end

@implementation ConvertProcess
- (id) init
{
    self = [super init];
    tool = nil;
    data = nil;
    tracks = [NSMutableArray new];
    return self;
}
- (void) dealloc
{
    RELEASE(tracks);
    RELEASE(tool);
    RELEASE(data);
    [super dealloc];
}
- (void) setTool: (id) t
{
    ASSIGN(tool, t);
}
- (void) setData: (id) d
{
    ASSIGN(data, d);
}
@end

@implementation ConvertAudioHelper

- (id) initWithController: (BurnProgressController *)aController
{
    self = [super init];
    if (self) {
        controller = aController;
        tempFiles = nil;
        processes = [NSMutableArray new];
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
    RELEASE(tempFiles);
    RELEASE(processes);
}

- (enum StartHelperStatus) start: (NSArray *)audioTracks
{
	enum StartHelperStatus ret = Done;
	NSMutableDictionary *processHelper = [NSMutableDictionary new];
	NSEnumerator *eTracks = [audioTracks objectEnumerator];
	Track *track = nil;
    id data = nil;

    if ((audioTracks == nil)
            || ([audioTracks count] == 0)) {
        return Done;
    }

	/*
	 * We iterate over the list of audio tracks. For each type we try to
	 * find an appropriate converter bundle. If we do, we add the track
	 * to an array which itself will be associated with the bundle's main
	 * object.
	 */
	while ((track = [eTracks nextObject]) != nil) {
		NSString *trackType = [track type];
		NSString *type = nil;
		id tool = nil;
		ConvertProcess *process;

		/*
		 * Ignore the built-in types.
		 */
		if ([trackType isEqualToString: @"audio:wav"]
				|| [trackType isEqualToString: @"audio:au"])
			continue;

		if (![trackType hasPrefix: @"audio:"])
			continue;

		type = [trackType substringFromIndex: [@"audio:" length]];

		/*
		 * Try to get a handle to the converter bundle for this file type.
		 */

        // Some special handling for CD tracks: For each detected audio CD
        // we create one separate process. This reduces CD switching if the
        // result will be a compilation from more than one source.
        if ([trackType isEqualToString: @"audio:cd"]) {
		    tool = [[AppController appController] currentCDGrabberBundle];
            data = [[[track source] componentsSeparatedByString: @"/"]
                objectAtIndex: 0]; 
            type = data;
        } else {
		    tool = [[AppController appController] currentAudioConverterBundle];
            data = nil;
        }
		if (nil == tool) {
    	    NSRunAlertPanel(APP_NAME,
							[NSString stringWithFormat: @"%@\n%@",
										_(@"ConvertAudioHelper.noProgram"),
										_(@"Common.stopProcess")],
							_(@"Common.OK"), nil, nil);
			ret = Failed;
	        goto clean_up;
		}

		process = [processHelper objectForKey: type];
		if (!process) {
			process = [ConvertProcess new];
            [process setTool: tool];
            [process setData: data];
	    	[processHelper setObject: process forKey: type];
            [processes addObject: process];
        }
        [process->tracks addObject: track];
	}

    /*
     * Release the helper dict and start the second stage.
     */
    if ([processes count] != 0) {
        ret = Started;
        nextProcess = 0;
        [self startNextProcess];
    }
clean_up:
    RELEASE(processHelper);
    return ret;
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
	BOOL keepTempFiles = [[[[controller burnParameters]
                                objectForKey: @"SessionParameters"]
                                    objectForKey: @"KeepTempWavs"] boolValue];
	NSFileManager *fileMan = [NSFileManager defaultManager];
    NSEnumerator *e = [processes objectEnumerator];
    ConvertProcess *p;

    while ((p = [e nextObject]) != nil) {
        [p->tool cleanUp];
    }

	if ((keepTempFiles == NO) && tempFiles) {
		NSString *file;
		int i, count = [tempFiles count];
		for (i = 0; i < count; i++) {
			file = [tempFiles objectAtIndex: i];
			logToConsole(MessageStatusInfo, [NSString stringWithFormat: _(@"Common.removeTempFile"), file]);
			if (![fileMan removeFileAtPath: file handler: nil]) {
				logToConsole(MessageStatusError, _(@"Common.removeFail"));
			}
		}

		RELEASE(tempFiles);
		tempFiles = nil;
	}
}

- (NSString *) checkCD: (NSString *) cddbId
{
	BOOL isRightCD = NO;
	NSString *sourceDevice = nil;
	id<AudioCDProtocol> audioCD = loadAudioCD();

	if (!audioCD) {
		return nil;
	}

    [audioCD startPollingWithPreferredDevice: nil];

	// Give the AudioCD.bundle some time to load the CD.
	sleep(1);

	// We check first, whether we have the right CD and then rip the stuff.
	while (isRightCD == NO) {
		if (![audioCD checkForCDWithId: cddbId]) {
			int result = NSRunInformationalAlertPanel(APP_NAME,
				[NSString stringWithFormat: _(@"GrabAudioCDHelper.insertCD"),
											[[[controller cdList] objectForKey: cddbId] objectForKey: @"artist"],
											[[[controller cdList] objectForKey: cddbId] objectForKey: @"title"]],
				_(@"Common.OK"), _(@"Common.cancel"), nil);
			if (result == NSAlertAlternateReturn) {
				if (NSRunAlertPanel(APP_NAME, _(@"GrabAudioCDHelper.reallyStop"),
							_(@"Common.no"), _(@"Common.yes"), nil) == NSAlertAlternateReturn) {
					break;
				}
			}
		} else {
			sourceDevice = [[audioCD device] copy];
			isRightCD = YES;
		}
	};

    [audioCD stopPolling];
	DESTROY(audioCD);

	return sourceDevice;
}


- (void) startNextProcess
{
	NSString *sourceDevice;
    ConvertProcess *process;
    // We know, that the dictionary returned here is mutable!
    // Silence the compiler!
	NSMutableDictionary *burnParameters = (NSMutableDictionary *)[controller burnParameters];

    if (nextProcess >= [processes count]) {
		logToConsole(MessageStatusInfo, _(@"ConvertAudioHelper.success"));
        [controller nextStage: YES];
        return;
    }

    process = [processes objectAtIndex: nextProcess++];

    [controller setTitle: _(@"ConvertAudioHelper.preparing")];
    [controller setTrackProgress: 0. andLabel: @""];

    // trigger CD switching if necessary
    if ([process->tool isCDGrabber] == YES) {
       	NSDictionary *cd = [[controller cdList] objectForKey: process->data];
        NSString *entireProgresstext = [NSString stringWithFormat:
											_(@"GrabAudioCDHelper.CDTitle"),
											[cd objectForKey: @"artist"],
											[cd objectForKey: @"title"]];

        [controller setEntireProgress: 0. andLabel: entireProgresstext];
        sourceDevice = [self checkCD: process->data];
        if (!sourceDevice) {
            [controller nextStage: NO];
            return;
        }

	    [burnParameters setObject: sourceDevice forKey: @"SourceDevice"];
    	RELEASE(sourceDevice);
    	[burnParameters setObject: process->data forKey: @"CddbId"];
    } else {
       [controller setEntireProgress: 0. andLabel: _(@"ConvertAudioHelper.allTracks")];
    }

	// now get it
	[NSThread detachNewThreadSelector: @selector(convertThread:)
							 toTarget: self
						   withObject: process];

	[NSTimer scheduledTimerWithTimeInterval: 0.4
									 target: self
								   selector: @selector(updateStatus:)
								   userInfo: nil
									repeats: NO];
}


- (void) convertThread: (id)anObject
{
	int i;
	BOOL result = YES;
	id pool = [NSAutoreleasePool new];
	NSDictionary *burnParameters = [controller burnParameters];
	id<AudioConverter> converter = ((ConvertProcess *)anObject)->tool;
	NSArray *tracks = ((ConvertProcess *)anObject)->tracks;

	currentTool = (id<BurnTool>)converter;
	result = [converter convertTracks: tracks withParameters: burnParameters];

	if (result) {
		if (!tempFiles) {
			tempFiles = [NSMutableArray new];
		}
		// add file to list of temporary files
		for (i = 0; i < [tracks count]; i++) {
			Track *track = [tracks objectAtIndex: i];
			[tempFiles addObject: [track storage]];
		}
	}

	RELEASE(pool);
	[NSThread exit];
}

- (void) updateStatus: (id)timer
{
	ToolStatus status;
	id<BurnTool> converter = currentTool;

	status = [converter getStatus];

	[controller setMiniwindowToTrack: status.trackProgress Entire: status.entireProgress];

	if (status.processStatus == isConverting) {
        [controller setTrackProgress: status.trackProgress
                            andLabel: [NSString stringWithFormat: _(@"Common.trackTitle"), status.trackName]];
        [controller setEntireProgress: status.entireProgress
                             andLabel: nil];
        
		[NSTimer scheduledTimerWithTimeInterval: 0.4
										target: self
										selector: @selector(updateStatus:)
										userInfo: nil
										repeats: NO];

		return;
	}

	// did we stop by 'Cancel' or by terminated thread?
	if (status.processStatus == isCancelled) {
		[controller nextStage: NO];
	} else {
        [controller setTrackProgress: status.trackProgress
                            andLabel: nil];
        [controller setEntireProgress: status.entireProgress
                             andLabel: nil];

        /*
         * -startNextProcess will determine whether we are
         * finished or not. Hence, we do not need to call
         * the controller's -nextStage: method here.
         */
		[self startNextProcess];
	}
}

@end
