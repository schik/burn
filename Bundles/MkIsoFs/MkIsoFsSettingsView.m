/* vim: set ft=objc et sw=4 ts=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "MkIsoFsSettingsView.h"
#include "Functions.h"
#include "Constants.h"

#ifdef _
#undef _
#endif

#define _(X) \
    [[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

static MkIsoFsSettingsView *singleInstance = nil;


@implementation MkIsoFsSettingsView

- (id) init
{
    return [self initWithNibName: @"Settings"];
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

- (void) chooseClicked: (id)sender
{
    NSArray *fileToOpen;
    NSOpenPanel *oPanel;
    NSString *dirName;
    NSString *fileName;
    int result;

    dirName = [programTextField stringValue];
    fileName = [dirName lastPathComponent];
    dirName = [dirName stringByDeletingLastPathComponent];

    oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection: NO];
    [oPanel setCanChooseDirectories: NO];
    [oPanel setCanChooseFiles: YES];

    result = [oPanel runModalForDirectory: dirName
                                     file: fileName
                                    types: nil];
  
    if (result == NSOKButton) {
        fileToOpen = [oPanel filenames];

        if ([fileToOpen count] > 0) {
            fileName = [fileToOpen objectAtIndex: 0];
            [programTextField setStringValue: fileName];
        }
    }
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
    NSString *temp;
    NSDictionary *parameters =
            [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"MkIsofsParameters"];

    temp = [parameters objectForKey: @"Program"];
    if (!temp) {
        temp = which(@"mkisofs");
    }
    if (temp) {
        [programTextField setStringValue: temp];
    }
}


/*
 * saveChanges checks the values for the programs and displays an alert panel
 * if the program is not defined or not executable.
 */
- (void) saveChanges
{
    NSString *mkisofs;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"MkIsofsParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    mkisofs = [programTextField stringValue];

    if (!checkProgram(mkisofs)) {
        NSRunAlertPanel(@"MkIsoFs.burntool",
                        [NSString stringWithFormat:
                                _(@"Program for %@ not defined or not executable. %@ may not run correctly."),
                                @"mkisofs", @"MkIsoFs.burntool"],
                        _(@"OK"), nil, nil);
    }

    [mutableParams setObject: mkisofs forKey: @"Program"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"MkIsofsParameters"];
    RELEASE(mutableParams);
    [[NSUserDefaults standardUserDefaults] synchronize];
}


//
// class methods
//
+ (id) singleInstance
{
    if (!singleInstance) {
        singleInstance = [[MkIsoFsSettingsView alloc] initWithNibName: @"Settings"];
    }

    return singleInstance;
}


@end
