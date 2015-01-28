/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  MkIsoFsController.m
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

#include "MkIsoFsController.h"

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



@implementation MkIsoFsController (Private)

/**
 * Tries to find the mkisofs executable in case it is not already set
 * in the defaults.
 */
- (void) initializeFromDefaults
{
    NSString *program;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"MkIsofsParameters"];
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
        program = which(@"mkisofs");
    }

    [mutableParams setObject: program forKey: @"Program"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"MkIsofsParameters"];
    RELEASE(mutableParams);
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) waitForEndOfTask
{
	BOOL sendLine;

	while ([mkiTask isRunning]) {
		NSData *inData;
        while ((inData = [[[mkiTask standardError] fileHandleForReading] availableData]) && [inData length]) {
			int i, count;
			NSString *aLine;
			NSString *temp;
			NSArray *theOutput;

			temp = [[NSString alloc] initWithData: inData
									encoding: NSISOLatin1StringEncoding];

			theOutput = [temp componentsSeparatedByString: @"\n"];

			count = [theOutput count];

			for (i = 0; i < count; i++) {
				aLine = [theOutput objectAtIndex: i];
				if (aLine && [aLine length])
					sendLine = YES;
				else
					sendLine = NO;	// don't send empty lines

				if (toolStatus.processStatus == isPreparing) {
					NSRange aRange = [aLine rangeOfString: @"done, estimate finish"];
					if (aRange.location != NSNotFound) {
						NSArray *parts = [aLine componentsSeparatedByString: @"%"];
						[statusLock lock];
						toolStatus.processStatus = isCreatingImage;
						toolStatus.entireProgress = [[parts objectAtIndex: 0] doubleValue];
						[statusLock unlock];
						sendLine = NO;
					}
				} else if (toolStatus.processStatus == isCreatingImage) {
					NSRange aRange;

					aRange = [aLine rangeOfString: @"done, estimate finish"];
					if (aRange.location != NSNotFound) {
						NSArray *parts = [aLine componentsSeparatedByString: @"%"];
						[statusLock lock];
						toolStatus.entireProgress = [[parts objectAtIndex: 0] doubleValue];
						[statusLock unlock];
						sendLine = NO;
					}
				}

				// post the oputput to the progress panel
				if (sendLine) {
					[self sendOutputString: aLine raw: YES];
				}
			}	// for (i = 0; i < count; i++)
		}	//  while ((inData = 
	}	// while ([mkiTask isRunning])
}


- (NSMutableArray *) makeParamsForVolumeId: (NSString *) volumeId
								  fileList: (NSArray *) files
								   outFile: (NSString *) outFile
							withParameters: (NSDictionary *) parameters;
{
	int i, count;
	NSString *param;
	NSMutableArray *mkiArgs = nil;
	NSFileManager *fileMan = [NSFileManager defaultManager];
	NSDictionary *mkiParams = [parameters objectForKey: @"MkIsofsParameters"];

	toolStatus.entireProgress = 0;
	toolStatus.processStatus = isPreparing;

	/* The array is autoreleased! Don't release it here!!! */
	mkiArgs = [NSMutableArray arrayWithObjects: @"-o", outFile, @"-gui", @"-graft-points", nil];
	[mkiArgs addObject: @"-V"];
	[mkiArgs addObject: volumeId];

	// any extra parameters?
	param = [mkiParams objectForKey: @"FollowSymlinks"];
	if ([param boolValue]) {
		[mkiArgs addObject: @"-f"];
	}
	param = [mkiParams objectForKey: @"NoBackupFiles"];
	if ([param boolValue]) {
		[mkiArgs addObject: @"-no-bak"];
	}
	param = [mkiParams objectForKey: @"DotStartAllowed"];
	if ([param boolValue]) {
		[mkiArgs addObject: @"-ldots"];
	}
	param = [mkiParams objectForKey: @"FullISOFilenames"];
	if ([param boolValue]) {
		[mkiArgs addObject: @"-l"];
	}
	param = [mkiParams objectForKey: @"RRExtensions"];
	if ([param boolValue]) {
		[mkiArgs addObject: @"-r"];
	}
	param = [mkiParams objectForKey: @"JolietExtensions"];
	if ([param boolValue]) {
		[mkiArgs addObject: @"-J"];
	}
	param = [mkiParams objectForKey: @"IsoLevel"];
	if ([param intValue]) {
		[mkiArgs addObject: @"-iso-level"];
		[mkiArgs addObject: param];
	}

	count = [files count];
	for (i = 0; i < count; i++) {
		Track *file = [files objectAtIndex: i];
		BOOL isDir;

		// we must set the graft point for directories
		if ([fileMan fileExistsAtPath: [file source] isDirectory: &isDir]) {
			if (isDir) {
				NSString *graftPoint;
				if ([[file description] hasSuffix: @"/"])
					graftPoint = [file description];
				else
					graftPoint = [NSString stringWithFormat: @"%@/", [file description]];

				[mkiArgs addObject: [NSString stringWithFormat: @"%@=%@", graftPoint, [file source]]];
			} else {
				// files can simply be appended
				[mkiArgs addObject: [NSString stringWithFormat: @"%@=%@", [file description], [file source]]];
			}
		}
	}

	return mkiArgs;
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
