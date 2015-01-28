/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  BurnController.m
 *
 *  Copyright (c) 2005
 *
 *  Author: Andreas Schik <aheppel@web.de>
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

#include <unistd.h>

#include "BurnController.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]



static BurnController *singleInstance = nil;

@interface BurnController (Private)
- (void) checkForDrives;
- (struct burn_drive_info *)getBurnDrive: (NSDictionary *) parameters;
- (void) sendOutputString: (NSString *) outString;
- (void) setStatus: (ProcessStatus) status;
@end


/*
 * private interface
 */
@implementation BurnController (Private)

- (void) checkForDrives
{
	[[NSNotificationCenter defaultCenter]
				postNotificationName: DisplayWorkInProgress
				object: nil
				userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                            @"1", @"Start",
                            @"Burn", @"AppName",
                            @"Checking for drives. Please wait.", @"DisplayString",
                            nil]];

    while (!burn_drive_scan(&drives, &numDrives)) ;

	[[NSNotificationCenter defaultCenter]
				postNotificationName: DisplayWorkInProgress
				object: nil
				userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                            @"0", @"Start",
                            @"Burn", @"AppName",
                            nil]];
}

- (struct burn_drive_info *)getBurnDrive: (NSDictionary *) parameters
{
    int i;
    NSString *burnDevice;
	NSDictionary *tools =
			[parameters objectForKey: @"SelectedTools"];

	/*
	 * Retrieve the selected burner device from the params.
	 */
	burnDevice = [tools objectForKey: BurnDevice];

    for (i = 0; i < numDrives; i++) {
        NSString *drive = [NSString stringWithFormat: @"%s %s", drives[i].vendor, drives[i].product];
        if ([burnDevice rangeOfString: drive].location != NSNotFound)
            return &drives[i];
    }
	[self sendOutputString: [NSString stringWithFormat: @"%@\n%@",
										_(@"No burning device specified."),
										_(@"Process will be stopped.")]];

    return NULL;
}

- (void) sendOutputString: (NSString *) outString
{
	NSString *outLine;

	outLine = [NSString stringWithFormat: @"%@", outString];

	[[NSDistributedNotificationCenter defaultCenter]
					postNotificationName: ExternalToolOutput
					object: nil
					userInfo: [NSDictionary dictionaryWithObject: outLine forKey: Output]];
}

- (void) setStatus: (ProcessStatus) status
{
	[statusLock lock];
	toolStatus.processStatus = status;
	[statusLock unlock];
}

@end

//
// public interface
//

@implementation BurnController

- (id) init
{
	self = [super init];

	if (self) {
        if (!burn_initialize()) {
            [self dealloc];

            return nil;
        }
		statusLock = [NSLock new];
		[self checkForDrives];
	}

	return self;
}


- (void) dealloc
{
	singleInstance = nil;
	RELEASE(statusLock);

    /*
     * Release libburn structures.
     */
    burn_drive_info_free(drives);
    burn_finish();
	[super dealloc];
}

/*
 * BurnTool methods
 */
- (NSString *) name
{
	return @"burn";
}

- (id<PreferencesModule>) preferences;
{
	return nil;
}

- (id<PreferencesModule>) parameters;
{
	return nil;
}

- (void) cleanUp
{
}

- (BOOL) stop: (BOOL)immediately
{
	if (toolStatus.processStatus == isBurning) {
		[self sendOutputString: _(@"Terminating process.")];
        [self setStatus: isCancelled];
	}
	return YES;
}

- (ToolStatus) getStatus
{
	ToolStatus status;

	[statusLock lock];
	status = toolStatus;
	[statusLock unlock];
	return status;
}


//
// class methods
//
+ (id) singleInstance
{
	if (! singleInstance) {
		singleInstance = [[BurnController alloc] init];
	}

	return singleInstance;
}


/*
 * Burner methods
 */

/** Returns the list of drivers implemented by this burner
 * libburn does not implement special drivers.
 */
- (NSArray *) drivers
{
    return nil;
}

- (NSArray *) availableDrives
{
    int i;
    NSMutableArray *avDrives = [NSMutableArray array];

    for (i = 0; i < numDrives; i++) {
        NSString *drive = [NSString stringWithFormat: @"%s %s", drives[i].vendor, drives[i].product];
        [avDrives addObject: drive];
    }
    return avDrives;
}

