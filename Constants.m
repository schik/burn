/* vim: set ft=objc ts=4 nowrap: */
/*
**  Constants.m
**
**  Copyright (c) 2002
** 
**  Author: Andreas Heppel <aheppel@web.de>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "Constants.h"

// GNUMail.app version number string
NSString *GSR_VERSION = @"0.3.0";
NSString *APP_NAME = @"Burn.app";

// Contants for the whole application
NSString *NOT_FOUND = @"NOT_FOUND";

const double CDLength74 = 74.;
const double CDLength80 = 80.;
const double CDLength90 = 90.;
const double CDLength100 = 100.;

const long BytesPerFrame = 2352;
const long FramesPerSecond = 75;

// Constants for the UI
const int TextFieldHeight = 21;
const int ButtonHeight = 25;
const int FilterTextFieldTag = 1001;

// Constants for the console window
NSString *MessageStatusToolOutput = @"MessageStatusToolOutput";
NSString *MessageStatusInfo = @"MessageStatusInfo";
NSString *MessageStatusWarning = @"MessageStatusWarning";
NSString *MessageStatusError = @"MessageStatusError";

// Notifications used in Burn.app
NSString *AudioCDMessage = @"AudioCDMessage";
NSString *ExternalToolOutput = @"ExternalToolOutput";
NSString *ToolChanged = @"ToolChanged";
NSString *BurnerInUse = @"BurnerInUse";
NSString *TrackSelectionChanged = @"TrackSelectionChanged";
NSString *DisplayWorkInProgress = @"DisplayWorkInProgress";
NSString *AlwaysKeepISOImages = @"AlwaysKeepISOImages";

// Dragged types for pasteboard
NSString *AudioCDPboardType = @"AudioCDPboardType";
NSString *BurnTrackPboardType = @"BurnTrackPboardType";
