/* vim: set ft=objc ts=4 nowrap: */
/*
 *  Track.m
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

#include "Track.h"
#include "Project.h"

#include "Constants.h"
#include "Functions.h"
#include "AppController.h"
#include "Burn/ExternalTools.h"


// recognized .au encodings (bytes per sample)
static short auEncodings[] = {
	0, 1, 1, 2, 3, 4, 4, 8
};

static NSString *version = @"2.0";


//
// WAV file header, all values are little-endian (Intel byte order)
// We don't use this any longer, as in particular the format chunck ('fmt')
// may vary in length.
//
/*
typedef struct {
	char riffTag[4];			// RIFF
	unsigned int totLength;		// total length to follow
	char waveTag[4];			// WAVE
	char fmtTag[4];				// fmt_
	unsigned int fmtLength;		// length of FORMAT chunk (always 0x00000010)
	unsigned short unused;		// always 0x01
	unsigned short numChannels;	// channel numbers (0x01=Mono, 0x02=Stereo)
	unsigned int smplRate;		// sample rate (binary, in Hz)
	unsigned int byteSec;		// bytes per second
	unsigned short byteSample;	// bytes Per sample: 1=8 bit Mono, 2=8 bit Stereo or 16 bit Mono, 4=16 bit Stereo
	unsigned short bitsSample;	// bits per sample
	char dataTag[4];			// data
	unsigned int dataLength;	// length of data to follow
} WavHeader;*/


//
// AU file header, all values are big endian (Motorola byte order)
//
typedef struct {
	char magicNum[4];			// .snd
	unsigned int hdrSize;		// offset from file start to audio data
	unsigned int dataLength;	// data length n bytes, maybe -1
	unsigned int encoding;		// we only accept encoding 3, 16-bit PCM
	unsigned int smplSec;		// samples per second
	unsigned int numChannels;	// number of channels (0x01=Mono, 0x02=Stereo)
} AuHeader;



@interface Track (Private)

- (BOOL) loadFromAudioFile: (NSString *)file;
- (BOOL) loadFromWavFile: (NSString *)file;
- (BOOL) loadFromAuFile: (NSString *)file;

@end

@implementation Track

- (id) init
{
	self = [super init];

	if (self) {
		properties = [NSMutableDictionary new];
	}

	return self;
}

- (id) initWithProperties: (NSDictionary*)props
{
	self = [super init];

	if (self) {
		properties = [props mutableCopy];
	}

	return self;
}

- (id) initWithProperties: (NSArray*)props forKeys: (NSArray*)keys
{
	self = [super init];

	if (self) {
		properties = [[NSMutableDictionary dictionaryWithObjects: props forKeys: keys] retain];
	}

	return self;
}

- (id) initWithFile: (NSString *)file
{
	if (isAudioFile(file)) {
		return [self initWithAudioFile: file];
	} else {
		return [self initWithDataFile: file];
	}
}


- (id) initWithAudioFile: (NSString *)file
{
	NSFileManager *fileMgr = [NSFileManager defaultManager];
	BOOL isdir;
		
	[fileMgr fileExistsAtPath: file isDirectory: &isdir];

	/*
	 * We do not insert directories as tracks.
	 */
	if (isdir) {
		RELEASE(self);
		return nil;
	}

	self = [super init];

	if (self) {
		properties = [NSMutableDictionary new];
		if ([self loadFromAudioFile: file] == NO) {
			RELEASE(self);
			return nil;
		}
	}

	return self;
}

- (id) initWithDataFile: (NSString *)file
{
	NSFileManager *fileMgr = [NSFileManager defaultManager];

	self = [super init];

	if (self) {
		unsigned long size = 0;
		NSDictionary *fAttrs = [fileMgr fileAttributesAtPath: file
											traverseLink: YES];

		properties = [NSMutableDictionary new];

		if (fAttrs) {
			NSString *filePath;
			BOOL isdir;
		
			[fileMgr fileExistsAtPath: file isDirectory: &isdir];
		 
			if (isdir) {
				NSDirectoryEnumerator *enumerator = [fileMgr enumeratorAtPath: file];
			
				while((filePath = [enumerator nextObject])) {
					filePath = [file stringByAppendingPathComponent: filePath];
					fAttrs = [fileMgr fileAttributesAtPath: filePath traverseLink: NO];
					if(fAttrs != nil) {
						size += [[fAttrs objectForKey: NSFileSize] unsignedLongValue];
					}
				}
				[self setType: @"dir"];
			} else {
				fAttrs = [fileMgr fileAttributesAtPath: file traverseLink: YES];
				if (fAttrs != nil) {
					size += [[fAttrs objectForKey: NSFileSize] unsignedLongValue];
				}
				[self setType: @"data"];
			}
		}

		[self setSize: size];

		[self setDuration: sizeToFrames(size)];

		[self setSource: file];
		[self setDescription: [file lastPathComponent]];
	}

	return self;
}

