/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  ExternalTools.h
 *
 *  Copyright (c) 2002, 2016
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

#ifndef BURN_EXTERNALTOOLS_H_INC
#define BURN_EXTERNALTOOLS_H_INC

#include <Foundation/Foundation.h>

#include "PreferencesModule.h"

/**
 * <p>Defines the stages a ripping/burning process may be in.</p>
 * <list>
 * <item>isStopped: The process is idle. No errors.</item>
 * <item>isRipping: The process is ripping one or more files.</item>
 * <item>isWaiting: The process is waiting for the actual process to begin (e.g. preparing the burning).</item>
 * <item>isPreparing: The process is writing the lead-in.</item>
 * <item>isBurning: The process is burning one or more files to the CD.</item>
 * <item>isFixating: The process is fixating (closing) the CD -> Lead-out.</item>
 * <item>isCancelled: The process has been cancelled by user action or by error.</item>
 * </list>
 */
typedef enum {
    isStopped,
    isConverting,
    isCreatingImage,
    isWaiting,
    isPreparing,
    isBurning,
    isFixating,
    isCancelled
} ProcessStatus;

/**
 * <p>Contains the current status of the burning process.</p>
 * <list>
 * <item>processStatus:  The stage of the process as defined in EProcessStatus.</item>
 * <item>trackNumber:    The number of the track currently processed. 1-based</item>
 * <item>trackName:      The name of the track currently processed.</item>
 * <item>trackProgress:  The progress of the current track in percent (0 to 100).</item>
 * <item>entireProgress: The progress of the entire process in percent (0 to 100).</item>
 * <item>bufferLevel:    The fill level of the burn buffer in percent (0 to 100).</item>
 * </list>
 */
typedef struct {
    ProcessStatus processStatus;
    int trackNumber;
    NSString *trackName;
    double trackProgress;
    double entireProgress;
    double bufferLevel;
} ToolStatus;

/**
 * <p>The currently supported modes for blanking a CD-RW.</p>
 * <list>
 * <item>fullBlank: The whole disk is blanked.</item>
 * <item>fastBlank: Only PMA and TOC are blanked.</item>
 * </list>
 */
typedef enum {
    fullBlank,
    fastBlank
} EBlankingMode;


/**
 * <p>BurnTool describes the interface for a generic class
 * encapsulationg an external tool.</p>
 * <p>Concrete classes must additionally implement one of the
 * following specialized protocols (e.g. for ripping an audio CD).</p>
 */
@protocol BurnTool

/**
 * <p>Returns a unique name for the tool to be displayed in
 * several cases (e.g. preferences).</p>
 */
- (NSString *) name;

/**
 * <p>Returns a pointer to the preferences view that can be displayed
 * as a page in the Preferences... panel.</p>
 * <p>If this returns nil, no page is displayed.</p>
 */
- (id<PreferencesModule>) preferences;

/**
 * <p>Returns a pointer to the parameters view that can be displayed
 * as a page in the Parameters... panel.</p>
 * <p>If this returns nil, no page is displayed.</p>
 */
- (id<PreferencesModule>) parameters;


/**
 * <p>Stops the current process if there is one.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>immediately</term>
 * <desc>If set to @c YES, the process must be stopped immediately.
 * This usually means sending a SIGTERM, and thus a more or less
 * ungraceful dead of the tool. If set to @c NO, the process may
 * finish gracefully, e.g. finish the current track. Currently always
 * set to @c YES.</desc>
 * </deflist>
 */
- (BOOL) stop: (BOOL)immediately;

/**
 * <p>Does some housekeeping when everything is over. This might include
 * removal of grabbed files or other temporary stuff. Whatever resources the
 * bundle allocated during ripping and is not needed any longer.</p>
 */
- (void) cleanUp;

/**
 * <p>Returns the current status of the process.</p>
 */
- (ToolStatus) getStatus;

/**
 * <p>Burn.app uses one single instance of the module and therefore
 * calls this class method. singleInstance must create the module and initialise it
 * if it does not exist, yet.
 * In any case the method returns a reference to the single instance of
 * the class.</p>
 */
+ (id) singleInstance;

