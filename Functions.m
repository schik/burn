/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  Functions.m
 *
 *  Copyright (c) 2002, 2011, 2016
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <unistd.h>

#include <AudioCD/AudioCDProtocol.h>

#include "AppController.h"
#include "Constants.h"
#include "Functions.h"

static NSArray *audioTypes = nil;

/**
 * This function returns the full path to a file. It is basically the
 * same as the 'which' command in a Un*x shell. which searches the standard
 * search path.<br />
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>name</term>
 * <desc>The file/program that is to be searched.</desc>
 * </deflist>
 */
NSString *which(NSString *name)
{
	int i, count;
	NSDictionary   *env;
	NSString *pathEnv;
	NSArray *pathList;
	NSString *test;
	NSFileManager *fileMan = [NSFileManager defaultManager];

    /*
     * Test the file name as is. Maybe we do not need to
     * walk through the whole search path.
     */
	if ([fileMan isExecutableFileAtPath: name])
		return name;

	env = [[NSProcessInfo processInfo] environment];
	pathEnv = [env objectForKey: @"PATH"];

	if (!pathEnv || [pathEnv length] == 0) {
		return NOT_FOUND;
	}

	pathList = [pathEnv componentsSeparatedByString: @":"];
	count = [pathList count];

	for (i = 0; i < count; i++) {
		test = [[pathList objectAtIndex: i] stringByAppendingPathComponent: name];

		if ([fileMan isExecutableFileAtPath: test])
			return test;
	}

	return NOT_FOUND;
}

/**
 * <p>Checks whether a program exists and returns FALSE if not.
 * The function also writes an error to the log console.<br />
 * As we use the which() function, it is also made sure that the
 * file is an executable.<br />
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>name</term>
 * <desc>The file/program to be checked.</desc>
 * </deflist>
 */
BOOL checkProgram(NSString *name)
{
    if (!name || ![name length])
        return NO;

    /*
     * Check the path and eventually report an error.
     */
    if ([which(name) isEqual: NOT_FOUND]) {
        logToConsole(MessageStatusError,
                     [NSString stringWithFormat: _(@"Functions.notFound"),
                                                 name]);
        return NO;
    }
    return YES;
}


/**
 * <p>Checks whether the given file is a registered audio type.
 * The function uses the file name's extension to determine
 * whether it is an audio file type recognized by Burn.app or not.<br />
 * Recognized file types are .wav and .au and all types registered
 * by converter bundles.<br />
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>fileName</term>
 * <desc>The name of the file to be checked.</desc>
 * </deflist>
 */
BOOL isAudioFile(NSString *fileName)
{
	NSString *ext = [[fileName pathExtension] lowercaseString];
    NSArray *ft = getAudioFileTypes();
	return [ft containsObject: ext];
}


/**
 * <p>Returns the path for user installed libraries for Burn. Usually
 * this is <code>~/GNUstep/Library/Burn</code>.</p>
 */
NSString *UserLibraryPath()
{
	NSString *aString;

	aString = [NSString stringWithFormat: @"%@/Burn", 
			      [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
							  objectAtIndex:0]];

	return aString;
}


/**
 * <p>Returns the path for globally installed libraries for Burn. Usually
 * this is <code>$GNUSTEP_LOCAL_ROOT/Library/Burn</code>.</p>
 */
NSString *LocalLibraryPath()
{
	NSString *aString;

	aString = [NSString stringWithFormat: @"%@/Burn", 
			      [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES)
							  objectAtIndex:0]];

	return aString;
}


static NSBundle *audioCDBundle = nil;

id loadAudioCD(void)
{
	int i;
	NSString *libPath;

	// if we don't know the AudioCD bundle, yet,
	// we try to load the AudioCD bundle
	if (!audioCDBundle) {
		NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
								NSUserDomainMask|NSLocalDomainMask|NSSystemDomainMask, YES);

		for (i = 0; i < [searchPaths count]; i++) {
			NSString *path;

			libPath = [NSString stringWithFormat: @"%@/Bundles", [searchPaths objectAtIndex: i]];

			path = [NSString stringWithFormat: @"%@/AudioCD.bundle", libPath];

			audioCDBundle = [NSBundle bundleWithPath: path];
			if (audioCDBundle) {
				[audioCDBundle retain];
				logToConsole(MessageStatusInfo, [NSString stringWithFormat: _(@"Functions.loadedAudioCD"), path]);
				break;
			} else {
				logToConsole(MessageStatusError, [NSString stringWithFormat: _(@"Functions.failedAudioCD"), path]);
			}
		}
	}
	if (audioCDBundle) {
		if ([[audioCDBundle principalClass] conformsToProtocol: @protocol(AudioCDProtocol)]) {
			id cd = [[[audioCDBundle principalClass] alloc] initWithHandler: nil];
			return cd;
		} else {
			logToConsole(MessageStatusError, _(@"Functions.notAudioCDProtocol"));
			[audioCDBundle release];
			audioCDBundle = nil;
		}
	}
	NSRunAlertPanel(APP_NAME, _(@"Functions.errorAudioCD"),
						_(@"Common.abort"), nil, nil);

	return nil;
}

