/* vim: set ft=objc ts=4 nowrap: */
/* All Rights reserved */

#ifndef CDPARANOIAPARAMETERSVIEW_H_INC
#define CDPARANOIAPARAMETERSVIEW_H_INC

#include <AppKit/AppKit.h>

#include "PreferencesModule.h"

@interface CDparanoiaParametersView : NSObject <PreferencesModule>
{
	id disParanoiaCheckBox;
	id disXParanoiaCheckBox;
	id disRepairCheckBox;
	id view;
	id window;
}

- (id) init;

//
// action methods
//


@end

#endif
