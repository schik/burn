/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/* All Rights reserved */

#ifndef CREATEISOPARAMETERSVIEW_H_INC
#define CREATEISOPARAMETERSVIEW_H_INC

#include <AppKit/AppKit.h>

#include "PreferencesModule.h"

@interface CreateIsoParametersView : NSObject <PreferencesModule>
{
  id rockRidgeCheckBox;
  id jolietCheckBox;
  id isoLevelPopUp;
  id window;
  id view;
}

- (id) init;

@end

#endif
