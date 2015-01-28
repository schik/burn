/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>

#include "ToolSelector.h"

#include "AppController.h"
#include "Constants.h"
#include "Functions.h"

#define VMARGIN 6

@implementation ToolSelector

- (id) initWithFrame: (NSRect) frameRect
{
	int optionalTools = 0;
	NSTextField *text;
	NSPopUpButton *popUp;

	self = [super initWithFrame: frameRect];
	if (self) {
		int i;
		float height;
		NSRect frame;

		additionalPopUps = [NSMutableArray new];
		fileTypes = RETAIN([[AppController appController] registeredFileTypes]);
		optionalTools = [fileTypes count];
		
		height = (optionalTools + 2) * (TextFieldHeight + VMARGIN);
		frame = NSMakeRect(0, 0, frameRect.size.width, height);

		toolView = [[NSView alloc] initWithFrame: frame];
		[toolView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

		MAKE_LABEL(text, NSMakeRect(10, height - (TextFieldHeight+VMARGIN)+VMARGIN/2, 130, TextFieldHeight),
					_(@"Common.Burn"), 'l', YES, toolView);
		[text setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

		burnToolPopUp = [[NSPopUpButton alloc] initWithFrame: NSZeroRect pullsDown: NO];
		[burnToolPopUp setFrame: NSMakeRect(150, height - (TextFieldHeight+VMARGIN)+VMARGIN/2, 150, 20)];
		[burnToolPopUp setAutoenablesItems: NO];
		[burnToolPopUp setAutoresizingMask: NSViewWidthSizable | NSViewMinXMargin | NSViewMinYMargin];
		[toolView addSubview: burnToolPopUp];

		MAKE_LABEL(text, NSMakeRect(10, height - 2*(TextFieldHeight+VMARGIN)+VMARGIN/2, 130, TextFieldHeight),
					_(@"ToolSelector.createISO"), 'l', YES, toolView);
		[text setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

		isoToolPopUp = [[NSPopUpButton alloc] initWithFrame: NSZeroRect pullsDown: NO];
		[isoToolPopUp setFrame: NSMakeRect(150, height - 2*(TextFieldHeight+VMARGIN)+VMARGIN/2, 150, 20)];
		[isoToolPopUp setAutoenablesItems: NO];
		[isoToolPopUp setAutoresizingMask: NSViewWidthSizable | NSViewMinXMargin | NSViewMinYMargin];
		[toolView addSubview: isoToolPopUp];

		for (i = 0; i < optionalTools; i++) {
			int relpos = i + 3;
			NSString *lblText = [NSString stringWithFormat: _(@"ToolSelector.convertAudio"), [fileTypes objectAtIndex: i]];
			MAKE_LABEL(text, NSMakeRect(10, height - relpos*(TextFieldHeight+VMARGIN)+VMARGIN/2, 130, TextFieldHeight),
					lblText, 'l', YES, toolView);
		    [text setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

			popUp = [[NSPopUpButton alloc] initWithFrame: NSZeroRect pullsDown: NO];
			[popUp setFrame: NSMakeRect(150, height - relpos*(TextFieldHeight+VMARGIN)+VMARGIN/2, 150, 20)];
			[popUp setAutoenablesItems: NO];
		    [popUp setAutoresizingMask: NSViewWidthSizable | NSViewMinXMargin | NSViewMinYMargin];
			[toolView addSubview: popUp];
			[additionalPopUps addObject: popUp];
			[popUp release];
		}

		frame = NSMakeRect(0,0,frameRect.size.width,frameRect.size.height);
		scrollView = [[NSScrollView alloc] initWithFrame: frame];
		[scrollView setHasHorizontalScroller: NO];
		[scrollView setHasVerticalScroller: YES];
		[scrollView setDocumentView: toolView];
		[scrollView setBorderType: NSGrooveBorder];
		[scrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

		[self addSubview: scrollView];
	}
	return self;
}

- (void) dealloc
{
	[fileTypes release];
	[additionalPopUps release];
	[burnToolPopUp release];
	[isoToolPopUp release];
	[toolView release];
	[scrollView release];
	[super dealloc];
}

- (NSPopUpButton *) burnToolPopUp
{
	return burnToolPopUp;
}

- (NSPopUpButton *) isoToolPopUp
{
	return isoToolPopUp;
}

- (void) getAvailableTools
{
	int i, j;
	for (i = 0; i < [fileTypes count]; i++) {
		NSString *temp;
		NSString *fileType = [fileTypes objectAtIndex: i];
		NSPopUpButton *popUp = [additionalPopUps objectAtIndex: i];
		NSArray *bundles = [[AppController appController] bundlesForFileType: fileType];

		for (j = 0; j < [bundles count]; j++) {
			id tool = [bundles objectAtIndex: j];
			[popUp addItemWithTitle: [(id<BurnTool>)tool name]];
		}

		if ([popUp numberOfItems] == 0) {
			[popUp addItemWithTitle: _(@"Common.empty")];
		}

		temp = [[[NSUserDefaults standardUserDefaults] objectForKey: @"SelectedTools"] objectForKey: fileType];
		if (temp && [temp length]) {
			[popUp selectItemWithTitle: temp];
		} else {
			[popUp selectItemAtIndex: 0];
		}
	}
}

- (void) saveChanges: (NSMutableDictionary *) selectedTools
{
	int i;
	for (i = 0; i < [fileTypes count]; i++) {
		NSString *fileType = [fileTypes objectAtIndex: i];
		NSPopUpButton *popUp = [additionalPopUps objectAtIndex: i];
		[selectedTools setObject: [popUp titleOfSelectedItem] forKey: fileType];
	}
}

- (void) setTarget: (id)target action: (SEL)action
{
	int i;
	for (i = 0; i < [additionalPopUps count]; i++) {
		NSPopUpButton *popUp = [additionalPopUps objectAtIndex: i];
		[popUp setTarget: target];
		[popUp setAction: action];
	}
}


@end
