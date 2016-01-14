/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	CreateISOHelper+CreateISO.m
 *
 *	Copyright (c) 2002-2005
 *
 *	Author: Andreas Heppel <aheppel@web.de>
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

#include "CreateISOHelper.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"
#include "Project.h"
#include "AppController.h"

#include "Burn/ExternalTools.h"


@implementation CreateISOHelper


- (id) initWithController: (BurnProgressController *)aController
{
    self = [super init];
    if (self) {
        controller = aController;
        isoImageFile = nil;
    }
    return self;
}


- (void) dealloc
{
    RELEASE(isoImageFile);
    [super dealloc];
}

/**
 * access methods
 */ 
- (NSString *)isoImageFile
{
    return isoImageFile;
}

- (enum StartHelperStatus) start: (NSArray *) dataTracks volumeId: (NSString *)volumeId
{
	BOOL isDir, mustCreate = YES;
	int i, count;

	/*
	 * The following arrays are auto released.
	 * We do not need to keep them.
	 */
	NSMutableArray *fileNames = [NSMutableArray arrayWithCapacity: 5];
	NSMutableArray *missingTracks = [NSMutableArray arrayWithCapacity: 5];
	NSMutableDictionary * threadObject;
	NSFileManager *fileMan = [NSFileManager defaultManager];
	NSDictionary *params = [[controller burnParameters] objectForKey: @"SessionParameters"];
    NSString *tempDir = [params objectForKey: @"TempDirectory"];

	currentTool = [[AppController appController] currentMkisofsBundle];
	if (nil == currentTool) {
        NSRunAlertPanel(APP_NAME,
						[NSString stringWithFormat: @"%@\n%@",
									_(@"CreateISOHelper.noProgram"),
									_(@"Common.stopProcess")],
						_(@"Common.OK"), nil, nil);
        return Failed;
	}

    /* Collect the tracks we must burn. If there are
     * no tracks there is nothing to do. In fact, we are
     * not allowed to proceed further to not produce a
     * name for a not existing ISO image.
     */
	count = [dataTracks count];
    if (count == 0) {
        ASSIGN(isoImageFile, nil);
        return Done;
    }
 
	for (i = 0; i < count; i++) {
		Track *track = [dataTracks objectAtIndex: i];
		NSString *burnFile = [track source];

		// if the file does not exist we add it it to the missing list
		if (![fileMan fileExistsAtPath: burnFile]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat: _(@"Common.fileNotFound"), burnFile]);
			[missingTracks addObject: burnFile];
		} else {
			[fileNames addObject: track];
		}
	}

	if ([missingTracks count] != 0) {
		NSRunAlertPanel(APP_NAME,
						[NSString stringWithFormat: @"%@\n%@\n%@",
								_(@"CreateISOHelper.noFiles"),
								[missingTracks componentsJoinedByString: @"\n"],
								_(@"Common.stopProcess")],
						 _(@"Common.OK"), nil, nil);
		
		return Failed;
	}

	isoImageFile = [currentTool isoImageFile];
    if ((nil == isoImageFile) || [isoImageFile isEqualToString: @""]) {
	    isoImageFile = [tempDir stringByAppendingPathComponent:
		    				 [NSString stringWithFormat: @"%@.iso", volumeId]];
    }

	if (![fileMan fileExistsAtPath: isoImageFile isDirectory: &isDir]) {
		// if file does not exist, yet, we are fine
	} else if (!isDir) {
		// otherwise ask whether the file shall be reused, if it is a file
		int result = NSRunAlertPanel(APP_NAME,
							[NSString stringWithFormat: _(@"CreateISOHelper.imageExists"), isoImageFile],
							_(@"CreateISOHelper.useImage"), _(@"CreateISOHelper.overwrite"), _(@"CreateISOHelper.createNew"));

		switch (result) {
		case NSAlertDefaultReturn:
			mustCreate = NO;	// don't create an image
			break;
		case NSAlertAlternateReturn:
			break;
		case NSAlertOtherReturn:
			i = 0;
			do {
				// try new names
				NSString *tmp = [NSString stringWithFormat: @"%@-%d.iso",
                             [isoImageFile stringByDeletingPathExtension],
                             i];
				if (![fileMan fileExistsAtPath: tmp]) {
                    isoImageFile = tmp;
					break;
                }
				i++;
			} while(YES);

			// do something here
			break;
		}
	} else {
		// if it exists and is a directory we create a new image in
		// this directory
		NSString *isoDir = [isoImageFile copy];

		i = 0;
		do {
			// try new names
			isoImageFile = [isoDir stringByAppendingPathComponent:
						[NSString stringWithFormat: @"%@-%d.iso", volumeId, i]];
			if (![fileMan fileExistsAtPath: isoImageFile])
				break;
			i++;
		} while(YES);
		RELEASE(isoDir);
	}

	RETAIN(isoImageFile);

	/*
	 * If we reuse an already existing ISO image, we directly
	 * start the burning process and skip the rest
	 */
	if (!mustCreate) {
		[controller nextStage: YES];
		return Done;
	}

	threadObject = [[NSMutableDictionary alloc] initWithCapacity: 3];

	[threadObject setObject: fileNames forKey: @"tracks"];
	[threadObject setObject: isoImageFile forKey: @"image"];
	[threadObject setObject: volumeId forKey: @"volid"];

    [controller setTitle: _(@"CreateISOHelper.title")];
    [controller setTrackProgress: 0. andLabel: @""];
    [controller setEntireProgress: 0. andLabel: _(@"CreateISOHelper.settingUp")];

	creationStarted = NO;

	[NSThread detachNewThreadSelector: @selector(createImageThread:)
							 toTarget: self
						   withObject: threadObject];

	[NSTimer scheduledTimerWithTimeInterval: 0.4
									 target: self
								   selector: @selector(updateCreateISOProgress:)
								   userInfo: nil
								    repeats: NO];

	RELEASE(threadObject);
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
	BOOL keepTempFiles = [[[[controller burnParameters]
                                objectForKey: @"SessionParameters"]
                                    objectForKey: @"KeepISOImage"] boolValue];
	NSFileManager *fileMan = [NSFileManager defaultManager];

    if (currentTool != nil) {
        [(id<BurnTool>)currentTool cleanUp];
    }

	if ((keepTempFiles == NO) && isoImageFile) {
		logToConsole(MessageStatusInfo, [NSString stringWithFormat: _(@"Common.removeTempFile"), isoImageFile]);
		if (![fileMan removeFileAtPath: isoImageFile handler: nil]) {
			logToConsole(MessageStatusError, _(@"Common.removeFail"));
		}

		ASSIGN(isoImageFile, nil);
	}
}

