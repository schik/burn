/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *	ProjectWindowController.m
 *
 *	Copyright (c) 2002-2008, 2011
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

#import <AppKit/NSToolbar.h>

#include "ProjectWindowController.h"
#include "AppController.h"
#include "Constants.h"
#include "Functions.h"
#include "Project.h"
#include "Inspectors/InspectorsWin.h"
#include "PreferencesWindowController.h"
#include "ParametersWindowController.h"
#include "OpenISOImagePanel.h"

#include <Burn/ExternalTools.h>


static NSString *AddDataButton = @"addDataButton";
static NSString *AddAudioButton = @"addAudioButton";
static NSString *RemoveButton = @"removeButton";
static NSString *CreateIsoButton = @"createIsoButton";
static NSString *BurnIsoButton = @"burnIsoButton";
static NSString *BurnButton = @"recordButton";
static NSString *BlankCDButton = @"blankCdButton";

@interface ProjectWindowController (Private)
- (void) wakeUpMainThreadRunloop: (id) arg;
- (void) enableButtons;
@end

@implementation ProjectWindowController (Private)

/**
 * This method is expected to be tun on the main thread to
 * indicate the end of the worker thread. Each worker thread
 * method must schedule this method to perform on main thread
 * before it exists. Otherwise, the end of the thread will not
 * be detected!
 */
- (void) wakeUpMainThreadRunloop: (id) arg
{
    workerThreadRunning = NO;
}

/**
 * Enables/disables the toolbar buttons.
 */
- (void) enableButtons
{
    int audioRow = [trackView rowForItem: audioRoot];
    int dataRow = [trackView rowForItem: dataRoot];
    int cdRow = [trackView rowForItem: cdRoot];
    int selRow = [trackView selectedRow];
    int numSelRows = [trackView numberOfSelectedRows];

    if ([[AppController appController] burnerInUse]
            || (YES == workerThreadRunning)) {
        // when modifying the compilation or burning disable whole tool bar
	    [addDataButton setEnabled: NO];
	    [addAudioButton setEnabled: NO];
	    [removeButton setEnabled: NO];
        [recordButton setEnabled: NO];
        [blankCdButton setEnabled: NO];
        [createIsoButton setEnabled: NO];
        [burnIsoButton setEnabled: NO];
        return;
    }
    if ([[self document] numberOfTracks] <= 0) {
	    [removeButton setEnabled: NO];
        [recordButton setEnabled: NO];
        [createIsoButton setEnabled: NO];
    } else {
        [recordButton setEnabled: YES];
        [createIsoButton setEnabled: YES];

        if ((numSelRows == 0)
               || ((numSelRows == 1)
                   && ((selRow == audioRow) || (selRow == dataRow) || (selRow == cdRow)))) {
            [removeButton setEnabled: NO];
        } else {
            [removeButton setEnabled: YES];
        }
    }
    [blankCdButton setEnabled: YES];
    [burnIsoButton setEnabled: YES];
    [addDataButton setEnabled: YES];
    [addAudioButton setEnabled: YES];
}

@end


@implementation ProjectWindowController

/**
 * Initialize the class.
 */ 
+ (void) initialize
{
    static BOOL initialized = NO;

    /* Make sure code only gets executed once. */
    if (initialized == YES)
        return;
    initialized = YES;

    [NSApp registerServicesMenuSendTypes: nil
                    returnTypes: [NSArray arrayWithObjects: AudioCDPboardType, nil]];
}


- (id) init
{
    [self initWithWindowNibName: @"ProjectWindow"];
    return self;
}

