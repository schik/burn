/* vim: set ft=objc et sw=4 ts=4 expandtab nowrap: */
/*
 *  CDrecordController.m
 *
 *  Copyright (c) 2002-2015
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <sys/types.h>
#include <sys/wait.h>


#include "CDrecordController.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"

#ifdef _
#undef _
#endif

#define _(X) \
    [[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]


@implementation CDrecordController (Private)

/**
 * <p>checkForDrives runs <strong>cdrecord</strong> to get the list
 * of available drives. For performance reasons this should be done
 * only once when the bundle is loaded.
 */

NSString *writemodes[] = {
    @"",
    @"-dao",
    @"-raw96r",
    @"-raw96p",
    @"-raw16"
};

/**
 * Tries to find the cdrecord executable in case it is not already set
 * in the defaults.
 */
- (void) initializeFromDefaults
{
    NSString *program;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CDrecordParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    program = [mutableParams objectForKey: @"Program"];
    if ((nil != program) && ![program isEqualToString: NOT_FOUND]) {
        if (!checkProgram(program)) {
            program = NOT_FOUND;
        }
    } else {
        program = which(@"cdrecord");
    }

    [mutableParams setObject: program forKey: @"Program"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"CDrecordParameters"];
    RELEASE(mutableParams);
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) checkForDrives
{
    NSString *transport;
    NSString *cdrecord;
    int      count, j;
    NSDictionary *parameters =
            [[NSUserDefaults standardUserDefaults] objectForKey: @"CDrecordParameters"];

    cdrecord = [parameters objectForKey: @"Program"];

    if ((nil == cdrecord) || [cdrecord isEqualToString: NOT_FOUND]) {
        cdrecord = which(@"cdrecord");
    }
    /*
     * It may be that cdrecord cannot be found. In this case
     * we cannot do anything here.
     */
    if (!checkProgram(cdrecord))
        return;

    transport = [parameters objectForKey: @"Transport"];

    [[NSNotificationCenter defaultCenter]
                postNotificationName: DisplayWorkInProgress
                object: nil
                userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                            @"1", @"Start",
                            @"cdrecord", @"AppName",
                            @"Checking for drives. Please wait.", @"DisplayString",
                            nil]];

    [drives removeAllObjects];

    NSPipe *stdOut = [[NSPipe alloc] init];
    NSMutableArray* cdrArgs = [[NSMutableArray alloc] init];
    NSArray *output;

    if ((nil != transport) && [transport length])
        [cdrArgs addObject: [NSString stringWithFormat: @"dev=%@", transport]];
    [cdrArgs addObject: [NSString stringWithFormat: @"-scanbus"]];

    cdrTask = [[NSTask alloc] init];
    [cdrTask setLaunchPath: cdrecord];
    [cdrTask setArguments: cdrArgs];
    [cdrTask setStandardOutput: stdOut];
    [cdrTask setStandardError: stdOut];

    [cdrTask launch];

    [cdrTask waitUntilExit];

    output = [[[NSString alloc] initWithData: [[stdOut fileHandleForReading] availableData]
                                   encoding: NSISOLatin1StringEncoding] componentsSeparatedByString: @"\n"];

    count = [output count];

    for (j = 0; j < count; j++) {
        NSString *line;
        NSString *vendorString, *modelString, *revString;
        NSString *busIdLunString;

        line = [[output objectAtIndex: j] stringByTrimmingLeadSpaces];

        /*
         * Check whether it is a CD-ROM, first.
         */
        if (([line rangeOfString: @"CD-ROM"].location != NSNotFound)) {
            /* triple of bus, id, lun comes first */
            busIdLunString = [line substringToIndex: [line rangeOfString: @"\t"].location];
            line = [line substringFromIndex: [line rangeOfString: @"'"].location+1];

            /* Vendor, Model, Revision are encapsulated by ' */
            vendorString = [[line substringToIndex: [line rangeOfString: @"\'"].location] stringByTrimmingSpaces];
            line = [line substringFromIndex: [line rangeOfString: @"' '"].location+3];
            modelString = [[line substringToIndex: [line rangeOfString: @"\'"].location] stringByTrimmingSpaces];
            line = [line substringFromIndex: [line rangeOfString: @"' '"].location+3];
            revString = [[line substringToIndex: [line rangeOfString: @"\'"].location] stringByTrimmingSpaces];

            if ([transport isEqualToString:@"ATAPI:"]) {
                [drives setObject: transport
                           forKey: [NSString stringWithFormat: @"%@: %@ %@ %@",
                                                                busIdLunString,
                                                                vendorString, modelString, revString]];
            } else if ([transport length]) {
                [drives setObject: transport
                           forKey: [NSString stringWithFormat: @"%@: %@ %@ %@",
                                                                transport,
                                                                vendorString, modelString, revString]];
            } else {
                [drives setObject: @""
                           forKey: [NSString stringWithFormat: @"%@: %@ %@ %@",
                                                                busIdLunString,
                                                                vendorString, modelString, revString]];
            }
        }
    }

    [[NSNotificationCenter defaultCenter]
                postNotificationName: DisplayWorkInProgress
                object: nil
                userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                            @"0", @"Start",
                            @"cdrecord", @"AppName",
                            nil]];
}