- (void) dealloc
{
	RELEASE(properties);

	[super dealloc];
}
   
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject: version];
	[coder encodeObject: properties];
}  
   
- (id)initWithCoder:(NSCoder *)coder
{
	double duration;

	if ((self = [super init])) {
		NSString *fileVersion = [[coder decodeObject] copy];

		if ([fileVersion isEqual: version]) {
			properties = [[coder decodeObject] mutableCopy];
		} else if ([fileVersion isEqual: @"1.1"]) {
			[self setSource: [coder decodeObject]];
			[self setDescription: [coder decodeObject]];
			[coder decodeValueOfObjCType: @encode(long) at: &duration];
			[self setDuration: duration];
		} else if ([fileVersion isEqual: @"1.0"]) {
			[self setSource: [coder decodeObject]];
			[self setDescription: [coder decodeObject]];
			/*
			 * The first version stored the duration as seconds.
			 * Now, we use frames!
			 */
			[coder decodeValueOfObjCType: @encode(double) at: &duration];
			[self setDuration: duration*75];
		} else {
			RELEASE(self);
			self = nil;
		}
		RELEASE(fileVersion);
	}
	return self;
}


//
// access / mutation methods
//
- (Project *) owner
{
	return owner;
}

- (void) setOwner: (Project *)newOwner
{
	owner = newOwner;
}

- (id) propertyForKey: (NSString*)key
{
	return [properties objectForKey: key];
}

- (void) setProperty: (id)property forKey: (NSString*)key
{
	[properties setObject: property forKey: key];
}

- (NSArray*) allKeys
{
	return [properties allKeys];
}

- (unsigned) propCount
{
	return [properties count];
}

- (NSString *) type
{
	return [self propertyForKey: @"type"];
}

- (void) setType: (NSString *)type
{
	if (type) {
		[self setProperty: type forKey: @"type"];
		if (owner)
			[owner trackTypeChanged: self];
	}
}

- (NSString *) source
{
	return [self propertyForKey: @"source"];
}

- (void) setSource: (NSString *)source
{
	if (source) {
		[self setProperty: source forKey: @"source"];
	}
}


/**
 * Getter for the 'storage' property. This is where the temporary
 * storage of an intermediate .wav file is kept.
 *
 * @return The value of the 'storage' property or @c nil if
 * 		it has not been set, yet.
 */
- (NSString *) storage
{
	NSString *temp = [self propertyForKey: @"storage"];
	if (temp)
		return temp;

	return [self propertyForKey: @"source"];
}

/**
 * Setter for the 'storage' property. This is where the temporary
 * storage of an intermediate .wav file is kept.
 *
 * @param destination The new value for the 'storage' property.
 * 		The property is removed if set to @c nil.
 * @return The value of the 'destination' property or @c nil if
 * 		it has not been set, yet.
 */
- (void) setStorage: (NSString *)storage
{
	if (storage) {
		[self setProperty: storage forKey: @"storage"];
	}
}

- (NSString *) description
{
	return [self propertyForKey: @"description"];
}

- (void) setDescription: (NSString *)description
{
	if (description) {
		[self setProperty: description forKey: @"description"];
	}
}

- (long) duration
{
	NSNumber *myDuration = [self propertyForKey: @"duration"];

	if (myDuration)
		return [myDuration longValue];

	// if we could not get the duration in frames we check for the
	// size in bytes and convert it
	myDuration = [self propertyForKey: @"size"];
	if (myDuration) {
		if ([[self type] isEqual: @"data"] || [[self type] isEqual: @"dir"])
			return sizeToFrames([myDuration unsignedLongValue]);
		else
			return audioSizeToFrames([myDuration unsignedLongValue]);
	}

	return 0;
}

- (void) setDuration: (long)duration
{
	[self setProperty: [NSNumber numberWithLong: duration] forKey: @"duration"];
}

- (unsigned) size
{
	NSNumber *mySize = [self propertyForKey: @"size"];

	if (mySize)
		return [mySize unsignedLongValue];

	// if we could not get the size in Bytes we check for the
	// duration in frames and convert it
	mySize = [self propertyForKey: @"duration"];
	if (mySize) {
		if ([[self type] isEqual: @"data"] || [[self type] isEqual: @"dir"])
			return framesToSize([mySize longValue]);
		else
			return framesToAudioSize([mySize longValue]);
	}

	return 0;
}

- (void) setSize: (unsigned)size
{
	[self setProperty: [NSNumber numberWithUnsignedLong: size] forKey: @"size"];
}


//
// class methods
//

@end


//
// Private methods

@implementation Track (Private)

/*
 * RedBook says that audio data must be 16-bit stereo at 44100 Hz.
 * We reject all file containing something else.
 */
