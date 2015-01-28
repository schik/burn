/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  OpenISOImagePanel.m
 *
 *  Copyright (c) 2004
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

#include "OpenISOImagePanel.h"

static OpenISOImagePanel *openISOImagePanel = nil;

/**
 * <p>OpenISOImagePanel is a helper to easily set up a file browser
 * for searching ISO images and directly kick off the burning.</p>
 * <p>Actually, it is a simple NSOpenPanel, which has lost its 'OK'
 * button, but instead displays a big, fat 'Burn' button. This 'Burn'
 * button behaves as if it were the original 'OK'. Thus, the caller
 * may simply evaluate the panel's return value to know whether to
 * do something or not.</p>
 * <p>This behaviour is accomplished by a hack relying on NSOpenPanel
 * internals!!</p>
 */
@implementation OpenISOImagePanel

/**
 * <init />
 * <p>The initializer removes the complete bottom view from the
 * panel and adds a new one instead. This is done in order to
 * have a bigger 'Burn' ('OK') button to make the user know that
 * burning will be kicked off right away.</p>
 * <p>The code is taken from NSSavePanel.m and slightly modified.</p>
 */
- (id) init
{
    self = [super init];
    if (self != nil) {
        NSButton *button;
        NSRect r;
		NSImage *image;
        /* this helps to later maintain the tab order */
        NSView *lastKeyView = _browser;
        NSSize size = [[self contentView] frame].size;

        /* remove bottom view and create a new one*/
        [_bottomView removeFromSuperview];
  
        r = NSMakeRect (0, 0, size.width, 64);
        _bottomView = [[NSView alloc] initWithFrame: r];
        [_bottomView setBounds:  r];
        [_bottomView setAutoresizingMask: NSViewWidthSizable|NSViewMaxYMargin];
        [_bottomView setAutoresizesSubviews: YES];
        [[self contentView] addSubview: _bottomView];
        [_bottomView release];

        r = NSMakeRect (8, 39, size.width-17, 21);
        _form = [NSForm new];
        [_form addEntry: _(@"OpenISOImagePanel.name")];
        [_form setFrame: r];
        // Force the size we want
        [_form setCellSize: NSMakeSize (size.width-17, 21)];
        [_form setEntryWidth: size.width-17];
        [_form setInterlineSpacing: 0];
        [_form setAutosizesCells: YES];
        [_form setTag: NSFileHandlingPanelForm];
        [_form setAutoresizingMask: NSViewWidthSizable];
        [_form setDelegate: self];
        [_bottomView addSubview: _form];
        [lastKeyView setNextKeyView: _form];
        lastKeyView = _form;
        [_form release];

        r = NSMakeRect (size.width-319, 6, 27, 27);
        button = [[NSButton alloc] initWithFrame: r]; 
        [button setBordered: YES];
        [button setButtonType: NSMomentaryPushButton];
        image = [NSImage imageNamed: @"common_Home"];
        [button setImage: image];
        [button setImagePosition: NSImageOnly]; 
        [button setTarget: self];
        [button setAction: @selector(_setHomeDirectory)];
        // [_form setNextKeyView: button];
        [button setAutoresizingMask: NSViewMinXMargin];
        [button setTag: NSFileHandlingPanelHomeButton];
        [_bottomView addSubview: button];
        [lastKeyView setNextKeyView: button];
        lastKeyView = button;
        [button release];
  
        r = NSMakeRect (size.width-283, 6, 27, 27);
        button = [[NSButton alloc] initWithFrame: r];
        [button setBordered: YES];
        [button setButtonType: NSMomentaryPushButton];
        image = [NSImage imageNamed: @"common_Mount"]; 
        [button setImage: image]; 
        [button setImagePosition: NSImageOnly]; 
        [button setTarget: self];
        [button setAction: @selector(_mountMedia)];
        [button setAutoresizingMask: NSViewMinXMargin];
        [button setTag: NSFileHandlingPanelDiskButton];
        [_bottomView addSubview: button];
        [lastKeyView setNextKeyView: button];
        lastKeyView = button;
        [button release];

        r = NSMakeRect (size.width-247, 6, 27, 27);
        button = [[NSButton alloc] initWithFrame: r];
        [button setBordered: YES];
        [button setButtonType: NSMomentaryPushButton];
        image = [NSImage imageNamed: @"common_Unmount"]; 
        [button setImage: image];
        [button setImagePosition: NSImageOnly]; 
        [button setTarget: self];
        [button setAction: @selector(_unmountMedia)];
        [button setAutoresizingMask: NSViewMinXMargin];
        [button setTag: NSFileHandlingPanelDiskEjectButton];
        [_bottomView addSubview: button];
        [lastKeyView setNextKeyView: button];
        lastKeyView = button;
        [button release];
  
        r = NSMakeRect (size.width-211, 6, 71, 27);
        button = [[NSButton alloc] initWithFrame: r]; 
        [button setBordered: YES];
        [button setButtonType: NSMomentaryPushButton];
        [button setTitle: _(@"Common.cancel")];
        [button setImagePosition: NSNoImage]; 
        [button setTarget: self];
        [button setAction: @selector(cancel:)];
        [button setAutoresizingMask: NSViewMinXMargin];
        [button setTag: NSFileHandlingPanelCancelButton];
        [_bottomView addSubview: button];
        [lastKeyView setNextKeyView: button];
        lastKeyView = button;
        [button release];

		image = [NSImage imageNamed: @"iconBurn.tiff"];
        /* give the image a proper size */
		[image setScalesWhenResized: YES];
		[image setSize: NSMakeSize(20,20)];
  
        r = NSMakeRect (size.width-131, 6, 120, 27);
        _okButton = [[NSButton alloc] initWithFrame: r]; 
        [_okButton setBordered: YES];
        [_okButton setButtonType: NSMomentaryPushButton];
        [_okButton setTitle:  _(@"Common.Burn")];
        [_okButton setImagePosition: NSImageRight]; 
        [_okButton setImage: image];
        [_okButton setTarget: self];
        [_okButton setAction: @selector(ok:)];
        [_okButton setEnabled: NO];
        [_okButton setAutoresizingMask: NSViewMinXMargin];
        [_okButton setTag: NSFileHandlingPanelOKButton];
        [_bottomView addSubview: _okButton];
        [lastKeyView setNextKeyView: _okButton];
        [_okButton setNextKeyView: _browser];
        [self setDefaultButtonCell: [_okButton cell]];
        [_okButton release];

        [_browser setDoubleAction: @selector(performClick:)];
        [_browser setTarget: _okButton];

        /* setup the rest of the panel */
    	[self setTitle: _(@"OpenISOImagePanel.select")];
	    [self setCanChooseFiles: YES];
    	[self setCanChooseDirectories: NO];
        [self setAllowsMultipleSelection: NO];
    }
    return self;
}


/**
 * <p>Creates the single instance of this panel.</p>
 */
+ (OpenISOImagePanel *) openISOImagePanel
{
    if (!openISOImagePanel)
        openISOImagePanel = [[OpenISOImagePanel alloc] init];

    return openISOImagePanel;
}

@end
