/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  ParametersWindowController.h
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef PARAMETERSWINDOWCONTROLLER_H_INC
#define PARAMETERSWINDOWCONTROLLER_H_INC

#include <AppKit/AppKit.h>
#include "Burn/PreferencesModule.h"

typedef enum {
    OperationModeCreateIso = 1,
    OperationModeBurnIso = 2,
    OperationModeBurnData = 4,
    OperationModeBurnAudio = 8,
    OperationModeBurnAll = 14,
    OperationModeAll = 0xffffffff
} OperationMode;



@interface ParametersWindowController: NSWindowController
{
	// Outlets
	IBOutlet NSMatrix *matrix;
	IBOutlet NSBox *box;
    IBOutlet id window;
    IBOutlet id okButton;
	
	// Other ivar
	NSMutableDictionary *allModules;
    OperationMode opMode;
}

- (id) initWithWindowNibName: (NSString *) windowNibName
               operationMode: (OperationMode) operationMode;

- (void) dealloc;


//
// action methods
//
- (void) handleCellAction: (id) sender;
- (void) okClicked: (id) sender;


//
// other methods
//
- (void) saveParameters;
- (void) addModuleToView: (id <PreferencesModule>) aModule;

//
// access/mutation methods
//

//
// class methods
//

@end

#endif
