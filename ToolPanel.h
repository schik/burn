/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#ifndef TOOLPANEL_H_INC
#define TOOLPANEL_H_INC

#include <AppKit/AppKit.h>

#include <Burn/PreferencesModule.h>

@interface ToolPanel : NSObject <PreferencesModule>
{
  id panel;
  id view;
  id burnToolPopUp;
  id isoToolPopUp;
  id toolTable;
}

- (id) init;

- (void) toolChanged: (id) sender;

//
// class methods
//

@end


#endif