NSArray *getAvailableDrives(void)
{
	id writer = nil;
	NSArray *drives = nil;

	writer = [[AppController appController] currentWriterBundle];
	/*
	 * Check writer bundle, first. If this can deliver a drive list,
	 * we use this. Otherwise, we try our own.
	 */
	drives = [writer availableDrives];

	return drives;
}

NSArray *getAudioFileTypes(void)
{
    if (nil == audioTypes) {
        audioTypes = [[NSArray alloc] initWithObjects: @"wav", @"au", @"mp3", @"ogg",
                   @"flac", @"wma", @"aiff", @"avi", @"flv", @"m4v", @"mov", nil];
    }
    return audioTypes;
}

NSString* framesToString(long frames)
{
	NSString *ret;
	int min, sec;

	sec = frames/FramesPerSecond;
	frames = frames%FramesPerSecond;

	min = sec/60;
	sec %= 60;

	ret = [NSString stringWithFormat: @"%02d:%02d.%02d", min, sec, frames];

	return ret;
}

double framesToSeconds(long frames)
{
	return (double)frames/(double)FramesPerSecond;
}

unsigned framesToSize(long frames)
{
	return frames * 2048;	// a frame may contain 2048 bytes of usable data
}

unsigned framesToAudioSize(long frames)
{
	return frames * BytesPerFrame;	// but we can fill it with much more audio data
}

long secondsToFrames(double seconds)
{
	return seconds * FramesPerSecond;
}

long sizeToFrames(unsigned size)
{
	long inc = 0;

	// if the size does not fit into whole frames
	// we must add one for padding
	if (size % 2048)
		inc = 1;

	return size / 2048 + inc;
}

long audioSizeToFrames(unsigned size)
{
	long inc = 0;

	// if the size does not fit into whole frames
	// we must add one for padding
	if (size % BytesPerFrame)
		inc = 1;

	return size / BytesPerFrame + inc;
}

/**
 * Converts the user defaults to the new format. The function
 * is called from AppController's +initialize method.<br />
 * Attention: This function uses the developer's knowledge about
 * how the user defaults were structured before and how they are
 * now. This knowledge is not intended for the rest of the
 * application, but every part should treat its own part of the
 * defaults only and should not care about the rest!
 */