/**
 * <p>getCDrecordDrivers starts <strong>cdrecord</strong> with the
 * parameter <strong>driver=help</strong> to retrieve a list of all
 * built-in drivers.</p>
 * <p>No new thread is started as this takes only a very short amount
 * of time, and the caller must wait for the result anyway.</p>
 */
- (void) getCDrecordDrivers
{
    int termStatus;
    NSString *cdrecord;
    NSPipe *cdrStdout;
    NSFileHandle *hdl;
    NSArray *cdrOutput;
    NSString *outLine;
    NSArray *cdrArgs;
    int count, i;
    NSDictionary *parameters =
            [[NSUserDefaults standardUserDefaults] objectForKey: @"CDrecordParameters"];

    [drivers removeAllObjects];
    [drivers addObject: @"Default"];

    cdrecord = [parameters objectForKey: @"Program"];

    if (!checkProgram(cdrecord))
        return;

    cdrStdout = [[NSPipe alloc] init];
    cdrTask = [[NSTask alloc] init];

    cdrArgs = [NSArray arrayWithObjects:
                    [NSString stringWithString: @"driver=help"],
                    nil];

    [cdrTask setLaunchPath: cdrecord];
    [cdrTask setArguments: cdrArgs];

    [cdrTask setStandardError: cdrStdout];
    [cdrTask launch];
    [cdrTask waitUntilExit];

    // FreeBSD needs an lvalue for the WEXITSTATUS macros
    termStatus = [cdrTask terminationStatus];
    if (WEXITSTATUS(termStatus) == 0) {
        hdl = [cdrStdout fileHandleForReading];
        cdrOutput = [[[NSString alloc] initWithData: [hdl availableData]
                                        encoding: NSISOLatin1StringEncoding]
                        componentsSeparatedByString: @"\n"];

        count = [cdrOutput count];
        /*
         * Skip the first line in output. It contains only header data.
         */
        for (i = 1; i < count; i++) {
            NSRange range;
            outLine = [cdrOutput objectAtIndex: i];
            range = [outLine rangeOfCharacterFromSet: [NSCharacterSet whitespaceCharacterSet]];
            if (range.location != NSNotFound) {
                [drivers addObject: [outLine substringToIndex: range.location]];
            }
        }
    }

    RELEASE(cdrTask);
    RELEASE(cdrStdout);
}


/**
 * <p>waitForEndOfBurning waits until the current burning process
 * is finished.</p>
 * <p>The method reads the output from <strong>cdrecord</strong>
 * and processes it. This means that waitForEndOfBurning updates
 * the different progress values (entire progress, track progress,...)
 * and sends <strong>cdrecord</strong>'s output to the console.</p>
 */
