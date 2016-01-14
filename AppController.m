/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	AppController.m
 *
 *	Copyright (c) 2002-2005, 2011, 2016
 *
 *	Author: Andreas Schik <andreas@schik.de>
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <AppKit/NSDocumentController.h>

#include "AppController.h"

#include "Inspectors/InspectorsWin.h"
#include "Constants.h"
#include "Functions.h"
#include "PreferencesWindowController.h"
#include "ParametersWindowController.h"
#include "Project.h"
#include "ProjectWindowController.h"
#include "BlankPanel.h"
#include "ReadmePanel.h"
#include "ConsolePanel.h"
#include "BurnProgressController.h"
#include "WorkInProgress.h"

static NSMutableDictionary *worksInProgress = nil;
static AppController *appController = nil;

@implementation AppController


/*
 * Return the shared AppContoller instance. If it does not
 * exist, yet, create it.
 */
+ (AppController *) appController
{
	if (appController == nil) {
		appController = [[AppController alloc] init];
	}	
	return appController;
}

+ (void) initialize
{
	/*
	 * Set up new user defaults structure.
	 */
	 // [defaults setObject:anObject forKey:keyForThatObject];
    convertUserDefaults();
}

- (id) init
{
	self = [super init];

	burnerLock = [NSLock new];
	
	// We initialize our mutable array containing all opened windows
	allProjectWindows = [[NSMutableArray alloc] init];

	// We initialize our mutable array containing all our bundles
	externalTools = [NSMutableDictionary new];
	audioConverters = [NSMutableDictionary new];

	currentWorkingPath = nil;
    worksInProgress = [NSMutableDictionary new];

	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self
						   name: DisplayWorkInProgress
						   object: nil];

    RELEASE(worksInProgress);

	// We release our array containing all our windows
	RELEASE(allProjectWindows);
	allProjectWindows = nil;

	// We release our current working path
	RELEASE(currentWorkingPath);

	RELEASE(externalTools);
	RELEASE(audioConverters);
	RELEASE(burnerLock);

	releaseSharedInspectorsWin();
    releaseSharedReadme();
	// we close our console, this should be the very last action here
	releaseSharedConsole();

	[super dealloc];
}

- (void) applicationWillFinishLaunching: (NSNotification *) not
{
	[self createMenu];

	[[NSNotificationCenter defaultCenter] addObserver: self
						   selector: @selector(displayWorkInProgress:)
						   name: DisplayWorkInProgress
						   object: nil];

	[self setCurrentWorkingPath: NSHomeDirectory()];

	[[NSDocumentController sharedDocumentController] setShouldCreateUI: YES];
}

- (void) applicationDidFinishLaunching: (NSNotification *) not
{
    NSDictionary *params =
        [[NSUserDefaults standardUserDefaults] objectForKey: @"GeneralParameters"];

    // we create some panels
	sharedInspectorsWin();

    // If we don't already have a window open we open one, now
    if (!lastProjectWindowOnTop) {
        if ((nil == [params objectForKey: @"OpenCompilationOnStartup"])
            || (0 != [[params objectForKey: @"OpenCompilationOnStartup"] intValue])) {
            [self newProject: self];
        }
    }

	// now we are ready to tell the system that we can receive service requests
	[NSApp setServicesProvider: self];
	logToConsole(MessageStatusInfo, _(@"AppController.svcRegistered"));

	// We load all our bundles
	[self loadTools];

	logToConsole(MessageStatusInfo, _(@"AppController.loaded"));
}

- (BOOL) applicationShouldTerminate: (id) sender
{
	if (burnerInUse) {
		NSBeep();
		return NO;
	}

	return YES;
}


- (BOOL) validateMenuItem: (NSMenuItem*) item
{
	SEL	action = [item action];

	if (sel_isEqual(action, @selector(closeProject:))
    	|| sel_isEqual(action, @selector(miniaturize:))
	    || sel_isEqual(action, @selector(saveDocument:))
    	|| sel_isEqual(action, @selector(saveDocumentAs:))) {
		if (lastProjectWindowOnTop == nil)
			return NO;
	}

	/*
	 * Disable Media inspector and blanking if either a burning process
	 * is going on or no burner is present.
	 */
	if ((sel_isEqual(action, @selector(showInspector:)) && [[item title] isEqualToString: _(@"Common.media")])
    	|| sel_isEqual(action, @selector(blankCDRW:))) {
		NSString *burner;

		// are we started for the first time?
		burner = [[[NSUserDefaults standardUserDefaults] objectForKey: @"SelectedTools"]
									objectForKey: @"BurnSW"];

		if (burnerInUse || (!burner && ![burner length]))
			return NO;
	}

	return YES;
}