- (id) initWithWindowNibName: (NSString *) windowNibName
{
    self = [super initWithWindowNibName: windowNibName];

    // we do this as early as possible, since this data
    // is need when trackView is reloaded. and you never know when ...
    audioRoot = @"audio";
    dataRoot = @"data";
    cdRoot = @"cd";
    workerThreadRunning = NO;

    // We set our autosave window frame name and restore the one from the user's defaults.
    [[self window] setFrameAutosaveName: @"ProjectWindow"];
    [[self window] setFrameUsingName: @"ProjectWindow"];
    [progress setAnimationDelay: 1./6.];
    [progress setHidden: YES];
    [progressLabel setHidden: YES];
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                            name: BurnerInUse
                            object: nil];

    [super dealloc];
}

/**
 * Creates one toolbar button.
 */
- (NSToolbarItem *) toolbarButtonWithIdentifier: (NSString *) identifier
                                          title: (NSString *) title
                                       selector: (SEL) selector
                                      imageName: (NSString *) imageName
{
    NSToolbarItem *toolbarButton;

    toolbarButton = [[NSToolbarItem alloc] initWithItemIdentifier: identifier];
    [toolbarButton setImage: [NSImage imageNamed: imageName]];
    if (title) {
        [toolbarButton setLabel: title];
        [toolbarButton setPaletteLabel: title];
        [toolbarButton setToolTip: title];
    }
    [toolbarButton setTarget: self];
    [toolbarButton setAction: selector];

    return toolbarButton;
}

/**
 * Initializes the set of toolbar buttons.
 */
- (void) initToolbarButtons
{
    addDataButton = [self toolbarButtonWithIdentifier: AddDataButton
                    title: _(@"Add Files...")
                    selector: @selector(addFiles:)
                    imageName: @"iconAddFiles"];
    addAudioButton = [self toolbarButtonWithIdentifier: AddAudioButton
                    title: _(@"Add Audio Tracks...")
                    selector: @selector(addAudioTracks:)
                    imageName: @"iconAddAudioTracks"];
    removeButton = [self toolbarButtonWithIdentifier: RemoveButton
                       title: _(@"Remove Selection")
                       selector: @selector(deleteFile:)
                       imageName: @"iconRemoveTracks"];
    createIsoButton = [self toolbarButtonWithIdentifier: CreateIsoButton
                          title: _(@"Create ISO Image")
                          selector: @selector(createISOImage:)
                          imageName: @"iconCreateIso"];
    burnIsoButton = [self toolbarButtonWithIdentifier: BurnIsoButton
                          title: _(@"Burn ISO Image")
                          selector: @selector(burnISOImage:)
                          imageName: @"iconBurnIso"];
    recordButton = [self toolbarButtonWithIdentifier: BurnButton
                     title: _(@"Burn")
                     selector: @selector(runCDrecorder:)
                     imageName: @"iconBurn"];
    blankCdButton = [self toolbarButtonWithIdentifier: BlankCDButton
                     title: _(@"AppController.blankItem")
                     selector: @selector(blankCDRW:)
                     imageName: @"iconBlankCD"];
}

/**
 * Creates the toolbar as such
 */
- (void) createToolbar
{
    NSToolbar *toolbar;

    [self initToolbarButtons];

    toolbar = [[NSToolbar alloc] initWithIdentifier: @"ProjectToolbar"];
    [toolbar autorelease];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    [toolbar setSizeMode: NSToolbarSizeModeDefault];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: YES];

    [[self window] setToolbar: toolbar];
}


//
// action methods
//

