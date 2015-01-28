/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "MkIsoFsParametersView.h"
#include "MkIsoFsController.h"
#include "Functions.h"
#include "Constants.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

static MkIsoFsParametersView *singleInstance = nil;


@implementation MkIsoFsParametersView

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
			NSLog (@"MkIsoFs: Could not load nib \"%@\".", nibName);
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
					[aBundle pathForResource: @"iconMkIsoFs" ofType: @"tiff"]]);
}

- (NSString *) title
{
	return @"mkisofs";
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
    NSString *imagePath;
	NSDictionary *parameters =
			[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"MkIsofsParameters"];

    [imageNameTextField setStringValue:
        [NSString stringWithFormat: @"%@/NewImage.iso", NSHomeDirectory()]];

    if (nil == parameters) {
        // No parameters yet saved -> no defaults to set
        return;
    }

    imagePath = [parameters objectForKey: @"ImagePath"];
    if ((nil != imagePath) && ![imagePath isEqualToString: @""]) {
        [imageNameTextField setStringValue: imagePath];
    }

	if ([parameters objectForKey: @"RRExtensions"]) {
		[rockrCheckBox setState: [[parameters objectForKey: @"RRExtensions"] intValue]];
    } else {
		[rockrCheckBox setState: 1];
	}

	if ([parameters objectForKey: @"JolietExtensions"]) {
		[jolietCheckBox setState: [[parameters objectForKey: @"JolietExtensions"] intValue]];
    }

	if ([parameters objectForKey: @"FollowSymlinks"]) {
		[symlinkCheckBox setState: [[parameters objectForKey: @"FollowSymlinks"] intValue]];
    }

	if ([parameters objectForKey: @"NoBackupFiles"]) {
		[nobakCheckBox setState: [[parameters objectForKey: @"NoBackupFiles"] intValue]];
    }

	if ([parameters objectForKey: @"FullISOFilenames"]) {
		[longNameCheckBox setState: [[parameters objectForKey: @"FullISOFilenames"] intValue]];
    }

	if ([parameters objectForKey: @"DotStartAllowed"]) {
		[dotStartCheckBox setState: [[parameters objectForKey: @"DotStartAllowed"] intValue]];
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
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"MkIsofsParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    [mutableParams setObject: [imageNameTextField stringValue]
                      forKey: @"ImagePath"];

	[mutableParams setObject: [NSNumber numberWithInt: [rockrCheckBox state]]
                      forKey: @"RRExtensions"];

	[mutableParams setObject: [NSNumber numberWithInt: [jolietCheckBox state]]
                      forKey: @"JolietExtensions"];

	[mutableParams setObject: [NSNumber numberWithInt: [symlinkCheckBox state]]
                      forKey: @"FollowSymlinks"];

	[mutableParams setObject: [NSNumber numberWithInt: [nobakCheckBox state]]
                      forKey: @"NoBackupFiles"];

	[mutableParams setObject: [NSNumber numberWithInt: [longNameCheckBox state]]
                      forKey: @"FullISOFilenames"];

	[mutableParams setObject: [NSNumber numberWithInt: [dotStartCheckBox state]]
                      forKey: @"DotStartAllowed"];

	[mutableParams setObject: [isoLevelPopUp titleOfSelectedItem] forKey: @"IsoLevel"];
    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"MkIsofsParameters"];
    RELEASE(mutableParams);
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) chooseImageClicked: (id) sender
{
    NSSavePanel *panel;
    NSString *dirName;
    NSString *fileName;
    int result;

    dirName = [imageNameTextField stringValue];
    fileName = [dirName lastPathComponent];
    dirName = [dirName stringByDeletingLastPathComponent];

    panel = [NSSavePanel savePanel];
    [panel setCanCreateDirectories: YES];
    [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"iso", nil]];
    [panel setTitle: _(@"Select file")];

    result = [panel runModalForDirectory: dirName
                                    file: fileName];
  
    if (result == NSOKButton) {
        [imageNameTextField setStringValue: [panel filename]];
    }
}


//
// class methods
//
+ (id) singleInstance
{
	if (!singleInstance) {
		singleInstance = [[MkIsoFsParametersView alloc] initWithNibName: @"Parameters"];
	}

	return singleInstance;
}


@end