- (void) showPrefPanel: (id) sender
{
	[[[PreferencesWindowController singleInstance] window] makeKeyAndOrderFront: self];
}

- (void) newProject: (id) sender
{
	[[NSDocumentController sharedDocumentController]
			openUntitledDocumentOfType: @"burnprj" display: YES];

	if (burnerInUse) {
		[[NSNotificationCenter defaultCenter]
					postNotificationName: BurnerInUse
					object: nil
					userInfo: [NSDictionary dictionaryWithObject: @"YES" forKey: @"InUse"]];
	}
}

- (void) openProject: (id) sender
{
	[[NSDocumentController sharedDocumentController] openDocument: sender];

	if (burnerInUse) {
		[[NSNotificationCenter defaultCenter]
					postNotificationName: BurnerInUse
					object: nil
					userInfo: [NSDictionary dictionaryWithObject: @"YES" forKey: @"InUse"]];
	}
}

- (void) closeProject: (id) sender
{
	if (lastProjectWindowOnTop) {
		[lastProjectWindowOnTop performClose: sender];
	}
}

- (void) openRecentDoc: (id) sender
{
	[[NSDocumentController sharedDocumentController]
			openDocumentWithContentsOfFile: [sender title] display: YES];
}

- (void) showConsole: (id) sender
{
	[[ConsolePanel consolePanel] showWindow: self];
}

- (void) showInspector: (id) sender
{
	id inspectorsWin = sharedInspectorsWin();
	[inspectorsWin orderFront: nil]; 

	[inspectorsWin activateInspectorWithTitle: [(NSMenuItem *)sender title]];
}

- (void) showReadmePanel: (id) sender
{
    [[ReadmePanel readmePanel] showWindow: self];
}

- (void) blankCDRW: (id) sender
{
    [[BlankPanel sharedPanel] activate];
}


- (void) showBurnHelp: (id) sender
{
	NSBundle *mb = [NSBundle mainBundle];
	NSString *file = [mb pathForResource: @"Burn" ofType: @"help"]; 
 
	if (file) {
		[[NSWorkspace sharedWorkspace] openFile: file];
		return;
   	}
	NSBeep();
}

/** Display a progress window
 * 
 * This method is called when we receive a "DisplayWorkInProgress" notification.
 * Depending on the notification info, we either display or hide the window.
 * The notification must contain the info fields "Start" and "AppName".
 * "Start" is either "YES" or "NO" and tells us whether to start or stop the
 * animated window. "AppName" is a unique identifier for the sender. It will be
 * used as title for the animated window and as identifier to later on close
 * the correct window.
 */
- (void) displayWorkInProgress: (id) not
{
    BOOL start = [[[not userInfo] objectForKey: @"Start"] intValue];
    NSString *appname = [[not userInfo] objectForKey: @"AppName"];
    WorkInProgress *workInProgress = [worksInProgress objectForKey: appname];
 
    if (start && appname && !workInProgress) {
        NSString *string = [[not userInfo] objectForKey: @"DisplayString"];

        workInProgress = [WorkInProgress new];
        if (!workInProgress)
            return;

        [worksInProgress setObject: workInProgress forKey: appname];
        [workInProgress startAnimationWithString: string
                                         appName: appname];
        RELEASE(workInProgress);
    }

    if (!start && appname && workInProgress) {
        [workInProgress stopAnimation];
        [worksInProgress removeObjectForKey: appname];
    }
}


//
// access methods
//

- (NSArray *) allBundles
{
	return [externalTools allValues];
}

- (id) bundleForKey: (id) key
{
	return [externalTools objectForKey: key];
}

- (id) currentWriterBundle
{
    NSDictionary *tools = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"SelectedTools"];
    if (nil != tools) {
        NSString *bundleName = [tools objectForKey: @"BurnSW"];
        if ((nil != bundleName) && ![bundleName isEqualToString: @""]) {
            return [self bundleForKey: bundleName];
        }
    }
    // If we get here, no bundle has been selected, yet, by the user.
    // Return the first one from the dictionary.
    NSEnumerator *e = [externalTools objectEnumerator];
    id o;
    while (nil != (o = [e nextObject])) {
        if ([[o class] conformsToProtocol: @protocol(Burner)]) {
            return o;
        }
    }
    // Nothing found
    return nil;
}