- (BOOL) validateMenuItem: (NSMenuItem*) item
{
    SEL	action = [item action];
    int audioRow = [trackView rowForItem: audioRoot];
    int dataRow = [trackView rowForItem: dataRoot];
    int cdRow = [trackView rowForItem: cdRoot];
    int selRow = [trackView selectedRow];
    int numSelRows = [trackView numberOfSelectedRows];

    if ([[AppController appController] burnerInUse]
            || (YES == workerThreadRunning)) {
        if (sel_isEqual(action, @selector(addFiles:)))
            return NO;
        if (sel_isEqual(action, @selector(addAudioTracks:)))
            return NO;
        if (sel_isEqual(action, @selector(deleteFile:)))
            return NO;
        if (sel_isEqual(action, @selector(runCDrecorder:)))
            return NO;
        if (sel_isEqual(action, @selector(createISOImage:)))
            return NO;
        if (sel_isEqual(action, @selector(burnISOImage:)))
            return NO;
        if (sel_isEqual(action, @selector(cut:)))
            return NO;
        if (sel_isEqual(action, @selector(copy:)))
            return NO;
        if (sel_isEqual(action, @selector(paste:)))
            return NO;
    }

    if ([[self document] numberOfTracks] <= 0) {
        if (sel_isEqual(action, @selector(deleteFile:)))
            return NO;
        if (sel_isEqual(action, @selector(runCDrecorder:)))
            return NO;
        if (sel_isEqual(action, @selector(createISOImage:)))
            return NO;
    }

    if (sel_isEqual(action, @selector(deleteFile:))
            || sel_isEqual(action, @selector(cut:))
            || sel_isEqual(action, @selector(copy:))) {
        if ((numSelRows == 0)
               || ((numSelRows == 1)
                   && ((selRow == audioRow) || (selRow == dataRow) || (selRow == cdRow)))) {
            return NO;
        }
    }

    return YES;
}

- (void) runInThread: (SEL) selector
              target: (id) target
            userData: (id) data
             message: (NSString *) message
{
    workerThreadRunning = YES;

    [self enableButtons];
    [progressLabel setStringValue: message];
    [progressLabel setHidden: NO];
    [progress setHidden: NO];
    [progress startAnimation: self];

    [NSThread detachNewThreadSelector: selector
                             toTarget: target
                           withObject: data];

    while (workerThreadRunning) {
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                 beforeDate: [NSDate distantFuture]];
    }

    // stop progress animation
    [progressLabel setHidden: YES];
    [progress setHidden: YES];
    [progress stopAnimation: self];

    [self enableButtons];
}

- (BOOL) addFiles: (NSArray *) files
           ofType: (int) type
          atIndex: (int) index
        recursive: (BOOL) recursive
{
    BOOL success = YES;
    NSString *message;
    if (type == TrackTypeData) {
        message = _(@"ProjectWindowController.addingFiles");
    } else {
        message = _(@"ProjectWindowController.addingAudio");
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                files, @"fileNames",
                                [NSNumber numberWithInt: type], @"trackType",
                                [NSNumber numberWithInt: index], @"index",
                                [NSNumber numberWithBool: recursive], @"recursive",
                                nil];
    RETAIN(dict);

    [self runInThread: @selector(addTracksThread:)
               target: self
             userData: dict
              message: message];
    success = [(NSNumber *)[dict objectForKey: @"returnValue"] boolValue];
    RELEASE(dict);

    [self expandAllItems];
    [self updateWindow];
    return success;
}

- (void) addTracksThread: (id) data
{
    NSMutableDictionary *dict = RETAIN((NSMutableDictionary *)data);

    NSArray *fileNames = (NSArray *)[dict objectForKey: @"fileNames"];
    int trackType = [(NSNumber *)[dict objectForKey: @"trackType"] intValue];
    int index = [(NSNumber *)[dict objectForKey: @"index"] intValue];
    BOOL recursive = [(NSNumber *)[dict objectForKey: @"recursive"] boolValue];

    // Add files and folders
    NSFileManager *fileMan = [NSFileManager defaultManager];

    int count = [fileNames count];
    int i;
	BOOL success = YES;

    id pool = [NSAutoreleasePool new];

    for (i = count - 1; (i >= 0) && (YES == success); i--) {
        BOOL isDir;
        NSString *sourceFile = [fileNames objectAtIndex: i];
        // Is the current file a directory?
        if ([fileMan fileExistsAtPath: sourceFile isDirectory: &isDir] && isDir) {
            if (YES == recursive) {
                success = [[self document] insertTracksFromDirectory: sourceFile
                                                              asType: trackType
                                                          atPosition: index
                                                           recursive: NO];
            } else {
                success = [[self document] insertTrackFromFile: sourceFile
                                                        asType: trackType
                                                    atPosition: index];
            }
            if (NO == success) {
                logToConsole(MessageStatusError, [NSString stringWithFormat:
                                    _(@"ProjectWindowController.addDirFail"), sourceFile]);

            }
        } else {
            // simply add the file as the appropriate type
            if ([[self document] insertTrackFromFile: sourceFile
                                              asType: trackType
                                          atPosition: index] == NO) {
                logToConsole(MessageStatusError, [NSString stringWithFormat:
                                _(@"ProjectWindowController.addFileFail"), sourceFile]);
            }
        }
    }
    [dict setObject: [NSNumber numberWithBool: success] forKey: @"returnValue"];

    [self performSelectorOnMainThread: @selector(wakeUpMainThreadRunloop:)
                           withObject: nil
                        waitUntilDone: NO];
    RELEASE(dict);
    RELEASE(pool);
}

