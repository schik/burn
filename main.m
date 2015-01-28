/* vim: set ft=objc ts=4 et sw=4 nowrap: */
#include <AppKit/AppKit.h>
#include <AppKit/NSHelpManager.h>
#include "AppController.h"
#include "ProjectWindowController.h"

@interface BurnApplication : NSApplication
{
}
- (void) keyDown: (NSEvent *) theEvent;
@end

@implementation BurnApplication
- (void) keyDown: (NSEvent *) theEvent
{
	NSString *characters;
	unichar character;

	characters = [theEvent characters];
	character = 0;

	if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];

		switch (character) {
		case NSF1FunctionKey:
			[self activateContextHelpMode: self];
			return;
		case NSDeleteFunctionKey:
		case NSBackspaceCharacter:
		case NSDeleteCharacter:
			[[[[AppController appController] lastProjectWindowOnTop] delegate] deleteFile: self];
			return;
		}
	}
	[super keyDown: theEvent];
}
@end
/*
 * Initialise and go!
 */

int main(int argc, const char *argv[]) 
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    AppController     *controller;
  
    [BurnApplication sharedApplication];

    controller = [AppController appController];
    [NSApp setDelegate:controller];

    [[BurnApplication sharedApplication] run];

    RELEASE(controller);
    RELEASE(pool);

    return 0;
}