- (id) currentMkisofsBundle
{
    NSDictionary *tools = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"SelectedTools"];
    if (nil != tools) {
        NSString *bundleName = [tools objectForKey: @"ISOSW"];
        if ((nil != bundleName) && ![bundleName isEqualToString: @""]) {
            return [self bundleForKey: bundleName];
        }
    }
    // If we get here, no bundle has been selected, yet, by the user.
    // Return the first one from the dictionary.
    NSEnumerator *e = [externalTools objectEnumerator];
    id o;
    while (nil != (o = [e nextObject])) {
        if ([[o class] conformsToProtocol: @protocol(IsoImageCreator)]) {
            return o;
        }
    }
    // Nothing found
    return nil;
}

- (id) currentCDGrabberBundle
{
    // Return the first one from the dictionary.
    NSEnumerator *e = [externalTools objectEnumerator];
    id o;
    while (nil != (o = [e nextObject])) {
        if ([[o class] conformsToProtocol: @protocol(AudioConverter)]
                && ([(id<AudioConverter>)o isCDGrabber] == YES)) {
            return o;
        }
    }
    // Nothing found
    return nil;
}

- (id) currentAudioConverterBundle
{
    // Return the first one from the dictionary.
    NSEnumerator *e = [externalTools objectEnumerator];
    id o;
    while (nil != (o = [e nextObject])) {
        if ([[o class] conformsToProtocol: @protocol(AudioConverter)]
                && ([(id<AudioConverter>)o isCDGrabber] == NO)) {
            return o;
        }
    }
    // Nothing found
    return nil;
}

- (NSString *) currentDevice
{
    NSDictionary *tools = [[NSUserDefaults standardUserDefaults] dictionaryForKey: @"SelectedTools"];
    if (nil != tools) {
        NSString *name = [tools objectForKey: @"BurnDevice"];
        if ((nil != name) && ![name isEqualToString: @""]) {
            return name;
        }
    }

    id bundle = [self currentWriterBundle];
    if (nil != bundle) {
        NSArray *a = [bundle availableDrives];
        if (1 <= [a count]) {
            return [a objectAtIndex: 0];
        }
    }
    // Nothing found
    return NOT_FOUND;
}

- (NSArray *) allProjectWindows
{
	return allProjectWindows;
}

- (NSString *) currentWorkingPath
{
	return currentWorkingPath;
}

- (void) setCurrentWorkingPath: (NSString *) thePath
{
	RETAIN(thePath);
	RELEASE(currentWorkingPath);
	currentWorkingPath = thePath;
}

- (BOOL) lockBurner
{
	[burnerLock lock];
	if (burnerInUse) {
		[burnerLock unlock];
		return NO;
	}

	burnerInUse = YES;
	[[NSNotificationCenter defaultCenter]
				postNotificationName: BurnerInUse
				object: nil
				userInfo: [NSDictionary dictionaryWithObject: @"YES" forKey: @"InUse"]];
	[burnerLock unlock];
	return YES;
}

- (void) unlockBurner
{
	[burnerLock lock];
	burnerInUse = NO;
	[[NSNotificationCenter defaultCenter]
				postNotificationName: BurnerInUse
				object: nil
				userInfo: [NSDictionary dictionaryWithObject: @"NO" forKey: @"InUse"]];
	[burnerLock unlock];
}

- (BOOL) burnerInUse
{
	return burnerInUse;
}


//
// other methods
//

