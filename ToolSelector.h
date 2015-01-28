/* All Rights reserved */

#include <AppKit/AppKit.h>

@interface ToolSelector : NSView
{
	NSView		  *toolView;
	NSScrollView  *scrollView;
	NSPopUpButton *burnToolPopUp;
	NSPopUpButton *isoToolPopUp;
	NSMutableArray *additionalPopUps;

	NSArray       *fileTypes;
}

- (NSPopUpButton *) burnToolPopUp;
- (NSPopUpButton *) isoToolPopUp;

- (void) getAvailableTools;
- (void) saveChanges: (NSMutableDictionary *) selectedTools;
- (void) setTarget: (id)target action: (SEL)action;

@end
