/* vim: set ft=objc ts=4 nowrap: */
/*
 *  Project+Audio.m
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

#include <AppKit/AppKit.h>

#include "Constants.h"
#include "Functions.h"
#include "Project.h"
#include "ProjectWindowController.h"

#include <Burn/ExternalTools.h>



@interface Project (AudioPrivate)

- (BOOL) addAudioTracks: (NSArray *)theTracks forCD: (NSString *)cddbId atPosition: (int)pos;

@end

/**
 * <p>The class Project represents a project for compiling and
 * burning CDs.</p>
 * <p>It is derived from class NSDocument.</p>
 */


@implementation Project (Audio)

- (unsigned long) audioLength
{
	return audioLength;
}

- (int) numberOfCDs
{
	return [allCDs count];
}

- (int) numberOfAudioTracks
{
	return [audioTracks count];
}

- (NSString *) cddbIdAtIndex: (int)index
{
	NSArray *keys = [allCDs allKeys];
	NSString *ret;

	ret = [keys objectAtIndex: index];

	return ret;
}

- (NSArray *) allCddbIds
{
	return [allCDs allKeys];
}

- (NSMutableDictionary *) cdForKey: (id)key
{
	return [allCDs objectForKey: key];
}

- (BOOL) addCD: (NSDictionary *)cd withID: (NSString *)cddbId atPosition: (int)pos
{
	NSMutableDictionary *cdInfo;
	NSArray *tracks;

	tracks = [cd objectForKey: @"tracks"];
	if ([tracks count] == 0) {
		return NO;
	}

	if ([self addAudioTracks: tracks forCD: cddbId atPosition: pos] == YES) {
		cdInfo = [allCDs objectForKey: cddbId];

		/*
		 * If the CD has not already been added to the project we do this now.
		 * Otherwise we update the CD information.
		 */
		if (!cdInfo) {
			[allCDs setObject: [NSMutableDictionary dictionaryWithObjectsAndKeys:
									[cd objectForKey: @"artist"], @"artist",
									[cd objectForKey: @"title"], @"title",
									[NSString stringWithFormat: @"%d", [tracks count]], @"numberOfTracks",
									nil]
					forKey: cddbId];
		} else {
			NSNumber *num = [cdInfo objectForKey: @"numberOfTracks"];
			[cdInfo setObject: [NSNumber numberWithInt: [num intValue] + [tracks count]]
					forKey: @"numberOfTracks"];
		}
		return YES;
	}
	return NO;
}

- (BOOL) setCDInfo: (NSString *)cddbId : (NSString *)artist : (NSString *)title
{
	NSMutableDictionary *cdInfo;

	cdInfo = [allCDs objectForKey: cddbId];

	/*
	 * If the CD has not already been added to the project we do this now.
	 * Otherwise we update the CD information.
	 */
	if (!cdInfo) {
#if 0
		[allCDs setObject: [NSMutableArray arrayWithObjects: artist, title,
											[NSNumber numberWithInt: 0], nil]
				forKey: cddbId];
#endif
		return NO;
	} else {
		[cdInfo setObject: artist forKey: @"artist"];
		[cdInfo setObject: title forKey: @"title"];
	}
	return YES;
}

@end


@implementation Project (AudioPrivate)

- (BOOL) addAudioTracks: (NSArray *)theTracks forCD: (NSString *)cddbId atPosition: (int)pos
{
	int i, count;

	// take care that the array is not released inthe mean time!!
	RETAIN(theTracks);

	count = [theTracks count];

	// insert from last to first to maintain the position
	for (i = count-1; i >= 0; i--) {
		NSDictionary *trackInfo = [theTracks objectAtIndex: i];
		Track *track = [[Track alloc] initWithProperties: [NSArray arrayWithObjects:
																[trackInfo objectForKey: @"title"],
																[NSNumber numberWithInt: [[trackInfo objectForKey: @"length"] intValue]],
																@"audio:cd",
																[NSString stringWithFormat: @"%@/Track%@", cddbId, [trackInfo objectForKey: @"index"]],
																nil]
												forKeys: [NSArray arrayWithObjects:
																@"description", @"duration", @"type", @"source", nil]];

		if ((pos < 0) || (pos > [audioTracks count]))
			pos = [audioTracks count];

		[audioTracks insertObject: track atIndex: pos];
		audioLength += [[track propertyForKey: @"duration"] doubleValue];
	}

	[self updateChangeCount:NSChangeDone];

	RELEASE(theTracks);
	return YES;
}

@end