- (void) createImageThread: (id)anObject
{
	id pool = [NSAutoreleasePool new];

    [currentTool createISOImage: [anObject objectForKey: @"volid"]
                     withTracks: [anObject objectForKey: @"tracks"]
                         toFile: [anObject objectForKey: @"image"]
                 withParameters: [controller burnParameters]];

	RELEASE(pool);
	[NSThread exit];
}

- (void) updateCreateISOProgress: (id) timer
{
    // silence compiler
	id isoCreator = currentTool;
	ToolStatus status = [isoCreator getStatus];

	if (status.processStatus == isPreparing) {
		[NSTimer scheduledTimerWithTimeInterval: 0.4
										target: self
										selector: @selector(updateCreateISOProgress:)
										userInfo: nil
										repeats: NO];

		return;
	}

	[controller setMiniwindowToTrack: status.entireProgress Entire: status.entireProgress];
	if (status.processStatus == isCreatingImage) {
		if (!creationStarted) {
			creationStarted = YES;
			[controller setAbortEnabled: YES];
    		[controller setEntireProgress: -1 andLabel: _(@"CreateISOHelper.creatingImage")];
		}
    	[controller setEntireProgress: status.entireProgress andLabel: nil];

		[NSTimer scheduledTimerWithTimeInterval: 0.4
										target: self
										selector: @selector(updateCreateISOProgress:)
										userInfo: nil
										repeats: NO];

		return;
	}

    [controller setEntireProgress: status.entireProgress
                         andLabel: nil];

	// did we stop by 'Cancel' or by terminated thread?
	if (status.processStatus == isCancelled) {
		[controller nextStage: NO];
	} else {
		[controller nextStage: YES];
	}
}

@end