- (void) addAudioCDTracksThread: (id) data
{
    NSMutableDictionary *dict = RETAIN((NSMutableDictionary *)data);

	NSDictionary *cds = (NSDictionary *)[dict objectForKey: @"cds"];
    int index = [(NSNumber *)[dict objectForKey: @"index"] intValue];
    NSArray *cddbIds = nil;
	int i, count;
	BOOL success = YES;

    id pool = [NSAutoreleasePool new];

	cddbIds = [cds allKeys];
	count = [cddbIds count];

	for (i = count - 1; i >= 0; i--) {
		NSDictionary *cd;
		NSString *cddbId = [cddbIds objectAtIndex: i];

		cd = [cds objectForKey: cddbId];

		if ([[self document] addCD: cd withID: cddbId atPosition: index] == NO) {
			logToConsole(MessageStatusError, [NSString stringWithFormat:
										_(@"ProjectWindowController.addCDFail"), cddbId]);
            success = NO;
		}
	}

    [dict setObject: [NSNumber numberWithBool: success] forKey: @"returnValue"];

    [self performSelectorOnMainThread: @selector(wakeUpMainThreadRunloop:)
                           withObject: nil
                        waitUntilDone: NO];
    RELEASE(dict);
    RELEASE(pool);
}


/**
 * Opens a file selection dialog and adds the selected
 * files and folders to the track list.
 */
- (void) addFiles: (id)sender
{
    NSOpenPanel *openPanel;
    NSString *openDir;
    int rc;

    openDir = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSDefaultOpenDirectory"];

    openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection: YES];
    [openPanel setCanChooseDirectories: YES];
    [openPanel setTitle: _(@"ProjectWindowController.addFilesTitle")];
    [openPanel setDirectory: openDir];
	rc = [openPanel runModalForDirectory: openDir file: nil types: nil];
	if (rc == NSOKButton) {
        // Save last directory
        NSUserDefaults *userDefaults;
        userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject: [openPanel directory]
                         forKey: @"NSDefaultOpenDirectory"];
        [userDefaults synchronize];
  
        [self addFiles: [openPanel filenames]
                ofType: TrackTypeData
               atIndex: [[self document] numberOfDataTracks]
             recursive: NO];
    }
}

/**
 * Opens a file selection dialog and adds the selected
 * files and folders to the track list.
 */
