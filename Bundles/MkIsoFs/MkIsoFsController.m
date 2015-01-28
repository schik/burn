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


#include "MkIsoFsController.h"
#include "MkIsoFsParametersView.h"
#include "MkIsoFsSettingsView.h"

#include "Constants.h"
#include "Functions.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]



static MkIsoFsController *singleInstance = nil;


@implementation MkIsoFsController

- (id) init
{
    self = [super init];

    if (self) {
        statusLock = [NSLock new];
        [self initializeFromDefaults];
    }

    return self;
}


- (void) dealloc
{
	singleInstance = nil;
	RELEASE(statusLock);

	[super dealloc];
}

//
// BurnTool methods
//

- (NSString *) name
{
	return @"mkisofs";
}

- (id<PreferencesModule>) preferences;
{
    return AUTORELEASE([MkIsoFsSettingsView singleInstance]);
}

- (id<PreferencesModule>) parameters;
{
    return AUTORELEASE([MkIsoFsParametersView singleInstance]);
}

- (void) cleanUp
{
    /*
     * Nothing to do here at the moment.
     */
}

+ (id) singleInstance
{
	if (! singleInstance) {
		singleInstance = [[MkIsoFsController alloc] init];
	}

	return singleInstance;
}

//
// IsoImageCreator methods
//

- (NSString *) isoImageFile
{
	NSDictionary *parameters =
			[[NSUserDefaults standardUserDefaults] objectForKey: @"MkIsofsParameters"];
    if (nil == parameters) {
        return nil;
    }
   return [parameters objectForKey: @"ImagePath"];
}

- (BOOL) createISOImage: (NSString *) volumeId
			 withTracks: (NSArray *) trackArray
				 toFile: (NSString *) outFile
		 withParameters: (NSDictionary *) parameters
{
	BOOL ret = YES;
	int termStatus;
	NSString *mkisofs;
	NSArray *mkiArgs;
	NSPipe *stdOut;
    NSFileManager *fileMan = [NSFileManager defaultManager];


	// set up mkisofs task
	mkisofs = [[parameters objectForKey: @"MkIsofsParameters"]
						objectForKey: @"Program"];

    if (!checkProgram(mkisofs))
        return NO;

	mkiTask = [[NSTask alloc] init];
	stdOut = [[NSPipe alloc] init];

	mkiArgs = [self makeParamsForVolumeId: volumeId
								fileList: trackArray
                                 outFile: outFile
                          withParameters: parameters];

	[mkiTask setLaunchPath: mkisofs];
	[mkiTask setArguments: mkiArgs];
	[mkiTask setStandardError: stdOut];

	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
											mkisofs, [mkiArgs componentsJoinedByString: @" "]] raw: NO];

	[mkiTask launch];

	/*
	 * Now we wait until the mkisofs task is over and process its output.
	 */
	[self waitForEndOfTask];

	/*
	 * If mkisofs did not terminate gracefully we stop the whole affair.
	 * We delete in any case the actual (not finished) file.
	 */
	termStatus = [mkiTask terminationStatus];	// FreeBSD needs an lvalue for the WIF* macros
	if ((WIFEXITED(termStatus) == 0)
			|| WIFSIGNALED(termStatus)
			|| (toolStatus.processStatus == isCancelled)) {
		[self sendOutputString: [NSString stringWithFormat: _(@"Removing temporary file %@."), outFile] raw: NO];
		if (![fileMan removeFileAtPath: outFile handler: nil]) {
			[self sendOutputString: _(@"Removing file failed.") raw: NO];
		}
		toolStatus.processStatus = isCancelled;
		ret = NO;
	}

	RELEASE(stdOut);
	RELEASE(mkiTask);
	mkiTask = nil;

	if (toolStatus.processStatus != isCancelled) {
		[statusLock lock];
		toolStatus.processStatus = isStopped;
		[statusLock unlock];
	}

	return ret;
}

- (BOOL) stop: (BOOL) immediately
{
	if (mkiTask && (toolStatus.processStatus == isCreatingImage)) {
		[self sendOutputString: _(@"Terminating process.") raw: NO];
		[mkiTask terminate];
		toolStatus.processStatus = isCancelled;
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

@end