- (void) createMenu
{
	int i;
	NSMenu *menu;
	NSMenu *project;
	NSMenu *info;
	NSMenu *edit;
	NSMenu *inspectors;
	NSMenu *tools;
	NSMenu *services;
	NSMenu *windows;
	id<NSMenuItem> menuItem;
	NSArray *recentDocs;

	SEL action = @selector(method:);

	menu = AUTORELEASE([NSMenu new]);

	/* Info
	 *		-> Info Panel...
	 *		-> Preferences
	 *		-> Help
	 */
	menuItem = [menu addItemWithTitle:_(@"Info")
		action: action
		keyEquivalent:@""];

	info = AUTORELEASE([NSMenu new]);
	[menu setSubmenu:info forItem: menuItem];
	[info addItemWithTitle:_(@"AppController.infoItem") 
		action:@selector(orderFrontStandardInfoPanel:)
		keyEquivalent:@""];
	[info addItemWithTitle:_(@"AppController.prefsItem") 
		action:@selector(showPrefPanel:)
		keyEquivalent:@""];
	[info addItemWithTitle:_(@"AppController.readmeItem")
		action: @selector (showReadmePanel:)
		keyEquivalent:@""];
	[info addItemWithTitle:_(@"AppController.helpItem")
		action: @selector (showBurnHelp:)
		keyEquivalent:@"?"];

	/* CD Compilation
	 *		-> Open
	 *		-> New
	 *		-> Save
	 *		-> Save As...
	 *		-> Close
	 *		-> Burn CD
	 *		-> Recent Files
	 *			-> Recent 1 ...
	 */
	menuItem = [menu addItemWithTitle:_(@"AppController.compilMenu")
		action: action
		keyEquivalent:@""];

	project = AUTORELEASE([NSMenu new]);
	[menu setSubmenu:project forItem: menuItem];
	[project addItemWithTitle:_(@"AppController.openItem") 
		action:@selector(openProject:) 
		keyEquivalent:@"o"];
	[project addItemWithTitle:_(@"AppController.newItem") 
		action:@selector(newProject:) 
		keyEquivalent:@"n"];
	[project addItemWithTitle:_(@"AppController.saveItem") 
		action:@selector(saveDocument:)
		keyEquivalent:@"s"];
	[project addItemWithTitle:_(@"AppController.saveAsItem") 
		action:@selector(saveDocumentAs:)
		keyEquivalent:@"S"];
	[project addItemWithTitle:_(@"AppController.burnCDItem") 
		action:@selector(runCDrecorder:)
		keyEquivalent:@"B"];
	[project addItemWithTitle:_(@"AppController.createISOItem") 
		action:@selector(createISOImage:)
		keyEquivalent:@""];
	recentDocs = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
	{
		NSMenu *recent;

		menuItem = [project addItemWithTitle:_(@"AppController.recentItem")
			action: action
			keyEquivalent: @""];

		recent = AUTORELEASE([NSMenu new]);
		[project setSubmenu: recent forItem: menuItem];

		[recent addItemWithTitle: _(@"AppController.clearItem")
			action: @selector(clearRecentDocuments:)
			keyEquivalent: @""];

		for (i = 0; i < [recentDocs count]; i++) {
			if ([[[recentDocs objectAtIndex: i] path] length]) {
				[recent addItemWithTitle: [[recentDocs objectAtIndex: i] path]
									action: @selector(openRecentDoc:)
							keyEquivalent:@""];
			}
		}
	}

	/* Edit
	 *		-> Cut
	 *		-> Copy
	 *		-> Paste
	 *		-> Delete
	 */
	menuItem = [menu addItemWithTitle:_(@"AppController.editMenu")
		action: action
		keyEquivalent:@""];

	edit=AUTORELEASE([NSMenu new]);
	[menu setSubmenu: edit forItem: menuItem];
	[edit addItemWithTitle: _(@"AppController.cutItem")
		action: @selector(cut:)
		keyEquivalent: @"x"];
	[edit addItemWithTitle: _(@"AppController.copyItem")
		action: @selector(copy:)
		keyEquivalent: @"c"];
	[edit addItemWithTitle: _(@"AppController.pasteItem")
		action: @selector(paste:)
		keyEquivalent: @"v"];
	[edit addItemWithTitle: _(@"AppController.deleteItem")
		action: @selector(deleteFile:)
		keyEquivalent: @"d"];

	/* Tools
	 *      -> Inspectors
	 *		      -> Track
	 *		      -> Media
	 *		      -> Audio CDs
     *      -> Burn ISO Image
	 *		-> Blank CD-RW
	 *		-> Console
	 */
	menuItem = [menu addItemWithTitle:_(@"AppController.toolsMenu")
		action:action
		keyEquivalent:@""];

	tools = AUTORELEASE([NSMenu new]);
	[menu setSubmenu:tools forItem: menuItem];

	menuItem = [tools addItemWithTitle:_(@"AppController.inspMenu")
		action: action
		keyEquivalent: @""];

	inspectors = AUTORELEASE([NSMenu new]);
	[tools setSubmenu: inspectors forItem: menuItem];

	[inspectors addItemWithTitle:_(@"TrackInspector.name")
		action: @selector(showInspector:)
		keyEquivalent: @"1"];
	[inspectors addItemWithTitle:_(@"MediaInspector.name")
		action: @selector(showInspector:)
		keyEquivalent: @"2"];
	[inspectors addItemWithTitle:_(@"AudioCDInspector.name")
		action: @selector(showInspector:)
		keyEquivalent: @"3"];

	[tools addItemWithTitle:_(@"AppController.burnISOItem")
		action: @selector(burnISOImage:)
		keyEquivalent: @""];

	[tools addItemWithTitle:_(@"AppController.blankItem")
		action: @selector(blankCDRW:)
		keyEquivalent: @""];

	[tools addItemWithTitle:_(@"AppController.consoleItem")
		action:@selector(showConsole:)
		keyEquivalent:@""];

	/* Windows
	 *		-> Arrange
	 *		-> Miniaturize
	 *		-> Close
	 */
	menuItem = [menu addItemWithTitle:_(@"Common.windows")
		action:action
		keyEquivalent:@""];

	windows = AUTORELEASE([NSMenu new]);
	[menu setSubmenu:windows forItem: menuItem];
	[windows addItemWithTitle:_(@"AppController.arrange")
		action:@selector(arrangeInFront:)
		keyEquivalent:@""];
	[windows addItemWithTitle:_(@"AppController.miniaturize")
		action:@selector(performMiniaturize:)
		keyEquivalent:@"m"];
	[windows addItemWithTitle:_(@"Common.close")
		action:@selector(performClose:)
		keyEquivalent:@"w"];

	/* Services
	 */
	menuItem = [menu addItemWithTitle:_(@"Common.services")
		action:action
		keyEquivalent:@""];

	services = AUTORELEASE([NSMenu new]);
	[menu setSubmenu:services forItem: menuItem];

	/* Burn.app
	 *		-> Hide
	 *		-> Quit
	 */
	[menu addItemWithTitle:_(@"Common.hide")
		action:@selector(hide:)
		keyEquivalent:@"h"];
	[menu addItemWithTitle:_(@"Common.quit")
		action:@selector(terminate:)
		keyEquivalent:@"q"];

	[NSApp setServicesMenu: services];
	[NSApp setWindowsMenu: windows];
	[NSApp setMainMenu: menu];
}


