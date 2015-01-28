/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "CDparanoiaSettingsView.h"
#include "Functions.h"
#include "Constants.h"

#ifdef _
#undef _
#endif

#define _(X) \
    [[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]

static CDparanoiaSettingsView *singleInstance = nil;


@implementation CDparanoiaSettingsView

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
            NSLog (@"CDparanoia: Could not load nib \"%@\".", nibName);
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
    NSString *temp;
    NSDictionary *parameters =
            [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CDparanoiaParameters"];

    temp = [parameters objectForKey: @"Program"];
    if (!temp) {
        temp = which(@"cdparanoia");
    }
    if (temp) {
        [programTextField setStringValue: temp];
    }
}


/**
 * <p>Checks the values for the programs and displays an alert panel if the
 * backend program is not defined or not executable.</p>
 */
- (void) saveChanges
{
    NSString *cdparanoia;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"CDparanoiaParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    cdparanoia = [programTextField stringValue];

    if (!checkProgram(cdparanoia)) {
        NSRunAlertPanel(@"CDparanoia.burntool",
                        [NSString stringWithFormat:
                                _(@"Program for %@ not defined or not executable. %@ may not run correctly."),
                                @"cdparanoia", @"CDparanoia.burntool"],
                        _(@"OK"), nil, nil);
    }

    [mutableParams setObject: cdparanoia forKey: @"Program"];
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
        singleInstance = [[CDparanoiaSettingsView alloc] initWithNibName: @"Settings"];
    }

    return singleInstance;
}


@end