@end


/**
 * <p>AudioConverter describes the interface for a class
 * encapsulationg an external audio converter.</p>
 * <p>Basically, the protocol contains methods for displaying
 * a preferences view and for converting an audio track into a
 * .wav file.</p>
 */
@protocol AudioConverter

/**
 * <p>Returns whether the bundle grabs audio CDs or converts
 * audio files.</p>
 */
- (BOOL) isCDGrabber;

/**
 * <p>Returns the duration of the track in frames.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>fileName</term>
 * <desc>The name of the file whose duration must be
 * calculated.</desc>
 * </deflist>
 */
- (long) duration: (NSString *) fileName;

/**
 * <p>Returns the size of the track in bytes.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>fileName</term>
 * <desc>The name of the file whose size must be
 * calculated.</desc>
 * </deflist>
 */
- (unsigned) size: (NSString *) fileName;

/**
 * <p>Converts a list of audio tracks into .wav files.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>tracks</term>
 * <desc>The list of tracks to be converted.</desc>
 * <term>parameters</term>
 * <desc>A static snapshot of the usr defaults taken when the user
 * started the action.</desc>
 * </deflist>
 */
- (BOOL) convertTracks: (NSArray *) tracks
        withParameters: (NSDictionary *) parameters;

@end



/**
 * <p>IsoImageCreator describes the interface for a class
 * encapsulationg an external tool for creating ISO images.</p>
 * <p>Basically, the protocol contains methods for displaying
 * a preferences views and for creating the image.</p>
 */
@protocol IsoImageCreator

/**
 * <p>Returns the preferred name of the ISO file to be created.
 * The return value may be @c nil or the empty string if the tool
 * has no preference about the file name.<br />
 * The returned string (if any) must be an absolute path.<br />
 * The main program may choose a different name, though, if
 * considered adequate.</p>
 */
- (NSString *) isoImageFile;

/**
 * <p>Creates an ISO image from the given track list.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>volumeID</term>
 * <desc>The identifier for the volume to be created. This string
 * may appear in file system browsers, for example.</desc>
 * <term>trackArray</term>
 * <desc>An array of data tracks to be contained in the image. The
 * tracks form the top level of the directory tree.</desc>
 * <term>outFile</term>
 * <desc>The name of the file for the ISO image. The file name is a
 * <em>must</em>, otherwise Burn.app will never find the file again.</desc>
 * <term>parameters</term>
 * <desc>A static snapshot of the usr defaults taken when the user
 * started the action.</desc>
 * </deflist>
 */
- (BOOL) createISOImage: (NSString *) volumeID
             withTracks: (NSArray *) trackArray
                 toFile: (NSString *) outFile
         withParameters: (NSDictionary *) parameters;


@end


#define BurnDevice @"BurnDevice"
#define Drivers @"Drivers"
#define DriverOptions @"DriverOptions"
#define BurnSpeed @"Speed"
#define EjectCD @"EjectCD"
#define Overburn @"Overburn"
#define FixateCD @"FixateCD"
#define TestOnly @"TestOnly"
#define NumberOfCopies @"Copies"
#define TempDirectory @"WAVTEMPDIR"

/**
 * <p>Burner describes the interface for a class
 * encapsulationg an external burning program for CDs.</p>
 * <p>Basically, the protocol contains methods for displaying
 * a preferences view and for burning a project's tracks
 * or image to a CD.</p>
 */
@protocol Burner

/**
 * <p>Returns an array containg the burning drivers used by the tool.</p>
 */
- (NSArray *) drivers;

/**
 * <p>Returns an array containg the drives found by the tool.</p>
 */
- (NSArray *) availableDrives;