- (void) waitForEndOfBurning
{
    BOOL sendLine;
    int actCDProgress;
    int maxCDProgress;
    int maxTrackProgress, curTrackProgress;

    maxCDProgress = 0;
    actCDProgress = 0;
    maxTrackProgress = 0;
    curTrackProgress = 0;

    while ([cdrTask isRunning]) {
        NSData *inData;
        while ((inData = [[[cdrTask standardError] fileHandleForReading] availableData])
                 && [inData length]) {
            int i, count;
            NSString *aLine;
            NSArray *theOutput;

            theOutput = [[[NSString alloc] initWithData: inData
                                    encoding: NSISOLatin1StringEncoding]
                                    componentsSeparatedByString: @"\n"];

            count = [theOutput count];

            for (i = 0; i < count; i++) {
                aLine = [theOutput objectAtIndex: i];
                if (aLine && [aLine length])
                    sendLine = YES;
                else
                    sendLine = NO;  // don't send empty lines

                if (burnStatus.processStatus == isWaiting) {
                    NSRange aRange = [aLine rangeOfString: @"No disk / Wrong disk!"];
                    if (aRange.location != NSNotFound) {
                        [statusLock lock];
                        burnStatus.processStatus = isCancelled;
                        [statusLock unlock];
                        break;
                    }

                    aRange = [aLine rangeOfString: @"Total size:"];
                    if (aRange.location != NSNotFound) {
                        maxCDProgress = [[aLine substringFromIndex: aRange.location + aRange.length] intValue];
                    }

                    aRange = [aLine rangeOfString: @"Operation starts."];
                    if (aRange.location != NSNotFound) {
                        [statusLock lock];
                        burnStatus.processStatus = isPreparing;
                        [statusLock unlock];
                    }
                } else if ((burnStatus.processStatus == isPreparing)
                            || (burnStatus.processStatus == isBurning)) {
                    NSRange aRange = [aLine rangeOfString: @"Starting new track"];
                    if (aRange.location != NSNotFound) {
                        [statusLock lock];
                        actCDProgress += curTrackProgress;
                        burnStatus.trackProgress = 0.;
                        curTrackProgress = 0.;
                        burnStatus.trackNumber++;
                        [statusLock unlock];
                        sendLine = NO;
                    }
                    aRange = [aLine rangeOfString: @"MB written (fifo"];
                    if (aRange.location != NSNotFound) {
                        [statusLock lock];
                        aRange = [aLine rangeOfString: @"of"];
                        if (burnStatus.processStatus == isPreparing) {
                            maxTrackProgress = [[aLine substringFromIndex: aRange.location + aRange.length] intValue];
                            burnStatus.processStatus = isBurning;
                        }

                        curTrackProgress = [[aLine substringWithRange: NSMakeRange(aRange.location-5, 5)] intValue];
                        burnStatus.trackProgress = curTrackProgress * 100. / maxTrackProgress;
                        aRange = [aLine rangeOfString: @"[buf"];
                        // if cdrecord does not report the buffer level, we simply assume 100%
                        if (aRange.location != NSNotFound) {
                            burnStatus.bufferLevel = [[aLine substringFromIndex: aRange.location + aRange.length] doubleValue];
                        } else {
                            burnStatus.bufferLevel = 100;
                        }
                        burnStatus.entireProgress = (actCDProgress + curTrackProgress) * 100. / maxCDProgress;
                        [statusLock unlock];
                        sendLine = NO;
                    } else {
                        aRange = [aLine rangeOfString: @"Fixating"];
                        if (aRange.location != NSNotFound) {
                            [statusLock lock];
                            burnStatus.processStatus = isFixating;
                            burnStatus.trackProgress = 0.;
                            burnStatus.bufferLevel = 0.;
                            burnStatus.entireProgress = 0.;
                            [statusLock unlock];
                        }
                    }
                }

                // post the oputput to the progress panel
                if (sendLine) {
                    [self sendOutputString: aLine raw: YES];
                }
            }   // for (i = 0; i < count; i++)
        }   // while ((inData = 
    }   // while ([cdrTask isRunning])
}

- (NSString *) idForDevice: (NSString *) device
{
    NSRange range = NSMakeRange(NSNotFound, 0);
    /*
     * Now extract the SCSI device ID from the device string.
     * The format of the string is: "X,Y,Z: Device Name"
     * On OpenBSD the string is: "/dev/cdXc: Device Name"
     */
    if (device && [device length]) {
        range = [device rangeOfString: @": "];
    }

    if (range.location == NSNotFound) {
        return nil;
    }

    return [device substringToIndex: range.location];
}

