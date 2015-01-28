/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  CreateIsoController.m
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

#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <libburn/libisofs.h>

#include "CreateIsoController.h"

#include "CreateIsoParametersView.h"

#include "Track.h"
#include "Constants.h"
#include "Functions.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]


static CreateIsoController *singleInstance = nil;


@implementation CreateIsoController

- (id) init
{
	self = [super init];

	if (self) {
		statusLock = [NSLock new];
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
	return @"createiso";
}

- (id<PreferencesModule>) preferences;
{
	return nil;
}

- (id<PreferencesModule>) parameters;
{
	return [[CreateIsoParametersView singleInstance] autorelease];
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
		singleInstance = [[CreateIsoController alloc] init];
	}

	return singleInstance;
}

//
// IsoImageCreator methods
//
- (BOOL) createISOImage: (NSString *) volumeId
			 withTracks: (NSArray *) trackArray
				 toFile: (NSString *) outFile
		 withParameters: (NSDictionary *) parameters
{
    BOOL ret = YES;
    NSFileHandle *outfile;
    struct iso_volset *volset;
    struct iso_volume *volume;
    struct burn_source *src;
    char buf[2048];
    int level=1, flags=0;
    double step;
    NSDictionary *mkiParams = [parameters objectForKey: @"CreateIsoParameters"];
    NSString *param;

    toolStatus.entireProgress = 0;
    toolStatus.processStatus = isPreparing;

    //
    // Open the output file for writing. If this fails print
    // an error message and exit.
    int	fd = open([outFile fileSystemRepresentation], O_WRONLY|O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);

    if (fd < 0) {
        [self sendOutputString: [NSString stringWithFormat: @"Cannot open ISO file for writing %@", outFile]
                      priority: MessageStatusError];
        [self stop: YES];
        return NO;
    }
    outfile = [[NSFileHandle alloc] initWithFileDescriptor: fd closeOnDealloc: YES];
    if (outfile == nil) {
        [self sendOutputString: [NSString stringWithFormat: @"Cannot open ISO file for writing %@", outFile]
                      priority: MessageStatusError];
        [self stop: YES];
        return NO;
    }
    AUTORELEASE(outfile);
    //
    // Set up the parameters.
	param = [mkiParams objectForKey: @"RRExtensions"];
	if ([param boolValue]) {
		flags |= ECMA119_ROCKRIDGE;
	}
	param = [mkiParams objectForKey: @"JolietExtensions"];
	if ([param boolValue]) {
		flags |= ECMA119_JOLIET;
	}
	param = [mkiParams objectForKey: @"IsoLevel"];
	if ([param intValue]) {
		level = [param intValue];
	}

    //
    // Create a new volume and volume set
	volume = iso_volume_new([volumeId cString], "Burn.app", "Burn.app");
	volset = iso_volset_new(volume, [volumeId cString]);

    //
    // Collect the file information
    ret = [self getFiles: trackArray withParameters: parameters volume: volume];
    if (!ret) {
        [outfile closeFile];
        iso_volume_free(volume);
        [self stop: YES];
        return ret;
    }

    //
    // Create the burn source and write it to the output file.
	src = iso_source_new_ecma119(volset, 0, level, flags);

    //
    // Reset the progress indicator
    toolStatus.entireProgress = 0;
	toolStatus.processStatus = isCreatingImage;
    step = (100. * 2048.) / src->get_size(src);

	while ((src->read(src, buf, 2048) == 2048) && (toolStatus.processStatus != isCancelled)) {
        NS_DURING
            [outfile writeData: [NSData dataWithBytes: buf length: 2048]];
        NS_HANDLER
            [self sendOutputString: [NSString stringWithFormat: @"Cannot write to ISO file %@", outFile]
                          priority: MessageStatusError];

            toolStatus.processStatus = isCancelled;
            ret = NO;
        NS_ENDHANDLER
        [statusLock lock];
        toolStatus.entireProgress += step;
        [statusLock unlock];
	}
    [outfile closeFile];
    src->free_data(src);
    free(src);
    iso_volume_free(volume);

	if (toolStatus.processStatus != isCancelled) {
		[statusLock lock];
		toolStatus.processStatus = isStopped;
		[statusLock unlock];
	}

	return ret;
}

- (BOOL) getFiles: (NSArray *)trackArray
   withParameters: (NSDictionary *)parameters
           volume: (struct iso_volume *)volume
{
    NSFileManager *fileMan = [NSFileManager defaultManager];
    NSEnumerator *tracks = [trackArray objectEnumerator];
    Track *track = nil;
    double step;

    //
    // for the progress indicator
    step = 100. / [trackArray count];

    while ((track = [tracks nextObject]) != nil) {
        NSDictionary *attrs = [fileMan fileAttributesAtPath: [track source] traverseLink: NO];
        if (attrs == nil) {
		    [self sendOutputString: [NSString stringWithFormat: _(@"Cannot access file %@. Ignored."), [track source]]
                          priority: MessageStatusWarning];
        } else {
            //
            // Depending on the type we proceed differently.
            NSString *fType = [attrs objectForKey: NSFileType];
            NSString *fName = [track description];

            NSLog(@"fName %@", fName);
            if ([fType isEqualToString: NSFileTypeDirectory]) {
                //
                // Simply add this directory under the edited name. As we define
                // the top level of the CD only, we can simply use the recursive version
                // and don't need to care about diving into the subdirs.
                struct iso_tree_dir *dir = iso_tree_radd_dir(iso_volume_get_root(volume), [[track source] cString]);
                iso_tree_dir_set_name(dir, [fName cString]);
            } else if ([fType isEqualToString: NSFileTypeSymbolicLink]) {
                //
                // Simply add this file under the edited name
                struct iso_tree_file *file = iso_tree_add_file(iso_volume_get_root(volume), [[track source] cString]);
                iso_tree_file_set_name(file, [fName cString]);
            } else if ([fType isEqualToString: NSFileTypeRegular]) {
                //
                // Simply add this file under the edited name
                struct iso_tree_file *file = iso_tree_add_file(iso_volume_get_root(volume), [[track source] cString]);
                iso_tree_file_set_name(file, [fName cString]);
            } else {
		        [self sendOutputString: [NSString stringWithFormat: _(@"File %@ is of unknown type. Ignored."), [track source]]
                              priority: MessageStatusWarning];
            }
        }
        [statusLock lock];
        toolStatus.entireProgress += step;
        [statusLock unlock];
    }

    return YES;
}

- (BOOL) stop: (BOOL)immediately
{
	[self sendOutputString: _(@"Terminating process.") priority: MessageStatusToolOutput];
    [statusLock lock];
	toolStatus.processStatus = isCancelled;
    [statusLock unlock];
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

- (void) sendOutputString: (NSString *)outString
                 priority: (NSString *)priority
{
	[[NSDistributedNotificationCenter defaultCenter]
					postNotificationName: ExternalToolOutput
					object: nil
					userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                        outString, @"Output", priority, @"Priority", nil]];
}

@end
