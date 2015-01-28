/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "CDparanoiaParametersView.h"
#include "Functions.h"
#include "Constants.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

static CDparanoiaParametersView *singleInstance = nil;


@implementation CDparanoiaParametersView

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
			NSLog (@"Could not load nib \"%@\".", nibName);
			[self dealloc];
		} else {
			view = [window contentView];
			[view retain];

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

- (void) awakeFromNib
{
    // We get our defaults for this panel
    [self initializeFromDefaults];
}


//
// access methods
//

- (NSImage *) image
{
	NSBundle *aBundle;
	
	aBundle = [NSBundle bundleForClass: [self class]];
	
	return AUTORELEASE([[NSImage alloc] initWithContentsOfFile:
					[aBundle pathForResource: @"iconCDparanoia" ofType: @"tiff"]]);
}

- (NSString *) title
{
	return _(@"cdparanoia");
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
	NSDictionary *parameters =
			[[NSUserDefaults standardUserDefaults] objectForKey: @"CDparanoiaParameters"];
    if (nil == parameters) {
        return;
    }

	if ([parameters objectForKey: @"DisableParanoia"] )
    {
		[disParanoiaCheckBox setState: [[parameters objectForKey: @"DisableParanoia"] intValue] ];
    }

	if ([parameters objectForKey: @"DisableExtraParanoia"] )
    {
		[disXParanoiaCheckBox setState: [[parameters objectForKey: @"DisableExtraParanoia"] intValue] ];
    }

	if ([parameters objectForKey: @"DisableScratchRepair"] )
    {
		[disRepairCheckBox setState: [[parameters objectForKey: @"DisableScratchRepair"] intValue] ];
    }
}


/**
 * <p>Checks the values for the programs and displays an alert panel if the
 * backend program is not defined or not executable.</p>
 */
- (void) saveChanges
{
    NSDictionary *params = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey: @"CDparanoiaParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

	[mutableParams setObject: [NSNumber numberWithInt: [disParanoiaCheckBox state]]
					forKey: @"DisableParanoia"];

	[mutableParams setObject: [NSNumber numberWithInt: [disXParanoiaCheckBox state]]
					forKey: @"DisableExtraParanoia"];

	[mutableParams setObject: [NSNumber numberWithInt: [disRepairCheckBox state]]
					forKey: @"DisableScratchRepair"];
    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"CDparanoiaParameters"];
    RELEASE(mutableParams);
	[[NSUserDefaults standardUserDefaults] synchronize];
}


//
// class methods
//
+ (id) singleInstance
{
	if (!singleInstance) {
		singleInstance = [[CDparanoiaParametersView alloc] initWithNibName: @"Parameters"];
	}

	return singleInstance;
}


@end