- (NSMutableArray *) makeParamsForTask: (CDrecordTask) task
                        withParameters: (NSDictionary *) parameters
{
    NSString *burnDevice;
    NSString *transport;
    NSString *nextParam;
    NSMutableArray *cdrArgs;
    NSDictionary *availDrivers;
    NSDictionary *sessionParams =
            [parameters objectForKey: @"SessionParameters"];
    NSDictionary *cdrParams =
            [parameters objectForKey: @"CDrecordParameters"];
    NSDictionary *tools =
            [parameters objectForKey: @"SelectedTools"];
    int mode;

    /*
     * Retrieve the selected burner device from the params and then get
     * the list of assigned drivers for this device.
     */
    burnDevice = [tools objectForKey: BurnDevice];
    transport = [drives objectForKey: burnDevice];

    availDrivers = [[parameters objectForKey: Drivers]
                        objectForKey: burnDevice];
 
    /*
     * Now extract the SCSI device ID from the device string.
     * The format of the string is: "X,Y,Z: Device Name"
     * On OpenBSD the string is: "/dev/cdXc: Device Name"
     */
    burnDevice = [self idForDevice: burnDevice];

    if (nil == burnDevice) {
        [self sendOutputString: [NSString stringWithFormat: @"%@\n%@",
                                            _(@"No burning device specified."),
                                            _(@"Process will be stopped.")] raw: NO];

        [NSException raise: NSInternalInconsistencyException
                    format: @"cdrecord cannot find a burning device."];
    }

    /* The array is autoreleased! Don't release it here!!! */
    cdrArgs = [NSMutableArray arrayWithObjects: @"-v", nil];

    // set device
    if (transport && [transport isEqualToString:@"ATAPI:"]) {
        [cdrArgs addObject: [NSString stringWithFormat: @"dev=%@%@", transport, burnDevice]];
    } else {
        [cdrArgs addObject: [NSString stringWithFormat: @"dev=%@", burnDevice]];
    }

    // we don't need the next stuff to simply eject the disk
    if (task != TaskEject) {
        // set driver and options
        nextParam = [availDrivers objectForKey: [self name]];
        if (nextParam && [nextParam length] && ![nextParam isEqual: @"Default"]) {
            [cdrArgs addObject: [NSString stringWithFormat: @"driver=%@", nextParam]];
        }

        nextParam = [cdrParams objectForKey: DriverOptions];
        if (nextParam && [nextParam length]) {
            [cdrArgs addObject: [NSString stringWithFormat: @"driveropts=%@", nextParam]];
        }
    }

    // make param string for burn command
    switch (task) {
    case TaskBurn:
        // set speed
        nextParam = [sessionParams objectForKey: BurnSpeed];
        if (nextParam && [nextParam length]) {
            [cdrArgs addObject: [NSString stringWithFormat: @"-speed=%@", nextParam]];
        } else {
            [cdrArgs addObject: [NSString stringWithFormat: @"-speed=0"]];
        }

        if ([cdrParams objectForKey: @"WriteMode"]) {
            mode = [[cdrParams objectForKey: @"WriteMode"] intValue];
        } else if ([[cdrParams objectForKey: @"TrackAtOnce"] boolValue] == NO) {
            mode = SessionAtOnce;
        } else {
            mode = TrackAtOnce;
        }

        if (mode > TrackAtOnce) {
            [cdrArgs addObject: writemodes[mode]];
        }

        if ([[sessionParams objectForKey: TestOnly] intValue]) {
            [cdrArgs addObject: @"-dummy"];
        }
        if ([[sessionParams objectForKey: EjectCD] boolValue] == YES) {
            [cdrArgs addObject: @"-eject"];
        }
        if ([[sessionParams objectForKey: Overburn] boolValue] == YES) {
            [cdrArgs addObject: @"-overburn"];
        }

        break;
    case TaskEject:
        // eject media
        [cdrArgs addObject: @"-eject"];
        [cdrArgs addObject: @"-dummy"];
        break;
    }

    return cdrArgs;
}

