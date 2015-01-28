/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  ExtProgressIndicator.m
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <AppKit/NSAttributedString.h>
#include <AppKit/NSAttributedString.h>
#include <AppKit/NSGraphics.h>
#include <GNUstepGUI/GSTheme.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSParagraphStyle.h>
#include <Foundation/Foundation.h>

#include "ExtProgressIndicator.h"

#include "Constants.h"
#include "Functions.h"

static inline NSSize
my_sizeForBorderType (NSBorderType aType)
{
  return [[GSTheme theme] sizeForBorderType: aType];
}


@implementation ExtProgressIndicator

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame: frameRect];
	if (self) {
		sections = [NSMutableArray new];
	}

	return self;
}

- (void) dealloc
{
	[sections release];
    [super dealloc];
}

- (void) addSection: (NSDictionary *)newSection
{
	[sections addObject: newSection];
}

- (void) removeLastSection
{
	if ([sections count]) {
		[sections removeLastObject];
	}
}

- (void) drawRect: (NSRect) rect
{
	NSRect origRect;

    [super drawRect: rect];

    // Calculate the inside rect to be drawn
	if ([self isBezeled]) {
		NSSize borderSize = my_sizeForBorderType (NSBezelBorder);
		origRect = NSInsetRect([self bounds], borderSize.width, borderSize.height);
	} else
		origRect = [self bounds];

    // Do something only if the actual value is larger than the minimum
    if ([self doubleValue] > [self minValue]) {
        double min = [self minValue];
        double max = [self maxValue];
        int i;
        for (i = 0; i < [sections count]; i++) {
            double value = [[[sections objectAtIndex: i] objectForKey: @"value"] doubleValue];
		    NSRect fillRect = origRect;

            if (value < min)
                value = min;
            if (value > max)
                value = max;

            if ([self isVertical]){
                fillRect.size.height = 1;
                fillRect.origin.y += NSHeight(origRect) * (value / (max - min));
            } else {
                fillRect.size.width = 1;
                fillRect.origin.x += NSWidth(origRect) * (value / (max - min));
            }

			fillRect = NSIntersectionRect(fillRect, rect);
			if (!NSIsEmptyRect(fillRect))
			{
				[[[sections objectAtIndex: i] objectForKey: @"color"] set];
				NSRectFill(fillRect);
			}
        }
    }
}

@end


@implementation CDLengthIndicator

- (id) initWithFrame: (NSRect) frameRect
{
	NSRect frame = NSMakeRect(0,0,frameRect.size.width,frameRect.size.height);
	NSMutableParagraphStyle *pStyle;

	self = [super initWithFrame: frameRect];
	if (self) {
		/*
		 * Create the progress indicator.
		 * Default audio CD length is 74 min. We use size in kB for
		 * the indicator.
		 */
		lengthIndicator = [[ExtProgressIndicator alloc] initWithFrame: frame];
		[lengthIndicator setBezeled: YES];
		[lengthIndicator setIndeterminate: NO];
		[lengthIndicator setControlTint: NSProgressIndicatorPreferredThickness];
		[lengthIndicator setMinValue: 0];
		[lengthIndicator setMaxValue: framesToSize((long)CDLength100*60*FramesPerSecond)];
		[lengthIndicator addSection: [NSDictionary dictionaryWithObjectsAndKeys:
											[NSColor greenColor], @"color",
											[NSNumber numberWithDouble:
                                                framesToSize((long)CDLength74*60*FramesPerSecond)],
                                            @"value", nil]];
		[lengthIndicator addSection: [NSDictionary dictionaryWithObjectsAndKeys:
											[NSColor yellowColor], @"color",
											[NSNumber numberWithDouble:
                                                framesToSize((long)CDLength80*60*FramesPerSecond)],
                                            @"value", nil]];
		[lengthIndicator addSection: [NSDictionary dictionaryWithObjectsAndKeys:
											[NSColor redColor], @"color",
											[NSNumber numberWithDouble:
                                                framesToSize((long)CDLength90*60*FramesPerSecond)],
                                            @"value", nil]];
		[lengthIndicator setAutoresizingMask: NSViewWidthSizable];
		[self addSubview: lengthIndicator];

		pStyle = [NSMutableParagraphStyle new];
		[pStyle setAlignment: NSRightTextAlignment];
		labelAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
						    [NSFont boldSystemFontOfSize: 0], NSFontAttributeName,
							pStyle, NSParagraphStyleAttributeName,
						    NULL] retain];
		[pStyle release];

		sizeLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(frameRect.size.width-105,0,100,frameRect.size.height)];
		[sizeLabel setDrawsBackground: NO];
		[sizeLabel setEditable: NO];
		[sizeLabel setSelectable: NO];
		[sizeLabel setBordered: NO];
		[sizeLabel setBezeled: NO];
		[sizeLabel setAlignment: NSRightTextAlignment];
		[sizeLabel setAutoresizingMask: NSViewMinXMargin];
		[sizeLabel setStringValue: [[[NSAttributedString new] initWithString: _(@"Common.0MB")
												 attributes: labelAttributes] autorelease]];
		[self addSubview: sizeLabel];
	}

	return self;
}

- (void) dealloc
{
	[lengthIndicator release];
	[sizeLabel release];
	[labelAttributes release];
	[super dealloc];
}

- (void) setDoubleValue: (double)doubleValue
{
	[lengthIndicator setDoubleValue: doubleValue];

	[sizeLabel setStringValue: [[[NSAttributedString new] initWithString:
												[NSString stringWithFormat: _(@"Common.MB"),
												doubleValue/1024./1024.]
											 attributes: labelAttributes] autorelease]];
}


- (void) forwardInvocation: (NSInvocation *)invocation
{
	if ([lengthIndicator respondsToSelector: [invocation selector]])
		[invocation invokeWithTarget: lengthIndicator];
	else
		[self doesNotRecognizeSelector: [invocation selector]];
}

@end