- (void) addAudioTracks: (id)sender
{
    NSOpenPanel *openPanel;
    NSString *openDir;
    NSMutableArray *types;
    int rc;

    openDir = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSDefaultOpenDirectory"];

    openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection: YES];
    [openPanel setCanChooseDirectories: NO];
    [openPanel setTitle: _(@"Add audio files...")];
    [openPanel setDirectory: openDir];
    // We only search for .wav, .au and the registered audio types
	types = [[[AppController appController] registeredFileTypes] mutableCopy];
	[types addObject: @"wav"];
	[types addObject: @"au"];

	rc = [openPanel runModalForDirectory: openDir file: nil types: types];
	if (rc == NSOKButton) {
        // Save last directory
        NSUserDefaults *userDefaults;
        userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject: [openPanel directory]
                         forKey: @"NSDefaultOpenDirectory"];
        [userDefaults synchronize];
  
        [self addFiles: [openPanel filenames]
                ofType: TrackTypeAudio
               atIndex: [[self document] numberOfAudioTracks]
             recursive: NO];
    }
}

- (void) deleteFile: (id)sender
{
    int i;
    int audioRow = [trackView rowForItem: audioRoot];
    int dataRow = [trackView rowForItem: dataRoot];
    int cdRow = [trackView rowForItem: cdRoot];
    int selRow = [trackView selectedRow];
    int numSelRows = [trackView numberOfSelectedRows];

    if ((numSelRows == 0) ||
            ((numSelRows == 1) &&
            ((selRow == audioRow) || (selRow == dataRow) || (selRow == cdRow)))) {
        NSBeep();
        return;
    }

    for (i = [[self document] numberOfAudioTracks]-1; i >= 0; i--) {
        if ([trackView isRowSelected: audioRow+i+1]){	// add 1 because of parent in outline view
            [[self document] deleteTrackOfType: TrackTypeAudio atIndex: i];
        }
    }

    for (i = [[self document] numberOfDataTracks]-1; i >= 0; i--) {
        if ([trackView isRowSelected: dataRow+i+1]){	// add 1 because of parent in outline view
            [[self document] deleteTrackOfType: TrackTypeData atIndex: i];
        }
    }

    [self updateWindow];
    [trackView deselectAll: self];

    // update the audio CD panel
    if ([[self window] isKeyWindow]) {
        [self updateAudioCDPanel];
        [self updateTrackInspector];
    }

    return;
}


- (void) runCDrecorder: (id) sender
{
    [self createCD: NO];
}

- (void) burnISOImage: (id) sender
{
	OpenISOImagePanel *openPanel;
	int rc;
    /*
     * Retrieve the path to the last opened ISO image file.
     */
    NSString *imageFile = [[NSUserDefaults standardUserDefaults] objectForKey: @"LastImage"];
    NSString *fileName = [imageFile lastPathComponent];
    NSString *dirName = [imageFile stringByDeletingLastPathComponent];

    openPanel = [OpenISOImagePanel openISOImagePanel];

    if (![dirName length])
        dirName = [[AppController appController] currentWorkingPath];

    /*
     * Open the image chooser panel. If the user says so, we open the parameters
     * panel after closing the chooser with 'OK'.
     */
	rc = [openPanel runModalForDirectory: dirName file: fileName types: nil];
	if (rc == NSOKButton) {
        imageFile = [[openPanel filenames] objectAtIndex: 0];

        /*
         * Save the last selected ISO image file.
         */
        [[NSUserDefaults standardUserDefaults] setObject: imageFile forKey: @"LastImage"];

        [[AppController appController] burnIsoImage: imageFile];
    }
}


- (void) createISOImage: (id) sender
{
    [self createCD: YES];
}

- (void) createCD: (BOOL) isoOnly
{
    ParametersWindowController *paramsPanel;
    BOOL burn = YES;
    int rc;

    if ([[AppController appController] burnerInUse] ||
             [[self document] numberOfTracks] <= 0) {
        NSBeep();
        return;
    }

    paramsPanel = [[ParametersWindowController alloc]
                initWithWindowNibName: @"ParametersWindow"
                        operationMode: (YES == isoOnly) ? OperationModeCreateIso : OperationModeBurnAll];

    if (YES == isoOnly) {
        // don't delete the generated ISO file
        [[NSNotificationCenter defaultCenter]
                    postNotificationName: AlwaysKeepISOImages
                                  object: nil
                                userInfo: nil];
    }

    rc = [NSApp runModalForWindow: [paramsPanel window]];

    // If parameter entry gets cancelled, we stop here
    burn = rc == NSOKButton;

    [[paramsPanel window] performClose: self];
    [paramsPanel release];

    if (burn) {
        if (![[AppController appController] lockBurner]) {
            NSBeep();
            return;
        }

        [[self document] createCD: isoOnly];
    }
}