- (NSDictionary *) mediaInformation: (NSDictionary *)parameters
{
    int nSessions;
    struct burn_drive_info *drive;
    struct burn_disc *disc;
    enum burn_disc_status dstatus;
    NSMutableDictionary *info = nil;

	/*
     * libburn does not deliver much useful information about
	 * the media in my drive, thus I preset the dictionary
     * with some defaults.
     */
	info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									_(@"Unknown"), @"type",
									@"n/a", @"vendor",
									@"n/a", @"speed",
									@"n/a", @"capacity",
									@"n/a", @"empty",
									@"n/a", @"remCapacity",
									@"n/a", @"sessions",
									@"n/a", @"appendable", nil];

    drive = [self getBurnDrive: parameters];
    if (!drive)
        return info;

    burn_drive_grab(drive->drive, 1);

    dstatus = burn_disc_get_status(drive->drive);

    if (dstatus == BURN_DISC_BLANK) {
        [info setObject: @"yes" forKey: @"empty"];
        [info setObject: @"0" forKey: @"sessions"];
    } else {
        [info setObject: @"no" forKey: @"empty"];

        /*
         * If the disc is not empty we check whether we can append
         * more data and how many sessions we have already on the disc.
         */
        if (dstatus == BURN_DISC_APPENDABLE)
            [info setObject: @"yes" forKey: @"appendable"];
        else
            [info setObject: @"no" forKey: @"appendable"];

        disc = burn_drive_get_disc(drive->drive);
        burn_disc_get_sessions(disc, &nSessions);
        [info setObject: [NSString stringWithFormat: @"%d", nSessions] forKey: @"sessions"];
        burn_disc_free(disc);
    }

    /*
     * Check whether it is a CD-R or a CD-RW
     */
    if (burn_disc_erasable(drive->drive) != 0)
        [info setObject: @"CD_RW" forKey: @"type"];
    else
        [info setObject: @"CD_R" forKey: @"type"];

    burn_drive_release(drive->drive, 0);
    return info;
}

- (BOOL) blankCDRW: (EBlankingMode)mode
	withParameters: (NSDictionary *) parameters
{
    struct burn_drive_info *drive;
	enum burn_disc_status s;
    drive = [self getBurnDrive: parameters];
    if (!drive)
        return NO;

    burn_drive_grab(drive->drive, 1);

    /*
     * Wait until the device is idle.
     */
    while (burn_drive_get_status(drive->drive, NULL)) {
        usleep(1000);
    }

    /*
     * Wait for a disc to be placed in the drive.
     */
    while ((s = burn_disc_get_status(drive->drive)) == BURN_DISC_UNREADY)
        usleep(1000);

    if (s != BURN_DISC_FULL) {
        NSString *dName = [NSString stringWithFormat: @"%s %s", drive->vendor, drive->product];
	    [self sendOutputString: [NSString stringWithFormat: _(@"There is no disk in '%@'."), dName]];
        burn_drive_release(drive->drive, 0);
        return YES;
    }

    /*
     * Check whether it is really a CD-RW.
     */
    if (burn_disc_erasable(drive->drive) == 0) {
        NSString *dName = [NSString stringWithFormat: @"%s %s", drive->vendor, drive->product];
	    [self sendOutputString: [NSString stringWithFormat: _(@"The disk in '%@' is not an erasable disk."), dName]];
        burn_drive_release(drive->drive, 0);
        return NO;
    }

    /*
     * The following check is due to libburn's documentation.
     * I don't know why this has to be.
     */
    if (burn_disc_get_status(drive->drive) != BURN_DISC_FULL) {
        NSString *dName = [NSString stringWithFormat: @"%s %s", drive->vendor, drive->product];
	    [self sendOutputString: [NSString stringWithFormat: _(@"The disk in '%@' cannot be erased."), dName]];
        burn_drive_release(drive->drive, 0);
        return NO;
    }

    burn_disc_erase(drive->drive, mode==fullBlank?0:1);

    burn_drive_release(drive->drive, 0);
    return YES;
}

- (BOOL) burnCDFromImage: (id)image
		  andAudioTracks: (NSArray *)trackArray
		  withParameters: (NSDictionary *) parameters
{
    return YES;
}

/*
 * IsoImageCreator methods
 */

- (BOOL) createISOImage: (NSString *) volumeID
			 withTracks: (NSArray *)trackArray
				 toFile: (NSString *)outFile
		 withParameters: (NSDictionary *) parameters
{
    return YES;
}


@end
