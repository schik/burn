/* vim: set ft=objc ts=4 nowrap: */
/*
**  Constants.h
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

#ifndef CONSTANTS_H_INC
#define CONSTANTS_H_INC

#include <Foundation/NSString.h>

// GSrecorder.app version number string
extern NSString *GSR_VERSION;
extern NSString *APP_NAME;

// Contants for the whole application
extern NSString *NOT_FOUND;

extern const double CDLength74;
extern const double CDLength80;
extern const double CDLength90;
extern const double CDLength100;

extern const long BytesPerFrame;
extern const long FramesPerSecond;

// Contants for the UI
extern const int TextFieldHeight;
extern const int ButtonHeight;
extern const int FilterTextFieldTag;

// Constants for the console window
extern NSString *MessageStatusToolOutput;
extern NSString *MessageStatusInfo;
extern NSString *MessageStatusWarning;
extern NSString *MessageStatusError;

// Notifications used in GSburn.app
extern NSString *AudioCDMessage;
extern NSString *ExternalToolOutput;
extern NSString *ToolChanged;
extern NSString *BurnerInUse;
extern NSString *TrackSelectionChanged;
extern NSString *DisplayWorkInProgress;
extern NSString *AlwaysKeepISOImages;

// Pasteboard data types
extern NSString *AudioCDPboardType;
extern NSString *BurnTrackPboardType;


#endif
