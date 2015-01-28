/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/* All Rights reserved */

#ifndef MKISOFSPARAMETERSVIEW_H_INC
#define MKISOFSPARAMETERSVIEW_H_INC

#include <AppKit/AppKit.h>

#include "PreferencesModule.h"

@interface MkIsoFsParametersView : NSObject <PreferencesModule>
{
    id rockrCheckBox;
    id jolietCheckBox;
    id symlinkCheckBox;
    id nobakCheckBox;
    id longNameCheckBox;
    id dotStartCheckBox;
    id isoLevelPopUp;
    id imageNameTextField;

    id view;
    id window;
}

- (id) init;

//
// action methods
//

- (void) chooseImageClicked: (id) sender;


@end

#endif