/**
 * <p>Returns information about an inserted media.</p>
 * <p>The dictionary must contain at least an entry for the following
 * key:</p>
 * <list>
 * <item><strong>"type"</strong> _("Unknown"), "CD-R", "CD-RW" or _("NONE")</item>
 * </list>
 * If "type" is "CD-R" or "CD-RW" there should be entrys for the following keys:
 * <list>
 * <item><strong>"capacity"</strong> a string value containing the capacity</item>
 * <item><strong>"vendor"</strong> a string value containing vandor/manuf. info</item>
 * <item><strong>"speed"</strong> a string value containing the writing speed</item>
 * <item><strong>"empty"</strong> must be "yes" or "no"</item>
 * <item><strong>"remCapacity"</strong> a string value containing the remaining capacity for multi-session media</item>
 * <item><strong>"sessions"</strong> a string value containing the number of sessions</item>
 * <item><strong>"appendable"</strong> tells whether sessions can be appended, must be "yes" or "no"</item>
 * </list>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>parameters</term>
 * <desc>The parameter list to be used when executing the backend program.</desc>
 * </deflist>
 */
- (NSDictionary *) mediaInformation: (NSDictionary *)parameters;

/**
 * <p>Returns information about an inserted media.</p>
 * <p>The dictionary must contain at least an entry for the following
 * key:</p>
 * <list>
 * <item><strong>"type"</strong> _("Unknown"), "CD-R", "CD-RW" or _("NONE")</item>
 * </list>
 * If "type" is "CD-R" or "CD-RW" there should be entrys for the following keys:
 * <list>
 * <item><strong>"capacity"</strong> a string value containing the capacity</item>
 * <item><strong>"vendor"</strong> a string value containing vandor/manuf. info</item>
 * <item><strong>"speed"</strong> a string value containing the writing speed</item>
 * <item><strong>"empty"</strong> must be "yes" or "no"</item>
 * <item><strong>"remCapacity"</strong> a string value containing the remaining capacity for multi-session media</item>
 * <item><strong>"sessions"</strong> a string value containing the number of sessions</item>
 * <item><strong>"appendable"</strong> tells whether sessions can be appended, must be "yes" or "no"</item>
 * </list>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>device</term>
 * <desc>The name of the device to be used. The format of this string depends
 * on the tool. It will be one from the list returned by -availableDrives.</desc>
 * <term>parameters</term>
 * <desc>The parameter list to be used when executing the backend program.</desc>
 * </deflist>
 */
- (NSDictionary *) mediaInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *)parameters;

/**
 * <p>Returns whether a writable medium is inserted in the writing device.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>device</term>
 * <desc>The name of the device to be used. The format of this string depends
 * on the tool. It will be one from the list returned by -availableDrives.</desc>
 * <term>parameters</term>
 * <desc>The parameter list to be used when executing the backend program.</desc>
 * </deflist>
 */
- (BOOL) isWritableMediumInDevice: (NSString *) device
                       parameters: (NSDictionary *)parameters;

/**
 * <p>Blanks a CD-RW and returns the result (success/no success).</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>mode</term>
 * <desc>The blanking mode. Currently two modes must be supported:
 * full mode to blank the entire disk, and fast mode to blank only
 * PMA and TOC.</desc>
 * <term>device</term>
 * <desc>The name of the device to be used. The format of this string depends
 * on the tool. It will be one from the list returned by -availableDrives.</desc>
 * <term>parameters</term>
 * <desc>A static snapshot of the usr defaults taken when the user
 * started the action.</desc>
 * </deflist>
 */
- (BOOL) blankCDRW: (EBlankingMode) mode
          inDevice: (NSString *) device
    withParameters: (NSDictionary *) parameters;

/**
 * <p>Burns the given image/tracks to a CD.</p>
 * <br />
 * <strong>Inputs</strong><br />
 * <deflist>
 * <term>image</term>
 * <desc>The location of an ISO image to be burned to the CD. This 
 * parameter may be nil in case of a pure audio CD.</desc>
 * <term>trackArray</term>
 * <desc>This array contains the file names of the audio tracks to
 * be burned on the CD. The tracks must be burned to the CD in the
 * array's order. The array may be empty or the parameter may point
 * to nil in case of a pure data CD (CD-ROM).</desc>
 * <term>parameters</term>
 * <desc>A static snapshot of the usr defaults taken when the user
 * started the action.</desc>
 * </deflist>
 */
- (BOOL) burnCDFromImage: (id)image
          andAudioTracks: (NSArray *)trackArray
          withParameters: (NSDictionary *) parameters;



@end

#endif