//
// document related methods
//

- (void) setDocument: (NSDocument *)document
{
    [super setDocument: document];

    /* and we need cdrecord to write it */
    [self updateWindow];

    if ([[self document] numberOfAudioTracks] > 0)
        [trackView expandItem: audioRoot];

    if ([[self document] numberOfDataTracks] > 0)
        [trackView expandItem: dataRoot];
}

- (void)saveDocument: (id)sender
{
    if ([[self document] isDocumentEdited] == YES) {
        [[self document] saveDocument: sender];
    }

    return;
}

- (void)saveDocumentAs: (id)sender
{
    [[self document] saveDocumentAs: sender];

    return;
}

- (void)saveDocumentTo: (id)sender
{
    [[self document] saveDocumentTo: sender];

    return;
}


- (void)burnerInUse: (id)sender
{
    [self updateWindow];
}



//
// delegate methods
//

- (void) outlineViewSelectionDidChange: (NSNotification *) not
{
    [self enableButtons];
    [self updateTrackInspector];
}


- (BOOL) windowShouldClose: (id) window
{
    // We remove our window from our list of opened windows
    [[AppController appController] removeProjectWindow: [self window]];

    // We update our last project window on top if it was the current selected one
    if ([[AppController appController] lastProjectWindowOnTop] == [self window]) {
        [[AppController appController] setLastProjectWindowOnTop: nil];
    }

    return YES;
}


- (void) awakeFromNib
{
	NSTableColumn *column;
    // We set the last window on top
    [[AppController appController] setLastProjectWindowOnTop: [self window]];

    [[NSNotificationCenter defaultCenter] addObserver: self
       selector: @selector(burnerInUse:)
       name: BurnerInUse
       object: nil];

    // We add our window to our list of opened windows
    [[AppController appController] addProjectWindow: [self window]];
    [self createToolbar];

    // Finalize the track outline view. This stuff cannot be
    // det by Gorm.
	[trackView setIndentationPerLevel: 10];
	[trackView setRowHeight: 20];
	[trackView setAutoresizesAllColumnsToFit: YES];
	[trackView setAutoresizesOutlineColumn: YES];
	[trackView setIndentationMarkerFollowsCell: YES];
	[trackView setVerticalMotionCanBeginDrag: NO];
	[trackView sizeLastColumnToFit];
	[trackView registerForDraggedTypes:
			 [NSArray arrayWithObjects: NSFilenamesPboardType,
										AudioCDPboardType,
										BurnTrackPboardType, nil]];

	column = [trackView tableColumnWithIdentifier: @"Track"];
	[[column headerCell] setStringValue: _(@"Common.track")];
	[column setMinWidth: 150];
	[column setWidth: 300];

	column = [trackView tableColumnWithIdentifier: @"Length"];
	[[column headerCell] setStringValue: _(@"Common.length")];
	[column setMinWidth: 90];
	[column setMaxWidth: 90];
}

- (void) windowDidBecomeKey: (NSNotification *) not
{
    // We set the last window on top
    [[AppController appController] setLastProjectWindowOnTop: [self window]];

    // update the audio CD panel
    [self updateAudioCDPanel];
 
    [self updateTrackInspector];
}

- (void) expandAllItems
{
    [trackView expandItem: cdRoot expandChildren: YES];
}

//
// NSToolbar delegate
//

/**
 * Returns the toolbar item for a certain identifier.
 */
