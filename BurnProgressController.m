/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	BurnProgressController.m
 *
 *	Copyright (c) 2002-2005, 2011
 *
 *	Author: Andreas Schik <andreas@schik.de>
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

#include "BurnProgressController.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"
#include "Project.h"
#include "AppController.h"
#include "ConvertAudioHelper.h"
#include "CreateISOHelper.h"
#include "BurnCDHelper.h"
#include "ConsolePanel.h"


enum BurnStage {
    None,
    ConvertAudio,
    GrabCD,
    CreateISO,
    BurnCD
};
    
@interface BurnProgressController (Private)

- (void) setMiniwindowImage;
- (void) drawImageRep;
- (void) drawArc: (double) radius Percent: (double) percent Entire: (BOOL) entire;

@end


@implementation BurnProgressController (Private)

- (void) setMiniwindowImage
{
    NSImageRep *rep;
    NSImage *image;
    
    if (![[self window] isMiniaturized])
        return;

    if (mwTrack < 0)
        mwTrack = 0;
    if (mwEntire < 0)
        mwEntire = 0;

    image = [[NSImage alloc] initWithSize: NSMakeSize(48,48)];
    rep = [[NSCustomImageRep alloc] initWithDrawSelector: @selector(drawImageRep)
                                                delegate: self];
    [rep setSize: NSMakeSize(48,48)];
    [image addRepresentation: rep];
    [[self window] setMiniwindowImage: image];
    DESTROY(image);
}

-(void) drawImageRep
{
    PSsetlinewidth(1.0);
    PSsetalpha(1.0);

    PSsetrgbcolor(0.58, 0.58, 0.58);
    PSmoveto(24, 24);
    PSarcn(24, 24, 22, 90, -270);
    PSfill();
    [self drawArc: 22.0 Percent: mwEntire Entire: YES];
    PSsetrgbcolor(0.58, 0.58, 0.58);
    PSmoveto(24, 24);
    PSarcn(24, 24, 16, 90, -270);
    PSfill();
    [self drawArc: 15.0 Percent: mwTrack Entire: NO];
    PSsetrgbcolor(0.58, 0.58, 0.58);
    PSmoveto(24, 24);
    PSarcn(24, 24, 9, 90, -270);
    PSfill();
}

- (void) drawArc: (double) radius Percent: (double) percent Entire: (BOOL) entire
{
    if (entire) {
        PSsetrgbcolor(0.14, 0.58, 0.95);  // blue
    } else {
        PSsetrgbcolor(0.10, 1.03, 1.81);  // blue
    }
    PSmoveto(24, 24);
    PSarcn(24, 24, radius, 90, 90 - percent * 360);
    PSfill();
}

@end


@implementation BurnProgressController

- (id) init
{
    self = [self initWithWindowNibName: @"BurnProgress"];

	return self;
}

- (id) initWithVolumeId: (NSString *)volId
             dataTracks: (NSArray *)dTracks
            audioTracks: (NSArray *)aTracks
                 cdList: (NSDictionary *)cds
                isoOnly: (BOOL) isoOnly
{
    self = [self init];

    if (self != nil) {
    	ASSIGN(volumeId, volId);
	    ASSIGN(dataTracks, dTracks);
    	ASSIGN(audioTracks, aTracks);
	    ASSIGN(cdList, cds);
        isoImageOnly=isoOnly;
    }
    return self;
}


- (id) initWithIsoImage: (NSString *)isoImage
{
    self = [self init];

    if (self != nil) {
        ASSIGN(isoImageFile, isoImage);
    }
    return self;
}