//
// services methods
//

- (void) newProject: (NSPasteboard *) pboard
		   userData: (NSString *) userData
			  error: (NSString **) error
{
	NSArray *types = [pboard types];
	ProjectWindowController *controller = nil;

	/*
	 * Do we have at least one valid pasteboard type?
	 */
	if (![types containsObject: NSFilenamesPboardType] &&
		![types containsObject: AudioCDPboardType]) {
        *error = _(@"AppController.noValidType");
        return;

    }

	controller = [lastProjectWindowOnTop delegate];

	/*
	 * We open a new compilation and add the files/tracks.
     * We do this if either no compilation window exists or if the top most
     * window is already populated.
	 */
    if (!lastProjectWindowOnTop || [controller totalTime])
        [self newProject: self];

    [self addToProject: pboard userData: userData error: error];
}

- (void) addToProject: (NSPasteboard *) pboard
			 userData: (NSString *) userData
				error: (NSString **) error
{
	ProjectWindowController *controller = nil;
	NSArray *types = [pboard types];

	/*
	 * Do we have at least one valid pasteboard type?
	 */
	if (![types containsObject: NSFilenamesPboardType] &&
		![types containsObject: AudioCDPboardType]) {
        *error = _(@"AppController.noValidType");
        return;

    }

	/*
	 * check whether we have a top project window and whether
	 * it is of the correct class
	 */
	if (!lastProjectWindowOnTop) {
		/*
		 * If it is not, we open a new compilation and
		 * add the files/tracks.
		 */
		[self newProject: self];
	}

	controller = [lastProjectWindowOnTop delegate];

	/*
	 * Try to add as much as possible, i.e. even if one pasteboard
	 * type fails try the other one (if it exists in the pasteboard).
	 */
	if ([types containsObject: NSFilenamesPboardType] &&
		![controller acceptFilenames: pboard byOperation: NSDragOperationPrivate
							forIndex: -1 andItem: nil]) {
		*error = _(@"AppController.couldNotAddFiles");
	}
	if ([types containsObject: AudioCDPboardType] &&
		![controller acceptAudioCDTracks: pboard
							forIndex: -1 andItem: nil]) {
		*error = _(@"AppController.couldNotAddTracks");
	}
}