- (NSToolbarItem *) toolbar: (NSToolbar *) toolbar
      itemForItemIdentifier: (NSString *) identifier
  willBeInsertedIntoToolbar: (BOOL) flag
{
    NSToolbarItem *item = nil;

    if ([identifier isEqualToString: AddDataButton])
        item = addDataButton;
    else if ([identifier isEqualToString: AddAudioButton])
        item = addAudioButton;
    else if ([identifier isEqualToString: RemoveButton])
        item = removeButton;
    else if ([identifier isEqualToString: CreateIsoButton])
        item = createIsoButton;
    else if ([identifier isEqualToString: BurnIsoButton])
        item = burnIsoButton;
    else if ([identifier isEqualToString: BurnButton])
        item = recordButton;
    else if ([identifier isEqualToString: BlankCDButton])
        item = blankCdButton;
    return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects: AddDataButton,
                  AddAudioButton,
                  RemoveButton,
                  CreateIsoButton,
                  BurnIsoButton,
                  BurnButton,
                  BlankCDButton,
                  NSToolbarCustomizeToolbarItemIdentifier, 
                  NSToolbarSpaceItemIdentifier,
                  NSToolbarFlexibleSpaceItemIdentifier,
                  NSToolbarSeparatorItemIdentifier,
                  nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects: AddDataButton,
                  AddAudioButton,
                  NSToolbarSpaceItemIdentifier,
                  BurnButton,
                  NSToolbarSpaceItemIdentifier,
                  BlankCDButton,
                  NSToolbarSpaceItemIdentifier,
                  NSToolbarCustomizeToolbarItemIdentifier, 
                  nil];
}


//
// access / mutation methods
//

- (long) totalTime
{
    return [(Project*)[self document] totalLength];
}

- (BOOL) workerThreadRunning
{
    return workerThreadRunning;
}

//
// Other methods
//

- (void) displayTotalTime
{
    long totalTime;		// Frames

    totalTime = [(Project*)[self document] totalLength];
    [totalLength setDoubleValue: (double)framesToSize((double)totalTime)];
}

- (void) updateWindow
{
    [trackView reloadData];

    [self displayTotalTime];
    [self enableButtons];
}

- (void) updateAudioCDPanel
{
    int i;
    NSArray *keys;
    NSMutableArray *allCDs = [NSMutableArray new];

    keys = [[self document] allCddbIds];
    for (i = 0; i < [keys count]; i++) {
        NSDictionary *orgCD = [[self document] cdForKey: [keys objectAtIndex: i]];
        NSDictionary *newCD = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [keys objectAtIndex: i], @"cddbId",
                                    [orgCD objectForKey: @"artist"], @"artist",
                                    [orgCD objectForKey: @"title"], @"title", nil];

        [allCDs addObject: newCD];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName: AudioCDMessage
        object: nil
        userInfo: [NSDictionary dictionaryWithObjectsAndKeys: allCDs, @"cds", nil]];
}

- (void) updateTrackInspector
{
    //
    // change data in track inspector if necessary
    int i;
    int audioRow = [trackView rowForItem: audioRoot];
    int dataRow = [trackView rowForItem: dataRoot];
    NSMutableArray *tracks = [NSMutableArray new];

    audioRow += 1;
    dataRow += 1;
    for (i = 0; i < [[self document] numberOfAudioTracks]; i++) {
        if ([trackView isRowSelected: audioRow+i])
            [tracks addObject: [[self document] trackOfType: TrackTypeAudio atIndex: i]];
    }
    for (i = 0; i < [[self document] numberOfDataTracks]; i++) {
        if ([trackView isRowSelected: dataRow+i])
            [tracks addObject: [[self document] trackOfType: TrackTypeData atIndex: i]];
    }
    [[NSNotificationCenter defaultCenter]
        postNotificationName: TrackSelectionChanged
        object: nil
        userInfo: [NSDictionary dictionaryWithObject: tracks forKey: @"Tracks"]];
    [tracks release];
}

@end

