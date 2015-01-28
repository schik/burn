/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#ifndef MKISOFSSETTINGSVIEW_H_INC
#define MKISOFSSETTINGSVIEW_H_INC

#include <AppKit/AppKit.h>

#include "PreferencesModule.h"

@interface MkIsoFsSettingsView : NSObject <PreferencesModule>
{
  id programTextField;

  id view;
  id window;
}

- (id) init;

//
// action methods
//

- (void) chooseClicked: (id)sender;

@end

#endif
