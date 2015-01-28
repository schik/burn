/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  CdrdaoController.m
 *
 *  Copyright (c) 2002-2005
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <sys/types.h>
#include <sys/wait.h>
#include <stdlib.h>

#include "CdrdaoController.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"


#undef CDRDAO_DEBUG
//#define CDRDAO_DEBUG

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]


@implementation CdrdaoController (Private)

/**
 * Tries to find the cdrdao executable in case it is not already set
 * in the defaults.
 */
- (void) initializeFromDefaults
{
    NSString *program;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CdrdaoParameters"];
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
        program = which(@"cdrdao");
    }

    [mutableParams setObject: program forKey: @"Program"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"CdrdaoParameters"];
    RELEASE(mutableParams);
	[[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 * <p>checkForDrives runs <strong>cdrdao</strong> to get the list
 * of available drives. For performance reasons this should be done
 * only once when the bundle is loaded.
 */

- (void) checkForDrives
{
	NSString *cdrdao;
	int		 count, i;
	NSPipe *stdOut;
	NSMutableArray *cdrArgs;
	NSArray *cdrOutput;
	NSDictionary *parameters =
			[[NSUserDefaults standardUserDefaults] objectForKey: @"CdrdaoParameters"];

	cdrdao = [parameters objectForKey: @"Program"];

    /*
     * It may be that the path to cdrdao is not set, yet. This
     * is the case, when Burn is run for the first time. In this case
     * we cannot do anything here.
     */
    if (!checkProgram(cdrdao))
        return;

	[[NSNotificationCenter defaultCenter]
				postNotificationName: DisplayWorkInProgress
				object: nil
				userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                            @"1", @"Start",
                            @"cdrdao", @"AppName",
                            @"Checking for drives. Please wait.", @"DisplayString",
                            nil]];

    DESTROY(drives);
    drives = [NSMutableDictionary new];

	cdrTask = [[NSTask alloc] init];  
	stdOut = [[NSPipe alloc] init];
	cdrArgs = [[NSMutableArray alloc] init];
	[cdrArgs addObject: [NSString stringWithFormat: @"scanbus"]];

	[cdrTask setLaunchPath: cdrdao];
	[cdrTask setArguments: cdrArgs];
	[cdrTask setStandardOutput: stdOut];
	[cdrTask setStandardError: stdOut];

	[cdrTask launch];

	[cdrTask waitUntilExit];

	cdrOutput = [[[NSString alloc] initWithData: [[stdOut fileHandleForReading] availableData]
									encoding: NSISOLatin1StringEncoding]
					componentsSeparatedByString: @"\n"];

	count = [cdrOutput count];

	for (i = 0; i < count; i++) {
        NSRange range;
		NSString *line;
		NSString *vendorString, *modelString, *revString;
		NSString *busIdLunString, *protocol;

		line = [[cdrOutput objectAtIndex: i] stringByTrimmingLeadSpaces];
        /*
         * protocol comes first
         * triple of bus, id, lun comes second
         */
        range = [line rangeOfString: @": "];
        if (range.location != NSNotFound) {
            // This is an older version of cdrdao
            protocol = @"";
            busIdLunString = [[line substringToIndex: range.location] stringByTrimmingSpaces];
            line = [line substringFromIndex: range.location+1];
        } else {
            range = [line rangeOfString: @":"];
            if (range.location != NSNotFound) {
                protocol = [line substringToIndex: range.location];
                line = [line substringFromIndex: range.location+1];

                range = [line rangeOfString: @" "];
		        busIdLunString = [[line substringToIndex: range.location] stringByTrimmingSpaces];
                line = [line substringFromIndex: range.location+1];
            } else {
                continue;
            }
        }

		/* Vendor, Model, Revision are encapsulated by , */
        range = [line rangeOfString: @","];
        if (range.location == NSNotFound) {
            continue;
        }
		vendorString = [[line substringToIndex: range.location] stringByTrimmingSpaces];
        line = [line substringFromIndex: range.location+1];
        range = [line rangeOfString: @","];
        if (range.location == NSNotFound) {
            continue;
        }
		modelString = [[line substringToIndex: range.location] stringByTrimmingSpaces];
        line = [line substringFromIndex: range.location+1];
		revString = [line stringByTrimmingSpaces];

        if ([protocol length])
    	    [drives setObject: protocol
                       forKey: [NSString stringWithFormat: @"%@: %@ %@ %@",
                                                            busIdLunString,
                                                            vendorString, modelString, revString]]; 
        else
    	    [drives setObject: @""
                       forKey: [NSString stringWithFormat: @"%@: %@ %@ %@",
                                                            busIdLunString,
                                                            vendorString, modelString, revString]]; 
	}

	[[NSNotificationCenter defaultCenter]
				postNotificationName: DisplayWorkInProgress
				object: nil
				userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                            @"0", @"Start",
                            @"cdrdao", @"AppName",
                            nil]];
}

