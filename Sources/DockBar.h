#import <UIKit/UIKit.h>

@interface LLBDockBar : UIView

// Finds (or creates) the bar attached to the given UIKeyboardDockView and
// brings it in sync with the current preferences and dock geometry.
+ (void)syncWithDockView:(UIView *)dockView;

// Fallback host: finds (or creates) the bar attached to the keyboard's
// UIPeripheralHostView, laid out in the bottom strip the lift creates.
// Used only while no dock-hosted bar is visible, so devices whose dock
// view is usable keep the dock layout and never show two bars.
+ (void)syncWithHostView:(UIView *)hostView;

// Second fallback host: the keyboard window itself, with the bar in the
// bottom strip of the window's bounds. For cases where neither the dock
// view nor the peripheral host view ever lay out with a usable frame.
+ (void)syncWithWindow:(UIWindow *)window;

// Syncs the window-hosted bar of every keyboard window of the process.
// Called when the keyboard has finished appearing.
+ (void)syncKeyboardWindows;

// Re-syncs every live bar after a preferences change.
+ (void)refreshAllBars;

@end
