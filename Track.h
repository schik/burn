/* vim: set ft=objc ts=4 nowrap: */
/*
 *  Track.h
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
#ifndef TRACK_H_INC
#define TRACK_H_INC

#include <Foundation/Foundation.h>

@class Project;

//
// Helper class for storing track data
//

@interface Track: NSObject <NSCoding>
{
	NSMutableDictionary *properties;

	Project *owner;
}

- (id) init;
- (id) initWithProperties: (NSDictionary*)props;
- (id) initWithProperties: (NSArray*)props forKeys: (NSArray*)keys;

- (id) initWithFile: (NSString *)file;
- (id) initWithAudioFile: (NSString *)file;
- (id) initWithDataFile: (NSString *)file;

- (void) dealloc;

//
// access / mutation methods
//
- (Project *) owner;
- (void) setOwner: (Project *)newOwner;

- (id) propertyForKey: (NSString*)key;
- (void) setProperty: (id)property forKey: (NSString*)key;

- (NSArray*) allKeys;
- (unsigned) propCount;

- (NSString *) type;
- (void) setType: (NSString *)type;

- (NSString *) source;
- (void) setSource: (NSString *)source;


- (NSString *) storage;
- (void) setStorage: (NSString *)storage;

- (NSString *) description;
- (void) setDescription: (NSString *)description;

- (unsigned) size;
- (void) setSize: (unsigned)size;

- (long) duration;
- (void) setDuration: (long)duration;

//
// class methods
//


@end

#endif