- (void) addDevice: (NSString *) device
     andParameters: (NSDictionary *) parameters
       toArguments: (NSMutableArray *) args
{
    NSString *dev;
    NSString *nextParam;
    NSDictionary *cdrParams =
            [parameters objectForKey: @"CDrecordParameters"];
    NSDictionary *driverPrefs =
            [[parameters objectForKey: Drivers] objectForKey: device];

    dev = [self idForDevice: device];
    if (nil != dev) {
        NSString *transport = [drives objectForKey: device];

        if (transport && [transport isEqualToString:@"ATAPI:"]) {
            [args addObject: [NSString stringWithFormat: @"dev=%@%@", transport, dev]];
        } else {
            [args addObject: [NSString stringWithFormat: @"dev=%@", dev]];
        }

        // set driver and options
        nextParam = [driverPrefs objectForKey: [self name]];
        if (nextParam && [nextParam length] && ![nextParam isEqual: @"Default"]) {
            [args addObject: [NSString stringWithFormat: @"driver=%@", nextParam]];
        }

        nextParam = [cdrParams objectForKey: DriverOptions];
        if (nextParam && [nextParam length]) {
            [args addObject: [NSString stringWithFormat: @"driveropts=%@", nextParam]];
        }
    }else {
        [self sendOutputString: [NSString stringWithFormat: @"%@\n%@",
                                            _(@"No burning device specified."),
                                            _(@"Process will be stopped.")] raw: NO];

        [NSException raise: NSInternalInconsistencyException
                    format: @"cdrecord cannot find a burning device."];

    }
}

- (void) appendTrackArgs: (NSMutableArray *)args forCDROM: (BOOL)isCDROM
{
    int i, count;
    Track *track;

    count = [burnTracks count];

    if (isCDROM) {
        [args addObject: @"-data"];
        track = [burnTracks objectAtIndex: 0];
        [args addObject: [track storage]];
        if (count > 1) {
            [args addObject: @"-audio"];
            [args addObject: @"-pad"];
        }
    } else {
        [args addObject: @"-audio"];
        [args addObject: @"-pad"];
    }

    i = isCDROM ? 1 : 0;
    for (; i < count; i++) {
        track = [burnTracks objectAtIndex: i];
        NSString *storage = [track storage];

        [args addObject: storage];
    }
}

- (void) sendOutputString: (NSString *)outString raw: (BOOL)raw
{
    NSString *outLine;

    if (raw == NO)
        outLine = [NSString stringWithFormat: @"**** %@ ****", outString];
    else
        outLine = outString;

    [[NSDistributedNotificationCenter defaultCenter]
                    postNotificationName: ExternalToolOutput
                    object: nil
                    userInfo: [NSDictionary dictionaryWithObject: outLine forKey: @"Output"]];
}

