/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>
#include <AppKit/NSHelpManager.h>

#include "ToolPanel.h"
#include "ToolSelector.h"
#include "AppController.h"
#include "Constants.h"
#include "Functions.h"

#include <Burn/ExternalTools.h>

static ToolPanel *singleInstance = nil;


@interface ToolPanel (Private)
- (void) getAvailableTools;
@end


@implementation ToolPanel (Private)


//
// other methods
//
- (void) getAvailableTools
{
	int i;
	NSArray *bundles;
	id tool;

	[burnToolPopUp removeAllItems];
	[isoToolPopUp removeAllItems];

	bundles = [[AppController appController] allBundles];

	for (i = 0; i < [bundles count]; i++) {
		tool = [bundles objectAtIndex: i];
		if ([[(id)tool class] conformsToProtocol: @protocol(Burner)]) {
			[burnToolPopUp addItemWithTitle: [(id<BurnTool>)tool name]];
		} else if ([[(id)tool class] conformsToProtocol: @protocol(IsoImageCreator)]) {
			[isoToolPopUp addItemWithTitle: [(id<BurnTool>)tool name]];
		}
	}

	if ([burnToolPopUp numberOfItems] == 0) {
		[burnToolPopUp addItemWithTitle: _(@"ToolPanel.empty")];
	}
	if ([isoToolPopUp numberOfItems] == 0) {
		[isoToolPopUp addItemWithTitle: _(@"ToolPanel.empty")];
	}
}

@end

@implementation ToolPanel


- (id) init
{
	[self initWithNibName: @"ToolPanel"];
	return self;
}


- (id) initWithNibName: (NSString *) nibName;
{
	if (singleInstance) {
		[self dealloc];
	} else {
		self = [super init];
		if (![NSBundle loadNibNamed: nibName owner: self]) {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
								_(@"Common.loadNibFail"), nibName]);
		} else {
			view = [panel contentView];
			[view retain];

			singleInstance = self;
		}
	}
	return singleInstance;
}

- (void) dealloc
{
	/*
	 * Make the compiler shut up.
	 */
    [super dealloc];
}

- (void) awakeFromNib
{
	burnToolPopUp = [toolTable burnToolPopUp];
	[burnToolPopUp setTarget: self];
	[burnToolPopUp setAction: @selector(toolChanged)];

	isoToolPopUp = [toolTable isoToolPopUp];
	[isoToolPopUp setTarget: self];
	[isoToolPopUp setAction: @selector(toolChanged)];

	[toolTable setTarget: self action: @selector(toolChanged)];

	[self initializeFromDefaults];
}


//
// PreferencesModule methods
//

- (NSImage *) image
{
	NSBundle *aBundle;
	
	aBundle = [NSBundle bundleForClass: [self class]];
	
	return AUTORELEASE([[NSImage alloc] initWithContentsOfFile:
					[aBundle pathForResource: @"iconGeneral" ofType: @"tiff"]]);
}

- (NSString *) title
{
	return _(@"ToolPanel.title");
}

- (NSView *) view
{
	return view;
}

- (BOOL) hasChangesPending
{
	return YES;
}


- (void) initializeFromDefaults
{
	NSString *temp;

	[self getAvailableTools];
	[toolTable getAvailableTools];

	temp = [[[NSUserDefaults standardUserDefaults] objectForKey: @"SelectedTools"] objectForKey: @"BurnSW"];
	if (temp && [temp length]) {
		[burnToolPopUp selectItemWithTitle: temp];
	} else {
		[burnToolPopUp selectItemAtIndex: 0];
	}

	temp = [[[NSUserDefaults standardUserDefaults] objectForKey: @"SelectedTools"] objectForKey: @"ISOSW"];
	if (temp && [temp length]) {
		[isoToolPopUp selectItemWithTitle: temp];
	} else {
		[isoToolPopUp selectItemAtIndex: 0];
	}

	[[NSNotificationCenter defaultCenter]
		postNotificationName: ToolChanged
		object: nil
		userInfo: nil];
}

- (void) saveChanges
{
	NSMutableDictionary *selectedTools = [NSMutableDictionary dictionary];

	[selectedTools setObject: [burnToolPopUp titleOfSelectedItem]
					  forKey: @"BurnSW"];
	[selectedTools setObject: [isoToolPopUp titleOfSelectedItem]
					  forKey: @"ISOSW"];

	[toolTable saveChanges: selectedTools];
	[[NSUserDefaults standardUserDefaults] setObject: selectedTools forKey: @"SelectedTools"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}



- (void) toolChanged: (id) sender
{
	[self saveChanges];

	[[NSNotificationCenter defaultCenter]
		postNotificationName: ToolChanged
		object: nil
		userInfo: nil];
}

//
// class methods
//
+ (id) singleInstance
{
	if (singleInstance == nil) {
		singleInstance = [[ToolPanel alloc] init];
	}

	return singleInstance;
}

@end
