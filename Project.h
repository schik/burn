/* vim: set ft=objc ts=4 nowrap: */
/*
 *  Project.h
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

#ifndef PROJECT_H_INC
#define PROJECT_H_INC

#include <Foundation/Foundation.h>
#include <AppKit/NSDocument.h>


#include "Track.h"

#define TrackTypeNone -1
#define TrackTypeAudio 0
#define TrackTypeData 1

@interface Project : NSDocument
{
	NSString *volumeId;
	NSMutableArray *audioTracks;
	NSMutableArray *dataTracks;
	NSMutableDictionary *allCDs;

	unsigned long	audioLength;
	unsigned long	dataLength;
	unsigned long	dataSize;
}

/**
 * <init />
 */
- (id) init;


//
// access/mutation methods
//
- (NSString *) volumeId;
- (void) setVolumeId: (NSString *)newVolId;

- (unsigned long) totalLength;		// in frames !!
- (int) numberOfTracks;

- (Track *) trackOfType: (int)type atIndex: (int)index;

- (BOOL) addTrackFromFile: (NSString *)file;
- (BOOL) insertTrack: (Track *)track
			asType: (int)type
		atPosition: (int)pos;
- (BOOL) insertTrackFromFile: (NSString *)file
					asType: (int)type
				atPosition: (int)pos;
- (BOOL) insertTracksFromDirectory: (NSString *)directory
					asType: (int)type
				atPosition: (int)pos
				recursive: (BOOL)rec;
- (void) deleteTrack: (Track *)track;
- (void) deleteTrackOfType: (int)type atIndex: (int)index;

- (void) trackTypeChanged: (Track *)track;

//
// action methods
//

//
// delegate methods
//

- (NSData *) dataRepresentationOfType: (NSString *)aType;
- (BOOL) loadDataRepresentation: (NSData *)data ofType: (NSString *)aType;

- (void) makeWindowControllers;

//
// other methods
//
- (void) createCD: (BOOL) isoOnly;


@end

@interface Project (Audio)

- (unsigned long) audioLength;		// in frames !!

- (int) numberOfAudioTracks;
- (int) numberOfCDs;

- (NSString *) cddbIdAtIndex: (int)index;
- (NSArray *) allCddbIds;
- (NSMutableDictionary *) cdForKey: (id)key;

- (BOOL) addCD: (NSDictionary *)cd withID: (NSString *)cddbId atPosition: (int)pos;
- (BOOL) setCDInfo: (NSString *)cddbId : (NSString *)artist : (NSString *)title;

@end

@interface Project (Data)

- (unsigned long) dataLength;		// in frames !!
- (unsigned long) dataSize;			// in bytes !!

- (int) numberOfDataTracks;

@end


#endif
