/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  BurnProgressController.h
 *
 *  Copyright (c) 2002
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef BURNPROGRESSCONTROLLER_H_INC
#define BURNPROGRESSCONTROLLER_H_INC

#include <AppKit/AppKit.h>

#include "Burn/ExternalTools.h"

@class ConvertAudioHelper;
@class CreateISOHelper;
@class BurnCDHelper;

enum StartHelperStatus {
    Failed,
    Started,
    Done
};

@interface BurnProgressController : NSWindowController
{
    // ivars
    id closeButton;
    id abortButton;
    id entireLabel;
    id trackLabel;
    id entireProgress;
    id trackProgress;

	// data
	NSString *volumeId;
	NSArray *dataTracks;
	NSArray *audioTracks;
	NSDictionary *cdList;
    BOOL isoImageOnly;

	NSMutableDictionary *burnParameters;

	NSString *isoImageFile;

	// current status
	short processStatus;

    double mwTrack;
    double mwEntire;

    int stage;

    ConvertAudioHelper *convertHelper;
    BurnCDHelper *burnHelper;
    CreateISOHelper *createIsoHelper;
}

- (id) init;

- (id) initWithVolumeId: (NSString *) volId
             dataTracks: (NSArray *) dTracks
            audioTracks: (NSArray *) aTracks
                 cdList: (NSDictionary *) cds
                isoOnly: (BOOL) isoOnly;

- (id) initWithIsoImage: (NSString *) isoImage;

- (void) startProcess;
- (void) nextStage: (BOOL)success;

//
// action methods
//
- (void) closeClicked: (id) sender;
- (void) abortClicked: (id) sender;

//
// access methods
//
- (NSDictionary *) burnParameters;
- (NSString *)isoImageFile;
- (NSDictionary *) cdList;
- (void) setTitle: (NSString *)title;
- (void) setTrackProgress: (double) value andLabel: (NSString *) label;
- (void) hideTrackProgress: (BOOL) hide;
- (void) setEntireProgress: (double) value andLabel: (NSString *) label;
- (void) hideEntireProgress: (BOOL) hide;
- (void) makeEntireProgressIndeterminate: (BOOL) ind;
- (void) setAbortEnabled: (BOOL) enabled;
- (void) setMiniwindowToTrack: (double) track Entire: (double) entire;

//
// private methods
//
- (void) cleanUp: (BOOL) success;
- (BOOL) createTempDirectory;


@end


#endif