- (BOOL) loadFromAudioFile: (NSString *)file;
{
	BOOL	success = NO;

	if ([self loadFromWavFile: file]) {
		success = YES;
	} else if ([self loadFromAuFile: file]) {
		success = YES;
	} else {
		// if the file is supposed be an audio file, but neither
		// wav nor au it must be one of the externally registered ones
		if (isAudioFile(file)) {
			NSString *ext = [[file pathExtension] lowercaseString];
			NSString *type = [NSString stringWithFormat: @"audio:%@", ext];
			id<AudioConverter> converter = [[AppController appController] currentBundleForFileType: ext];

			[self setType: type];
			if (converter != nil) {
				[self setDuration: [converter duration: file]];
				[self setSize: [converter size: file]];
			} else {
				[self setDuration: 0];
				[self setSize: 0];
			}
			success = YES;
		}
	}

	if (success) {
		[self setSource: file];

		if ([self propertyForKey: @"description"] == nil) {
			[self setDescription: [file lastPathComponent]];
		}
	}

	return success;
}

- (BOOL) loadFromWavFile: (NSString *)file
{
	BOOL success = NO;
	NSFileHandle *fileHdl;
	NSData *rawData;
	char buffer[17];
	unsigned int fmtLength = 0;
	unsigned int dataLength = 0;
	unsigned int byteSec = 0;
	unsigned int sampleRate = 0;
	unsigned short byteSample = 0;

	memset(buffer, 0, sizeof(buffer));

	/*
	 * Read the potential .wav header data from the file.
	 */
	fileHdl = [NSFileHandle fileHandleForReadingAtPath: file];
	rawData = [fileHdl readDataOfLength: 64];
	[fileHdl closeFile];

	[rawData getBytes: buffer length: 16];

	if ((strncmp(buffer, "RIFF", 4) == 0)
		   && (strncmp(buffer+8, "WAVE", 4) == 0))	{

		// format length field is at position 16
		[rawData getBytes: &fmtLength range: NSMakeRange(16, 4)];
		fmtLength = GSSwapLittleI32ToHost(fmtLength);
		// sample rate field is at position 24
		[rawData getBytes: &sampleRate range: NSMakeRange(24, 4)];
		sampleRate = GSSwapLittleI32ToHost(sampleRate);
		// bytes per sec field is at position 28
		[rawData getBytes: &byteSec range: NSMakeRange(28, 4)];
		byteSec = GSSwapLittleI32ToHost(byteSec);
		// bytes per sample field is at position 32
		[rawData getBytes: &byteSample range: NSMakeRange(32, 2)];
		byteSample = GSSwapLittleI16ToHost(byteSample);
		// data length field is at position 24 + format data length
		// 24: RIFF header (12) + fmt header (8) + data header (4)
		[rawData getBytes: &dataLength range: NSMakeRange(24+fmtLength, 4)];
		dataLength = GSSwapLittleI32ToHost(dataLength);

		/* check sample rate and sample size */
		if (sampleRate == 44100
			&& byteSample == 4) {

			success = YES;

			// set the duration in frames
			[self setDuration: (double)dataLength * 75. /
							   (double)byteSec];

			[self setType: @"audio:wav"];
			[self setSize: dataLength];
		} else {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
							_(@"Track.no16BitStereo"), file]);
		}
	}
	return success;
}


- (BOOL) loadFromAuFile: (NSString *)file
{
	BOOL success = NO;
	AuHeader  auHdr;
	NSFileHandle *fileHdl;
	NSData *rawData;
	NSFileManager *fileMgr = [NSFileManager defaultManager];

	memset(&auHdr, 0, sizeof(AuHeader));

	/*
	 * Read the potential .au header data from the file.
	 */
	fileHdl = [NSFileHandle fileHandleForReadingAtPath: file];
	rawData = [fileHdl readDataOfLength: sizeof(AuHeader)];
	[fileHdl closeFile];

	[rawData getBytes: &auHdr length: sizeof(AuHeader)];
	if (auHdr.magicNum[0] == '.'
			&& auHdr.magicNum[1] == 's'
			&& auHdr.magicNum[2] == 'n'
			&& auHdr.magicNum[3] == 'd') {

		/* check sample rate and sample size */
		if (GSSwapBigI32ToHost(auHdr.smplSec) == 44100
				&& auEncodings[GSSwapBigI32ToHost(auHdr.encoding)] == 2
				&& GSSwapBigI32ToHost(auHdr.numChannels) == 2) {

			success = YES;

			/*
			 * The field dataLangth maybe -1. In this case we must calculate
			 * the size of the audio part without theheader.
			 */
			if (auHdr.dataLength == 0xffffffff) {
				auHdr.dataLength = [[fileMgr fileAttributesAtPath: file
													 traverseLink: YES] fileSize] -
										GSSwapBigI32ToHost(auHdr.hdrSize);
			}

			// swap dataLength to host endianness
			auHdr.dataLength = GSSwapBigI32ToHost(auHdr.dataLength);

			// set the duration in frames
			[self setDuration: auHdr.dataLength * 75. / (44100.*2.*2.)];

			[self setType: @"audio:au"];
			[self setSize: auHdr.dataLength];
		} else {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
							_(@"Track.no16BitStereo"), file]);
		}
	}
	return success;
}

@end

