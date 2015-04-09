/* vim: set ft=objc et sw=4 ts=4 expandtab nowrap: */
/*
 *  CDrecordController.h
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef CDRECORDCONTROLLER_H_INC
#define CDRECORDCONTROLLER_H_INC

#include <AppKit/AppKit.h>

#include "ExternalTools.h"

typedef enum {
    TaskBurn,
    TaskEject,
} CDrecordTask;

typedef enum {
    TrackAtOnce,
    SessionAtOnce,
    Raw96R,
    Raw96P,
    Raw16
} WriteMode;

@interface CDrecordController : NSObject <BurnTool, Burner>
{
    // burn parameters
    NSMutableArray *burnTracks;

    short processStatus;

    NSTask *cdrTask;

    NSLock *statusLock;
    ToolStatus burnStatus;

    NSMutableDictionary *drives;
    NSMutableArray *drivers;
}

- (void) checkForDrives;

@end

//
// private methods
//
@interface CDrecordController (Private)

- (void) initializeFromDefaults;
- (void) waitForEndOfBurning;

- (NSMutableArray *) makeParamsForTask: (CDrecordTask) task
                        withParameters: (NSDictionary *) sessionParams;

- (void) addDevice: (NSString *) device
     andParameters: (NSDictionary *) parameters
       toArguments: (NSMutableArray *) args;

- (NSString *) idForDevice: (NSString *) device;

- (void) appendTrackArgs: (NSMutableArray *) args
                forCDROM: (BOOL) isCDROM;

- (void) sendOutputString: (NSString *) outString
                      raw: (BOOL) raw;

- (void) getCDrecordDrivers;

- (NSDictionary *) atipInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *) parameters;

- (NSDictionary *) minfoInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *) parameters;

@end

#endif
