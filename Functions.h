/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  Functions.h
 *
 *  Copyright (c) 2002, 2011
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
 
#ifndef FUNCTIONS_H
#define FUNCTIONS_H

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@class NSString;
@class NSMenuItem;
@class NSDictionary;

#ifndef GNUSTEP_BASE_VERSION
#define RETAIN(object)          [object retain]
#define RELEASE(object)         [object release]
#define AUTORELEASE(object)     [object autorelease]
#define TEST_RELEASE(object)    ({ if (object) [object release]; })
#define ASSIGN(object,value)    ({\
id __value = (id)(value); \
id __object = (id)(object); \
if (__value != __object) \
  { \
    if (__value != nil) \
      { \
        [__value retain]; \
      } \
    object = __value; \
    if (__object != nil) \
      { \
        [__object release]; \
      } \
  } \
})

#define DESTROY(object) ({ \
  if (object) \
    { \
      id __o = object; \
      object = nil; \
      [__o release]; \
    } \
})

#define NSLocalizedString(key, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

#define _(X) NSLocalizedString (X, @"")

#endif	// GNUSTEP_BASE_VERSION

#define ___(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

#define MAKE_LABEL(label, rect, str, align, release, view) { \
	label = [[NSTextField alloc] initWithFrame: rect];	\
	if (align == 'c') [label setAlignment: NSCenterTextAlignment]; \
	else if (align == 'r') [label setAlignment: NSRightTextAlignment]; \
	else [label setAlignment: NSLeftTextAlignment]; \
	[label setBackgroundColor: [NSColor windowBackgroundColor]]; \
	[label setBezeled: NO]; \
	[label setEditable: NO]; \
	[label setSelectable: NO]; \
	if (str) [label setStringValue: str]; \
	[view addSubview: label]; \
	if (release) RELEASE (label); \
}

#define MAKE_LOCALIZED_LABEL(label, rect, str, comm, align, release, view) { \
	label = [[NSTextField alloc] initWithFrame: rect];	\
	[label setFont: [NSFont systemFontOfSize: 12]]; \
	if (align == 'c') [label setAlignment: NSCenterTextAlignment]; \
	else if (align == 'r') [label setAlignment: NSRightTextAlignment]; \
	else [label setAlignment: NSLeftTextAlignment]; \
	[label setBackgroundColor: [NSColor windowBackgroundColor]]; \
	[label setBezeled: NO]; \
	[label setEditable: NO]; \
	[label setSelectable: NO]; \
	if (str) [label setStringValue: NSLocalizedString(str, comm)]; \
	[view addSubview: label]; \
	if (release) RELEASE (label); \
}

#define STROKE_LINE(c, x1, y1, x2, y2) { \
	[[NSColor c] set]; \
	[NSBezierPath strokeLineFromPoint: NSMakePoint(x1, y1) \
	toPoint: NSMakePoint(x2, y2)]; \
}

#define SELF_BUNDLE [NSBundle bundleForClass: [self class]]

NSString *which(NSString *name);
BOOL checkProgram(NSString *name);
NSString *UserLibraryPath(void);
NSString *LocalLibraryPath(void);
id loadAudioCD(void);
NSArray *getAvailableDrives(void);
BOOL isAudioFile(NSString *fileName);

NSString* framesToString(long frames);
double framesToSeconds(long frames);
unsigned framesToSize(long frames);
unsigned framesToAudioSize(long frames);
long secondsToFrames(double seconds);
long sizeToFrames(unsigned size);
long audioSizeToFrames(unsigned size);

/*
 * The following functions provide access to the singletons used in Burn.app.
 * Doing it this way makes it easier to exchange them.
 */
void releaseSharedConsole();
void logToConsole(NSString *priority, NSString *theMessage);

id sharedInspectorsWin();
void releaseSharedInspectorsWin();

void releaseSharedReadme();

void convertUserDefaults(void);

#endif