- (void) waitForEndOfBurning
{
	BOOL sendLine;
	double maxCDProgress;
	int maxTrackProgress, curTrackProgress;

	maxCDProgress = 0.;
	maxTrackProgress = 0;
	curTrackProgress = 0;

	while ([cdrTask isRunning]) {
		NSData *inData;
        NSFileHandle *fh = [[cdrTask standardError] fileHandleForReading];
        while ((inData = [fh availableData]) && [inData length]) {
			int i, count;
			NSString *aLine;
			NSString *temp;
			NSArray *theOutput;

			temp = [[NSString alloc] initWithData: inData
									encoding: NSISOLatin1StringEncoding];

			theOutput = [temp componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];

			count = [theOutput count];

			for (i = 0; i < count; i++) {
				aLine = [theOutput objectAtIndex: i];
				if (aLine && [aLine length])
					sendLine = YES;
				else
					sendLine = NO;	// don't send empty lines

				if (burnStatus.processStatus == isWaiting) {
					NSRange r = [aLine rangeOfString: @"Unit not ready, giving up"];
					if (r.location != NSNotFound) {
						[statusLock lock];
						burnStatus.processStatus = isCancelled;
						[statusLock unlock];
						break;
					}
					r = [aLine rangeOfString: @"Writing lead-in"];
					if (r.location == NSNotFound) {
						[statusLock lock];
						burnStatus.processStatus = isPreparing;
						[statusLock unlock];
					}
					r = [aLine rangeOfString: @"Starting write"];
					if (r.location != NSNotFound) {
						[statusLock lock];
						burnStatus.processStatus = isPreparing;
						[statusLock unlock];
					}
				} else if ((burnStatus.processStatus == isPreparing)
							|| (burnStatus.processStatus == isBurning)) {
					if (YES == [aLine hasPrefix: @"Writing track"]) {
                        Track *track = nil;
						[statusLock lock];
                        burnStatus.trackNumber = [[aLine substringFromIndex: 13] integerValue];
                        // cdrdao reports 1-based track numbers
                        track = [burnTracks objectAtIndex: burnStatus.trackNumber - 1];
						burnStatus.trackProgress = 0.;
						curTrackProgress = 0;
						maxTrackProgress = (long)[track duration] * 2352 / (1024*1024);
						[statusLock unlock];
						sendLine = NO;
					}
					if (YES == [aLine hasPrefix: @"Wrote"]) {
    					NSArray *parts = [aLine componentsSeparatedByString: @" "];
						[statusLock lock];
					    if (burnStatus.processStatus == isPreparing) {
							burnStatus.processStatus = isBurning;
							maxCDProgress = [[parts objectAtIndex: 3] doubleValue];
					    }
						curTrackProgress++;
						burnStatus.trackProgress = curTrackProgress * 100. / maxTrackProgress;
						burnStatus.entireProgress = [[parts objectAtIndex: 1] doubleValue] * 100. / maxCDProgress;
						burnStatus.bufferLevel = [[parts objectAtIndex: 6] doubleValue];
						[statusLock unlock];
						sendLine = NO;
                    }

					if ((YES == [aLine hasPrefix: @"Writing lead-out"])
                            || (YES == [aLine hasPrefix: @"Flushing cache"])) {
						[statusLock lock];
						burnStatus.processStatus = isFixating;
						burnStatus.trackProgress = 0.;
						burnStatus.bufferLevel = 0.;
						burnStatus.entireProgress = 0.;
						maxTrackProgress = 0;
						maxCDProgress = 0.;
						[statusLock unlock];
					}
				} else if (burnStatus.processStatus == isFixating) {
                    NSRange r;
					if (YES == [aLine hasPrefix: @"Wrote"]) {
						NSArray *parts = [aLine componentsSeparatedByString: @" "];

						[statusLock lock];
						if (0. == maxCDProgress) {
							maxCDProgress = [[parts objectAtIndex: 3] doubleValue];
						}
						burnStatus.entireProgress = [[parts objectAtIndex: 1] doubleValue] * 100. / maxCDProgress;
						[statusLock unlock];
						sendLine = NO;
					}
					r = [aLine rangeOfString: @"failed"];
					if (r.location != NSNotFound) {
						[statusLock lock];
						burnStatus.processStatus = isCancelled;
						[statusLock unlock];
					}
				}
				// post the oputput to the progress panel
				if (sendLine) {
					[self sendOutputString: aLine raw: YES];
				}
			}	// for (i = 0; i < count; i++)
		}	//  while ((inData = 
	}	// while ([cdrTask isRunning])
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


- (NSMutableArray *) makeParamsForTask: (int) task
						withParameters: (NSDictionary *) parameters
                               tocFile: (NSString *) tocFile;
{
	NSString *burnDevice;
	NSString *cdrParam;
	NSMutableArray *cdrArgs = nil;
	NSDictionary *sessionParams =
			[parameters objectForKey: @"SessionParameters"];
	NSDictionary *tools =
			[parameters objectForKey: @"SelectedTools"];

	/* The array is autoreleased! Don't release it here!!! */
	switch (task) {
	case TaskBurn:		// burn
		cdrArgs = [NSMutableArray arrayWithObjects: @"write", @"-n", nil];
		break;
	}

	// this should never (!!!) happen
	if (cdrArgs == nil)
		[NSException raise: NSInvalidArgumentException format: @"cdrdao cannot execute this kind of task."];

	// check for device to be use for burning/blanking...
    burnDevice = [tools objectForKey: BurnDevice];
	[self addDevice: burnDevice
      andParameters: parameters
        toArguments: cdrArgs];

	switch (task) {
	case TaskBurn:		// burn
	    // set the speed
		cdrParam = [sessionParams objectForKey: BurnSpeed];
		[cdrArgs addObject: @"--speed"];
		if (cdrParam && [cdrParam length]) {
			[cdrArgs addObject: cdrParam];
		} else {
			[cdrArgs addObject: @"0"];
		}

		if ([[sessionParams objectForKey: TestOnly] intValue]) {
			[cdrArgs addObject: @"--simulate"];
		}
		// any extra parameters?
		if ([[sessionParams objectForKey: EjectCD] boolValue] == YES) {
			[cdrArgs addObject: @"--eject"];
		}
		if ([[sessionParams objectForKey: Overburn] boolValue] == YES) {
			[cdrArgs addObject: @"--overburn"];
		}
		[cdrArgs addObject: tocFile];
		break;
	}

	return cdrArgs;
}

- (void) addDevice: (NSString *) device
     andParameters: (NSDictionary *) parameters
       toArguments: (NSMutableArray *) args
{
    NSString *dev;
	NSString *cdrParam;
	NSDictionary *cdrParams =
			[parameters objectForKey: @"CdrdaoParameters"];
	NSDictionary *drivers =
            [[parameters objectForKey: Drivers] objectForKey: device];

    dev = [self idForDevice: device];
    if (nil != dev) {
        NSString *transport = [drives objectForKey: device];
	    [args addObject: @"--device"];
        if (transport && [transport length]) {
            [args addObject: [NSString stringWithFormat: @"%@:%@", transport, dev]];
        } else {
            [args addObject: dev];
        }

	    // set the driver and its options
	    cdrParam = [drivers objectForKey: [self name]];
	    if (cdrParam && [cdrParam length] && ![cdrParam isEqual: @"Default"]) {
		    NSString *drvOpts;
		    drvOpts = [cdrParams objectForKey: DriverOptions];

		    [args addObject: @"--driver"];
		    if (drvOpts && [drvOpts length])
			    [args addObject: [NSString stringWithFormat: @"%@:%@", cdrParam, drvOpts]];
		    else
			    [args addObject: cdrParam];
	    }
    }else {
        [self sendOutputString: [NSString stringWithFormat: @"%@\n%@",
											_(@"No burning device specified."),
											_(@"Process will be stopped.")] raw: NO];

		[NSException raise: NSInternalInconsistencyException
					format: @"cdrdao cannot find a burning device."];

    }
}

/**
 * <p>createTOCFFromTracks converts the list of file names to be burned to
 * the CD into a cdrdao TOC file.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>isCDROM</term>
 * <desc>If set to YES the first track in burnTracks is assumed to be an
 * ISO image containing data.</desc>
 * </deflist>
 */
- (NSString *) createTOC: (BOOL) isCDROM
{
	int i, count;
	NSMutableString *tocContents;
    NSString *tocFile;

	/*
	 * Now, we must create the .toc file for cdrdao.
	 * We want it to be temporary.
	 */
	tocFile = [tempDir stringByAppendingPathComponent: [NSString stringWithFormat: @"burn_%@.toc",
														[[NSDate date] descriptionWithCalendarFormat: @"%H_%M_%S"
																		timeZone: nil locale: nil]]];

	// The first entry is the name of an image file (NSString*) if we burn a CD-ROM.
	count = [burnTracks count];
	if (isCDROM) {
        Track *track = [burnTracks objectAtIndex: 0];
		tocContents = [NSMutableString stringWithString: @"CD_ROM\n\n"];
		[tocContents appendString: @"TRACK MODE1\n"];
//		[tocContents appendString: @"PREGAP 00:02:00\n"];
		[tocContents appendString: [NSString stringWithFormat: @"DATAFILE \"%@\"\n", [track storage]]];
		// if audio tracks follow, we need a post-gap
		if (count > 1)
			[tocContents appendString: @"ZERO 00:02:00\n"];
	} else {
		tocContents = [NSMutableString stringWithString: @"CD_DA\n\n"];
	}

	// Append audio files, if any, and convert .au files to .wav if necessary
	// Remember, that audio file info is not stored as plain strings, but
	// as a data structure we may access using the method -(NSString*)storage!!!
	for (i = isCDROM ? 1 : 0; i < count; i++) {
        Track *track = [burnTracks objectAtIndex: i];
		NSString *File = [track storage];
		[tocContents appendString: @"TRACK AUDIO\n"];
		if (isCDROM && (i == 1)) {
			[tocContents appendString: @"SILENCE 00:02:00\n"];
			[tocContents appendString: @"START\n"];
		}

		burnStatus.trackProgress = 0.;

		if ([[File pathExtension] isEqual: @"au"]) {
			[self convertAuToWav: File];
			[tocContents appendString: [NSString stringWithFormat: @"FILE \"%@\" 0\n",
				[[File stringByDeletingPathExtension] stringByAppendingPathExtension: @"wav"]]];
		} else {
			[tocContents appendString: [NSString stringWithFormat: @"FILE \"%@\" 0\n", File]];
		}

		if (burnStatus.processStatus == isCancelled)
			break;
	}
    // burning starts with first track
	burnStatus.trackNumber = 0;

	[tocContents writeToFile: tocFile atomically: YES];
    return tocFile;
}

- (BOOL) convertAuToWav: (NSString *)auFile
{
	unsigned int temp, i, rest;
	int dataLength, dataOffset;
	NSString *wavFile;
	NSFileHandle *inFile, *outFile;
	NSData *rawData;
	char _wavHeader[] = {'R','I','F','F',0x0,0x0,0x0,0x0,'W','A','V','E',
						'f','m','t',' ',0x10,0x0,0x0,0x0,0x01,0x0,0x02,0x0,0x44,0xac,0x0,0x0,
						0x10,0xB1,0x02,0x0,0x04,0x0,0x10,0x0,'d','a','t','a',0x0,0x0,0x0,0x0};

	// if it is a .wav file already, we don't do anything
	if ([[auFile pathExtension] isEqual: @"wav"])
		return YES;

	// if it is not an .au file we indicate an error
	if (![[auFile pathExtension] isEqual: @"au"])
		return NO;

	// does the file exist?
	if (![fileMan fileExistsAtPath: auFile])
		return NO;

	// create the wav file name by using the temporary directory
	wavFile = [[auFile lastPathComponent] stringByDeletingPathExtension];
	wavFile = [wavFile stringByAppendingPathExtension: @"wav"];
	wavFile = [tempDir stringByAppendingPathComponent: wavFile];

	// check whether the .wav file already exists
	if ([fileMan fileExistsAtPath: wavFile])
		return YES;

	if(![fileMan createFileAtPath: wavFile contents: nil attributes: nil])
		return NO;

	[self sendOutputString: [NSString stringWithFormat: @"Converting %@ to %@.", auFile, wavFile] raw: NO];

	inFile = [NSFileHandle fileHandleForReadingAtPath: auFile];
	outFile = [NSFileHandle fileHandleForWritingAtPath: wavFile];

	// read header and calculate data length, remember we have Motorole byte order!!
	[inFile seekToFileOffset: 4];
	[[inFile readDataOfLength: sizeof(unsigned int)] getBytes: &dataOffset length: sizeof(dataOffset)];
	dataOffset = GSSwapBigI32ToHost(dataOffset);
	dataLength = [[fileMan fileAttributesAtPath: auFile
									traverseLink: YES] fileSize]; // - dataOffset;
	dataLength -= dataOffset;

	// we assume here that the file is 2 channel 16-bit PCM data and don't check this!!!

	// write .wav Header
	temp = GSSwapHostI32ToLittle(dataLength);
	memcpy(_wavHeader+40, &temp, sizeof(temp));
	temp += 36;
	memcpy(_wavHeader+4, &temp, sizeof(temp));
	[outFile writeData: [NSData dataWithBytes: _wavHeader length: 44]];

	// write the swapped data
	[inFile seekToFileOffset: dataOffset];
	rawData = [inFile readDataOfLength: dataLength];

	rest = dataLength % 2;
	for (i = 0; i < dataLength-rest; i+= 2) {
		short data;
		[rawData getBytes: &data range: NSMakeRange(i,2)];
		data = GSSwapI16(data);
		[outFile writeData: [NSData dataWithBytes: &data length: 2]];
		burnStatus.trackProgress = i * 100 / dataLength;

		if (burnStatus.processStatus == isCancelled)
			break;
	}
	// write the last byte
	if (rest)
		[outFile writeData: [inFile readDataOfLength: 1]];

	// close the files
	[inFile closeFile];
	[outFile closeFile];

	if (!tempFiles) {
		tempFiles = [[NSMutableArray alloc] init];
	}
	[tempFiles addObject: wavFile];

	return YES;
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

@end
