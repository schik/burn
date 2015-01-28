/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/* All Rights reserved */

#ifndef CDPARANOIASETTINGSVIEW_H_INC
#define CDPARANOIASETTINGSVIEW_H_INC

#include <AppKit/AppKit.h>

#include "PreferencesModule.h"

@interface CDparanoiaSettingsView : NSObject <PreferencesModule>
{
  id programTextField;
  id view;
  id window;
}

- (id) init;

//
// action methods
//

- (void) chooseClicked: (id) sender;

@end

#endif