void convertUserDefaults(void)
{
	NSMutableDictionary *selectedTools;
    id object = nil;

	/*
	 * Check for the new tools structure
	 */
	selectedTools = [[NSUserDefaults standardUserDefaults] objectForKey: @"SelectedTools"];
	if (!selectedTools) {
		selectedTools = [NSMutableDictionary dictionary];

        object = [[NSUserDefaults standardUserDefaults] objectForKey: @"BURNER"];
		if (object)
			[selectedTools setObject: object forKey: @"BurnSW"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"RIPPER"];
		if (object)
			[selectedTools setObject: object forKey: @"cd"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"ISOTOOL"];
		if (object)
			[selectedTools setObject: object forKey: @"ISOSW"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"BURN_DEVICE"];
		if (object)
			[selectedTools setObject: object forKey: @"BurnDevice"];
		[[NSUserDefaults standardUserDefaults] setObject: selectedTools forKey: @"SelectedTools"];

		/*
		 * Remove obsolete tool entries.
		 */
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"DRIVERS"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"BURNER"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"RIPPER"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"ISOTOOL"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"BURN_DEVICE"];
    } else {
        // RipSW is obsolete
        id object = [selectedTools objectForKey: @"RipSW"];
        if (nil != object) {
            [selectedTools setObject: object forKey: @"cd"];
            [selectedTools removeObjectForKey: @"RipSW"];
        }
    }

	/*
	 * Check whether session data is already converted
	 */
	object = [[NSUserDefaults standardUserDefaults] objectForKey: @"SPEED"];
	if (object) {
		NSMutableDictionary *sessionParams = [NSMutableDictionary dictionary];
		/*
		 * Transform parameters to new format and save.
		 */
		[sessionParams setObject: object forKey: @"Speed"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"COPIES"];
		if (object)
			[sessionParams setObject: object forKey: @"Copies"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"EJECT_CD"];
		if (object)
			[sessionParams setObject: object forKey: @"EjectCD"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"FIXATE_CD"];
		if (object)
			[sessionParams setObject: object forKey: @"FixateCD"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"TEST_ONLY"];
		if (object)
			[sessionParams setObject: object forKey: @"TestOnly"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"KEEP_TEMPORARY_WAVS"];
		if (object)
			[sessionParams setObject: object forKey: @"KeepTempWavs"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"KEEP_ISO_IMAGE"];
		if (object)
			[sessionParams setObject: object forKey: @"KeepISOImage"];
    	object = [[NSUserDefaults standardUserDefaults] objectForKey: @"WAVTEMPDIR"];
	    if (object)
		    [sessionParams setObject: object forKey: @"TempDirectory"];

		[[NSUserDefaults standardUserDefaults] setObject: sessionParams forKey: @"SessionParameters"];

		/*
		 * Remove obsolete entries.
		 */
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"SPEED"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"EJECT_CD"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"COPIES"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"FIXATE_CD"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"TEST_ONLY"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"KEEP_TEMPORARY_WAVS"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"KEEP_ISO_IMAGE"];
	    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"WAVTEMPDIR"];
	}
 
	/*
	 * Check for the old CDparanoia params structure
	 */
	object = [[NSUserDefaults standardUserDefaults] objectForKey: @"CDPARANOIA"];
	if (object) {
		NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

		[parameters setObject: object forKey: @"Program"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"DIS_PARANOIA"];
		if (object)
			[parameters setObject: object forKey: @"DisableParanoia"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"DIS_XTRA_PARANOIA"];
		if (object)
			[parameters setObject: object forKey: @"DisableExtraParanoia"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"DIS_SCRATCH_REPAIR"];
		if (object)
			[parameters setObject: object forKey: @"DisableScratchRepair"];
		[[NSUserDefaults standardUserDefaults] setObject: parameters forKey: @"CDparanoiaParameters"];

		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"CDPARANOIA"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"DIS_PARANOIA"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"DIS_XTRA_PARANOIA"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"DIS_SCRATCH_REPAIR"];
	}

	/*
	 * Check for the old CDrecord params structure
	 */
	object = [[NSUserDefaults standardUserDefaults] objectForKey: @"CDRECORD"];
	if (object) {
	    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
 
		[parameters setObject: object forKey: @"Program"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"CDRECORD_TAO"];
		if (object)
			[parameters setObject: object forKey: @"TrackAtOnce"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"CDRECORD_DRVOPTS"];
		if (object)
			[parameters setObject: object forKey: @"DriverOptions"];
		[[NSUserDefaults standardUserDefaults] setObject: parameters forKey: @"CDrecordParameters"];

		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"CDRECORD"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"CDRECORD_TAO"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"CDRECORD_DRVOPTS"];
	}

	/*
	 * Check for the old Cdrdao params structure
	 */
	object = [[NSUserDefaults standardUserDefaults] objectForKey: @"CDRDAO"];
	if (object) {
	    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
 
		[parameters setObject: object forKey: @"Program"];
		[[NSUserDefaults standardUserDefaults] setObject: parameters
												  forKey: @"CdrdaoParameters"];

	    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"CDRDAO"];
	}

	/*
	 * Check for the old MkIsoFs params structure
	 */
	object = [[NSUserDefaults standardUserDefaults] objectForKey: @"MKISOFS"];
	if (object) {
	    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
 
		[parameters setObject: object forKey: @"Program"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"ROCKRIDGE_EXT"];
		if (object)
			[parameters setObject: object forKey: @"RRExtensions"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"JOLIET_EXT"];
		if (object)
			[parameters setObject: object forKey: @"JolietExtensions"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"FOLLOW_SYMLINKS"];
		if (object)
			[parameters setObject: object forKey: @"FollowSymlinks"];
		object = [[NSUserDefaults standardUserDefaults] objectForKey: @"NO_BACKUP_FILES"];
		if (object)
			[parameters setObject: object forKey: @"NoBackupFiles"];
		[[NSUserDefaults standardUserDefaults] setObject: parameters forKey: @"MkIsofsParameters"];

    	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"MKISOFS"];
    	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"ROCKRIDGE_EXT"];
    	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"JOLIET_EXT"];
    	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"FOLLOW_SYMLINKS"];
    	[[NSUserDefaults standardUserDefaults] removeObjectForKey: @"NO_BACKUP_FILES"];
	}

	[[NSUserDefaults standardUserDefaults] synchronize];
}
