/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "CreateIsoParametersView.h"
#include "Functions.h"
#include "Constants.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

static CreateIsoParametersView *singleInstance = nil;


@implementation CreateIsoParametersView

- (id) init
{
	return [self initWithNibName: @"Parameters"];
}

- (id) initWithNibName: (NSString *) nibName
{
	if (singleInstance) {
		[self dealloc];
	} else {
		self = [super init];

		if (![NSBundle loadNibNamed: nibName owner: self]) {
			NSLog (_(@"CreateIso: Could not load nib \"%@\"."), nibName);
			[self dealloc];
		} else {
			view = [window contentView];
			[view retain];

			// We get our defaults for this panel
			[self initializeFromDefaults];

			singleInstance = self;
		}
	}

	return singleInstance;
}


- (void) dealloc
{
	singleInstance = nil;
	RELEASE(view);

	[super dealloc];
}



//
// access methods
//

- (NSImage *) image
{
	NSBundle *aBundle;
	
	aBundle = [NSBundle bundleForClass: [self class]];
	
	return AUTORELEASE([[NSImage alloc] initWithContentsOfFile:
					[aBundle pathForResource: @"iconCreateIso" ofType: @"tiff"]]);
}

- (NSString *) title
{
	return @"createiso";
}

- (NSView *) view
{
	return view;
}

- (BOOL) hasChangesPending
{
	return YES;
}


//
//
//
- (void) initializeFromDefaults
{
	NSMutableDictionary *parameters =
			[[NSUserDefaults standardUserDefaults] objectForKey: @"CreateIsoParameters"];

	if ([parameters objectForKey: @"RRExtensions"]) {
		[rockRidgeCheckBox setState: [[parameters objectForKey: @"RRExtensions"] intValue]];
    } else {
		[rockRidgeCheckBox setState: 1];
	}

	if ([parameters objectForKey: @"JolietExtensions"]) {
		[jolietCheckBox setState: [[parameters objectForKey: @"JolietExtensions"] intValue]];
    }

	if ([parameters objectForKey: @"IsoLevel"]) {
		[isoLevelPopUp selectItemWithTitle: [parameters objectForKey: @"IsoLevel"]];
	}
}


/*
 * saveChanges checks the values for the programs and displays an alert panel
 * if the program is not defined or not executable.
 */
- (void) saveChanges
{
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

	[parameters setObject: [NSNumber numberWithInt: [rockRidgeCheckBox state]]
					forKey: @"RRExtensions"];

	[parameters setObject: [NSNumber numberWithInt: [jolietCheckBox state]]
					forKey: @"JolietExtensions"];

	[parameters setObject: [isoLevelPopUp titleOfSelectedItem] forKey: @"IsoLevel"];
    [[NSUserDefaults standardUserDefaults] setObject: parameters forKey: @"CreateIsoParameters"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


//
// class methods
//
+ (id) singleInstance
{
	if (!singleInstance) {
		singleInstance = [[CreateIsoParametersView alloc] initWithNibName: @"Parameters"];
	}

	return singleInstance;
}

@end