//
// Method used to load all bundles in $GNUSTEP_USER_ROOT/Library/Burn
//
- (void) loadTools
{
	NSFileManager *fileMan;
	NSString *libPath;
	NSArray *allFiles;
	NSArray	*searchPaths;
	NSBundle *bundle;
	int i, j;

	fileMan = [NSFileManager defaultManager];

	searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
							NSUserDomainMask|NSLocalDomainMask|NSSystemDomainMask, YES);

	for (j = 0; j < [searchPaths count]; j++) {
		libPath = [NSString stringWithFormat: @"%@/Bundles", [searchPaths objectAtIndex: j]];

		logToConsole(MessageStatusInfo, [NSString stringWithFormat:
											_(@"AppController.checkBundles"),
											libPath]);

		allFiles = [fileMan directoryContentsAtPath: libPath];

		for (i = 0; i < [allFiles count]; i++) {
            NSString *file = [allFiles objectAtIndex: i];
 
			// If we found a bundle, let's load it!
			if ([[file pathExtension] isEqualToString: @"burntool"]) {
                NSString *path = [NSString stringWithFormat: @"%@/%@",
											libPath, file];

				bundle = [NSBundle bundleWithPath: path];

				if (bundle) {
					id<BurnTool> module = nil;
					Class class = [bundle principalClass];

					if ([class conformsToProtocol: @protocol(BurnTool)] &&
                            ([class conformsToProtocol: @protocol(AudioConverter)] ||
							 [class conformsToProtocol: @protocol(Burner)] ||
							 [class conformsToProtocol: @protocol(IsoImageCreator)])) {
						module = [class singleInstance];

						if (module) {
							[externalTools setObject: module forKey: [module name]];

							logToConsole(MessageStatusInfo, [NSString stringWithFormat: _(@"AppController.loadBundle"),
											    path]);
						} else {
							logToConsole(MessageStatusError, [NSString stringWithFormat: _(@"Common.loadBundleFail"),
											    path]);
						}
					} else {
					}
				}
			}
		}
	}
}


- (BOOL) burnIsoImage: (NSString *) imageFile
{
    int rc = NSOKButton;
    BurnProgressController *bpcPanel;

    ParametersWindowController *paramsPanel;

    paramsPanel = [[ParametersWindowController alloc]
                    initWithWindowNibName: @"ParametersWindow"];

    [[NSNotificationCenter defaultCenter]
                postNotificationName: AlwaysKeepISOImages
                              object: nil
                            userInfo: nil];

    rc = [NSApp runModalForWindow: [paramsPanel window]];

    [[paramsPanel window] performClose: self];
    [paramsPanel release];

    if (rc != NSOKButton)
        return NO;

    logToConsole(MessageStatusInfo, [NSString stringWithFormat:
                                                @"Start burning ISO image %@.",
                                                imageFile]);
    bpcPanel = [[BurnProgressController alloc] initWithIsoImage: imageFile];

    if (bpcPanel != nil) {
        [[bpcPanel window] makeKeyAndOrderFront: self];
        [bpcPanel startProcess];
        /* If we get here we are finished. */
        return YES;
    }

    return NO;
}

- (void) addProjectWindow: (id) theProjectWindow
{
	if (allProjectWindows && theProjectWindow) {
		[allProjectWindows addObject: theProjectWindow];
	}
}

- (void) removeProjectWindow: (id) theProjectWindow
{
	if (allProjectWindows && theProjectWindow) {
		[allProjectWindows removeObject: theProjectWindow];
	}
	if (![allProjectWindows count]) {
	    NSDictionary *parameters =
			[[NSUserDefaults standardUserDefaults] objectForKey: @"GeneralParameters"];

		lastProjectWindowOnTop = nil;

		// inform the audio CD panel that the last window went away
		[[NSNotificationCenter defaultCenter]
			postNotificationName: AudioCDMessage
			object: nil
			userInfo: nil];

		// tell the track inspector
		[[NSNotificationCenter defaultCenter]
			postNotificationName: TrackSelectionChanged
			object: nil
			userInfo: nil];

	    if ([[parameters objectForKey: @"CloseOnLastWindow"] boolValue]) {
            [NSApp terminate: self];
        }
	}
}

- (id) lastProjectWindowOnTop
{ 
	return lastProjectWindowOnTop;
}


- (void) setLastProjectWindowOnTop: (id) aWindow
{
	lastProjectWindowOnTop = aWindow;
}

@end