- (id) initWithWindowNibName: (NSString *) nibName
{
	self = [super initWithWindowNibName: nibName];
	if (![NSBundle loadNibNamed: nibName owner: self]) {
		logToConsole(MessageStatusError, [NSString stringWithFormat:
							_(@"Common.loadNibFail"), nibName]);
	} else {
	    NSDictionary *params = nil;
        BOOL openConsole = NO;

        [[self window] setExcludedFromWindowsMenu: YES];
		[trackProgress setDoubleValue: 0];
		[entireProgress setDoubleValue: 0];

        stage = None;
        convertHelper = nil;
        createIsoHelper = nil;
        burnHelper = nil;

        /*
         * We take a snap shot of the current parameter set. Thus,
         * another session may already override the parameters while
         * this process is taking place.
         * autoreleased!!!
         */
   	    burnParameters = [NSMutableDictionary new];
        [burnParameters setDictionary: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
        // check whether the console should be opened
	    params = [burnParameters objectForKey: @"SessionParameters"];
        openConsole = [[params objectForKey: @"OpenConsole"] boolValue];
        if (YES == openConsole) {
	        [[ConsolePanel consolePanel] showWindow: self];
        }

        isoImageFile = nil;
        [[self window] setFrameAutosaveName: @"BurnProgress"];
        [[self window] setFrameUsingName: @"BurnProgress"];
	}
    return self;
}

- (void) awakeFromNib
{
    [abortButton setTitle: _(@"Common.cancel")];
    [closeButton setTitle: _(@"Common.close")];
    [closeButton setEnabled: NO];
}

- (void) dealloc
{
	RELEASE(volumeId);
	RELEASE(dataTracks);
	RELEASE(audioTracks);
	RELEASE(isoImageFile);
	RELEASE(cdList);
	RELEASE(burnParameters);
    RELEASE(convertHelper);
    RELEASE(burnHelper);
    RELEASE(createIsoHelper);

	[super dealloc];
}

//
// access methods
//
- (NSDictionary *) burnParameters
{
    return burnParameters;
}

- (NSString *)isoImageFile
{
    return isoImageFile;
}

- (NSDictionary *) cdList
{
    return cdList;
}

- (void) setTitle: (NSString *)title
{
    if (title && [title length]) {
        [[self window] setTitle: title];
    }
}


- (void) setTrackProgress: (double) value andLabel: (NSString *) label
{
    if (value >= 0) {
        [trackProgress setDoubleValue: value];
    }
    if (label != nil) {
        [trackLabel setStringValue: label];
    }
}

- (void) hideTrackProgress: (BOOL) hide
{
    [trackProgress setHidden: hide];
    [trackLabel setHidden: hide];
}

- (void) setEntireProgress: (double) value andLabel: (NSString *) label
{
    if (value >= 0) {
        [entireProgress setDoubleValue: value];
    }
    if (label != nil) {
        [entireLabel setStringValue: label];
    }
}

- (void) hideEntireProgress: (BOOL) hide
{
    [entireProgress setHidden: hide];
    [entireLabel setHidden: hide];
}

- (void) makeEntireProgressIndeterminate: (BOOL) ind
{
    if (YES == ind) {
        [entireProgress setIndeterminate: YES];
        [entireProgress startAnimation: self];
    } else {
        [entireProgress stopAnimation: self];
        [entireProgress setIndeterminate: NO];
    }
}

- (void) setAbortEnabled: (BOOL) enabled
{
    [abortButton setEnabled: enabled];
}


//
// delegate methods
//
- (void) windowDidMiniaturize: (NSNotification *)not
{
    [self setMiniwindowImage];
}


//
// action methods
//

- (void) closeClicked: (id)sender
{
	[self close];

	RELEASE(self);
	logToConsole(MessageStatusInfo, @"Burning finished.");

    [[AppController appController] unlockBurner];
}


- (void) abortClicked: (id)sender
{
	if (NSRunAlertPanel(APP_NAME, _(@"BurnProgressController.reallyStop"),
							_(@"Common.no"), _(@"Common.yes"), nil) == NSAlertDefaultReturn) {
		return;
	}

    if (convertHelper != nil) {
        [convertHelper stop: YES];
    }
    if (createIsoHelper != nil) {
        [createIsoHelper stop: YES];
    }
    if (burnHelper != nil) {
        [burnHelper stop: YES];
    }
    [self cleanUp: NO];
}

- (void) startProcess
{
	// no tracks -> nothing to do
	if ((audioTracks == nil) && (dataTracks == nil) && (isoImageFile == nil)) {
		[self close];
		return;
	}

	// create the temp path if it does not exist
	if (![self createTempDirectory]) {
		logToConsole(MessageStatusError, @"Could not create directory for temporary files.");
		return;
	}

    stage = None;
    [self nextStage: YES];
}

- (void) nextStage: (BOOL) success
{
    enum StartHelperStatus result;
    if (!success) {
        [self cleanUp: NO];
    } else {
        switch (stage) {
        case None:
            stage = ConvertAudio;
            convertHelper = [[ConvertAudioHelper alloc] initWithController: self];
            result = [convertHelper start: audioTracks];
	    	if (Done == result) {
                /*
                 * Fall through to CD grabbing
                 */
            } else {
    	    	if (Failed == result)
                    [self cleanUp: NO];
                break;
            }
        case ConvertAudio:
            stage = CreateISO;
            createIsoHelper = [[CreateISOHelper alloc] initWithController: self];
            result = [createIsoHelper start: dataTracks volumeId: volumeId];
    		if (Done == result) {
                /*
                 * Fall through to burning
                 */
            } else {
                if (Failed == result)
                    [self cleanUp: NO];
                break;
            }
        case CreateISO:
        {
            stage = BurnCD;
            if (isoImageOnly == YES) {
                /*
                 * Simply fall through, as we not have anything to burn.
                 */
            } else {
                /*
                * If we have not been passed the name of an ISO
                * image file, we try to get the one created by the
                * helper.
                */
                if (isoImageFile == nil) {
                    isoImageFile = RETAIN([createIsoHelper isoImageFile]);
                }
                burnHelper = [[BurnCDHelper alloc] initWithController: self];
                result = [burnHelper start: isoImageFile audioTracks: audioTracks];
                if (Failed == result)
                    [self cleanUp: NO];
                break;
            }
        }
        case BurnCD:
            [self cleanUp: YES];
            break;
        }
    }
}


- (void) cleanUp: (BOOL)success
{
	[convertHelper cleanUp: success];
	[burnHelper cleanUp: success];
	[createIsoHelper cleanUp: success];

	[[self window] setTitle: _(@"Common.finished")];
	[closeButton setEnabled: YES];
	[abortButton setEnabled: NO];
    [self hideTrackProgress: YES];
    [self makeEntireProgressIndeterminate: NO];
	[entireProgress setDoubleValue: 0.];
	if (success == NO) {
		[entireLabel setStringValue: _(@"BurnProgressController.noSuccess")];
		logToConsole(MessageStatusError, _(@"BurnProgressController.noSuccess"));
	} else {
		[entireLabel setStringValue: _(@"BurnProgressController.success")];
		logToConsole(MessageStatusInfo, _(@"BurnProgressController.success"));
	}
}

- (BOOL) createTempDirectory
{
	int i, count;
	BOOL isDir = YES;
	NSFileManager *fileMan = [NSFileManager defaultManager];
	NSDictionary *params = [burnParameters objectForKey: @"SessionParameters"];
    NSString *tempDir = [params objectForKey: @"TempDirectory"];

	if (!tempDir || ![tempDir length]) {
		NSRunInformationalAlertPanel(APP_NAME,
					[NSString stringWithFormat: @"%@\n%@",
						_(@"BurnProgressController.provideTempDir"),
						_(@"Common.stopProcess")],
					_(@"Common.OK"), nil, nil);
		return NO;
	}
	if (![fileMan fileExistsAtPath: tempDir isDirectory: &isDir]) {
		NSMutableString *createDir = [[NSMutableString alloc] init];
		NSArray *pathComponents = [tempDir pathComponents];
		count = [pathComponents count];
		// try to create the directories along out temp path
		for (i = 0; i < count; i++) {
			createDir = [[createDir stringByAppendingPathComponent: [pathComponents objectAtIndex: i]] copy];
			if (![fileMan fileExistsAtPath: createDir]) {
				if (![fileMan createDirectoryAtPath: createDir attributes: nil]) {
					NSRunAlertPanel(APP_NAME,
								[NSString stringWithFormat: @"%@ %@.\n%@",
									_(@"BurnProgressController.createDirFail"), createDir,
									_(@"Common.stopProcess")],
								_(@"Common.OK"), nil, nil);
					return NO;
				}
			}
		}
	} else if (!isDir) {
		NSRunAlertPanel(APP_NAME,
				[NSString stringWithFormat: @"%@ %@\n%@",
						tempDir,
						_(@"BurnProgressController.existsNoDir"),
						_(@"Common.stopProcess")],
					_(@"Common.OK"), nil, nil);
		return NO;
	}
	return YES;
}

- (void) setMiniwindowToTrack: (double) track Entire: (double) entire
{
    if (track >= 0)
        mwTrack = track/100.;
    if (entire >= 0)
        mwEntire = entire/100.;

    [self setMiniwindowImage];
}

@end