- (NSDictionary *) atipInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *) parameters
{
	int i, count;
	NSString *cdrecord;
	NSMutableArray *cdrArgs;
	NSPipe *stdOut;
	NSArray *cdrOutput;
	NSString *outLine;

	// cdrecord does not deliver useful information about
	// the media on my drive, thus I don't know the output
	// preset the dictionary with some defaults
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									_(@"Unknown"), @"type",
									@"n/a", @"vendor",
									@"n/a", @"speed",
									@"n/a", @"capacity",
									@"n/a", @"empty",
									@"n/a", @"remCapacity",
									@"n/a", @"sessions",
									@"n/a", @"appendable", nil];


	cdrecord = [[parameters objectForKey: @"CDrecordParameters"]
                    objectForKey: @"Program"];

    if (!checkProgram(cdrecord))
        return info;

    cdrArgs = [NSMutableArray arrayWithObjects: @"-v", nil];
	NS_DURING
        [self addDevice: device
          andParameters: parameters
            toArguments: cdrArgs];
	NS_HANDLER
		[self sendOutputString: [NSString stringWithFormat: @"Error: %@ -> %@",
												[localException name],
												[localException reason]] raw: NO];
		NS_VALRETURN(nil);
	NS_ENDHANDLER

    [cdrArgs addObject: @"-atip"];

	// set up cdrecord task
	cdrTask = [[NSTask alloc] init];
	stdOut = [[NSPipe alloc] init];

	[cdrTask setLaunchPath: cdrecord];

	[cdrTask setArguments: cdrArgs];
	[cdrTask setStandardOutput: stdOut];
	[cdrTask setStandardError: stdOut];

	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
										cdrecord, [cdrArgs componentsJoinedByString: @" "]] raw: NO];
	[cdrTask launch];

	[cdrTask waitUntilExit];

	/*
	 * If cdrecord did not terminate gracefully we stop the whole affair.
	 * We delete in any case the actual (not finished) file.
	 */
	{
        int termStatus = [cdrTask terminationStatus];	// FreeBSD needs an lvalue for the WIF* macros
    	if ((WIFEXITED(termStatus) == 0)
	    		|| WIFSIGNALED(termStatus)) {
		    [info setObject: _(@"Unknown") forKey: @"type"];
    		return info;
        }
	}

	cdrOutput = [[[NSString alloc] initWithData: [[stdOut fileHandleForReading] availableData]
									encoding: NSISOLatin1StringEncoding]
					componentsSeparatedByString: @"\n"];

	count = [cdrOutput count];

	/*
	 * Skip the first line in output. It contains only header data.
	 */
	for (i = 1; i < count; i++) {
		NSRange range;
		outLine = [cdrOutput objectAtIndex: i];

        // wodim is rather stupid as it can only read ATIP info, which
        // itself does not contain info about whether the disk is empty
        // or not. If we get ATIP info, we assume that the disk is empty.
		range = [outLine rangeOfString: @"ATIP info from disk"];
		if (range.location != NSNotFound) {
			[info setObject: @"yes" forKey: @"empty"];
			continue;
		}

		// check for not erasable first, then for erasable
		// if none applies don#t change the dictionary
		range = [outLine rangeOfString: @"Is not erasable"];
		if (range.location != NSNotFound) {
			[info setObject: @"CD-R" forKey: @"type"];
			continue;
		} else {
			range = [outLine rangeOfString: @"Is erasable"];
			if (range.location != NSNotFound) {
				[info setObject: @"CD-RW" forKey: @"type"];
				continue;
			}
		}

		// search manufacturer/vendor
		range = [outLine rangeOfString: @"Manufacturer"];
		if (range.location != NSNotFound) {
			if ([outLine length] > range.location+13)
				[info setObject: [outLine substringFromIndex: 14] forKey: @"vendor"];
			continue;
		}

		range = [outLine rangeOfString: @"  speed low"];
		if (range.location != NSNotFound) {
			NSRange range1 = [outLine rangeOfString: @"speed high"];
			if ([outLine length] > range1.location+11)
				[info setObject: [NSString stringWithFormat: @"%dX - %dX",
									[[outLine substringFromIndex: 13] intValue],
									[[outLine substringFromIndex: range1.location+12] intValue]]
						forKey: @"speed"];
			continue;
		}
		range = [outLine rangeOfString: @"ATIP start of lead out"];
		if (range.location != NSNotFound) {
			if ([outLine length] > 41) {
				int frames = [[outLine substringFromIndex: 26] intValue];
				NSString *str = [NSString stringWithFormat: @"%@ - %d blocks, %d/%d MB",
									[outLine substringWithRange: NSMakeRange(34,8)],
									frames,
									frames * 2048 / (1024*1024),
									frames * 2352 / (1024*1024)];
				[info setObject: str forKey: @"capacity"];
			} else
				[info setObject: [outLine substringFromIndex: 26] forKey: @"capacity"];

			continue;
		}
	}

	RELEASE(stdOut);
	RELEASE(cdrTask);

	return info;
}

