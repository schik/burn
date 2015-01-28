/* vim: set ft=objc et sw=4 ts=4 nowrap: */
/*
 *  CdrdaoController.h
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

#ifndef CDRDAOCONTROLLER_H_INC
#define CDRDAOCONTROLLER_H_INC

#include <AppKit/AppKit.h>

#include "ExternalTools.h"

@interface CdrdaoController : NSObject <BurnTool, Burner>
{
	// burn parameters
	NSMutableArray *burnTracks;

	NSMutableArray *tempFiles;

	NSString *tempDir;

	NSTask *cdrTask;

	NSLock *statusLock;
	ToolStatus burnStatus;

	NSMutableDictionary *drives;
	NSFileManager *fileMan;
}

@end

//
// private methods
//
@interface CdrdaoController (Private)
- (void) initializeFromDefaults;
- (void) checkForDrives;
- (void) sendOutputString: (NSString *) outString
                      raw: (BOOL) raw;
- (NSString *) idForDevice: (NSString *) device;
- (void) waitForEndOfBurning;
- (NSMutableArray *) makeParamsForTask: (int) task
					    withParameters: (NSDictionary *) parameters
                               tocFile: (NSString *) tocFile;
- (void) addDevice: (NSString *) device
     andParameters: (NSDictionary *) parameters
       toArguments: (NSMutableArray *) args;
- (NSString *) createTOC: (BOOL) isCDROM;
- (BOOL) convertAuToWav: (NSString *) auFile;
@end



typedef enum {
	TaskBurn,
} CdrdaoTask;

#endif