- (NSDictionary *) minfoInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *) parameters
{
    int i, count;
    NSString *cdrecord;
    NSMutableArray *cdrArgs;
    NSPipe *stdOut;
    NSArray *cdrOutput;
    NSString *outLine;

    // cdrecord does not deliver useful information about
    // the media on my drive, thus I don't know the output
    // preset the dictionary with some defaults
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    _(@"Unknown"), @"type",
                                    @"n/a", @"vendor",
                                    @"n/a", @"speed",
                                    @"n/a", @"capacity",
                                    @"n/a", @"empty",
                                    @"n/a", @"remCapacity",
                                    @"n/a", @"sessions",
                                    @"n/a", @"appendable", nil];


    cdrecord = [[parameters objectForKey: @"CDrecordParameters"]
                    objectForKey: @"Program"];

    if (!checkProgram(cdrecord))
        return info;

    cdrArgs = [NSMutableArray arrayWithObjects: @"-v", nil];
    NS_DURING
        [self addDevice: device
          andParameters: parameters
            toArguments: cdrArgs];
    NS_HANDLER
        [self sendOutputString: [NSString stringWithFormat: @"Error: %@ -> %@",
                                                [localException name],
                                                [localException reason]] raw: NO];
        NS_VALRETURN(nil);
    NS_ENDHANDLER

    [cdrArgs addObject: @"-minfo"];

    // set up cdrecord task
    cdrTask = [[NSTask alloc] init];
    stdOut = [[NSPipe alloc] init];

    [cdrTask setLaunchPath: cdrecord];

    [cdrTask setArguments: cdrArgs];
    [cdrTask setStandardOutput: stdOut];
    [cdrTask setStandardError: stdOut];

    [self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
                                        cdrecord, [cdrArgs componentsJoinedByString: @" "]] raw: NO];
    [cdrTask launch];

    [cdrTask waitUntilExit];

    /*
     * If cdrecord did not terminate gracefully we stop the whole affair.
     * We delete in any case the actual (not finished) file.
     */
    {
        int termStatus = [cdrTask terminationStatus];   // FreeBSD needs an lvalue for the WIF* macros
        if ((WIFEXITED(termStatus) == 0)
                || WIFSIGNALED(termStatus)) {
            [info setObject: _(@"Unknown") forKey: @"type"];
            return info;
        }
    }

    cdrOutput = [[[NSString alloc] initWithData: [[stdOut fileHandleForReading] availableData]
                                    encoding: NSISOLatin1StringEncoding]
                    componentsSeparatedByString: @"\n"];

    count = [cdrOutput count];

    /*
     * Skip the first line in output. It contains only header data.
     */
    for (i = 1; i < count; i++) {
        NSRange range;
        outLine = [cdrOutput objectAtIndex: i];

        // check for not erasable first, then for erasable
        // if none applies don#t change the dictionary
        if ([outLine hasPrefix: @"Mounted media type:"]) {
            [info setObject: [[outLine substringFromIndex: 19] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]]
                     forKey: @"type"];
            continue;
        }

        if ([outLine hasPrefix: @"disk status:"]) {
            NSString *tmp = [[outLine substringFromIndex: 12] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if ([tmp isEqualToString: @"empty"]) {
                [info setObject: @"yes" forKey: @"empty"];
            } else {
                [info setObject: @"no" forKey: @"empty"];
                if ([tmp isEqualToString: @"complete"]) {
                    [info setObject: @"no" forKey: @"appendable"];
                } else {
                    [info setObject: @"yes" forKey: @"appendable"];
                }
            }
            continue;
        }
        // search manufacturer/vendor
        if ([outLine hasPrefix: @"Manufacturer:"]) {
            NSString *tmp = [[outLine substringFromIndex: 13] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            [info setObject: tmp forKey: @"vendor"];
            continue;
        }

        if ([outLine hasPrefix: @"number of sessions:"]) {
            NSString *tmp = [[outLine substringFromIndex: 19] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            [info setObject: tmp forKey: @"sessions"];
            continue;
        }

        range = [outLine rangeOfString: @"ATIP start of lead out:"];
        if (range.location != NSNotFound) {
            if ([outLine length] > 41) {
                int frames = [[outLine substringFromIndex: 26] intValue];
                NSString *str = [NSString stringWithFormat: @"%@ - %d blocks, %d/%d MB",
                                    [outLine substringWithRange: NSMakeRange(34,8)],
                                    frames,
                                    frames * 2048 / (1024*1024),
                                    frames * 2352 / (1024*1024)];
                [info setObject: str forKey: @"capacity"];
            } else
                [info setObject: [outLine substringFromIndex: 26] forKey: @"capacity"];

            continue;
        }
    }

    RELEASE(stdOut);
    RELEASE(cdrTask);

    return info;
}

@end
