#import <UIKit/UIKit.h>
#import "Prefs.h"
#import "DockBar.h"

// LilLiftBoard raises the system keyboard on Home-button iPhones by giving
// UIKit a non-zero bottom device-specific padding, the same mechanism the
// system itself uses for the dock area on iPhone X and later. The keyboard
// background and the globe / dictation dock are laid out by UIKit into the
// added space, so nothing is left transparent below the keys.

%group LilLiftBoard

%hook UIKeyboardImpl

+ (UIEdgeInsets)deviceSpecificPaddingForInterfaceOrientation:(NSInteger)orientation inputMode:(id)mode {
    UIEdgeInsets padding = %orig;
    if (!LLBEnabled || LLBLiftAmount <= 0) {
        return padding;
    }
    if (padding.bottom > 0) {
        return padding;
    }
    if (orientation != UIInterfaceOrientationPortrait && orientation != UIInterfaceOrientationPortraitUpsideDown) {
        return padding;
    }
    padding.bottom = LLBLiftAmount;
    return padding;
}

%end

%hook UIKeyboardDockView

- (CGRect)bounds {
    CGRect bounds = %orig;
    if (LLBEnabled && LLBLiftAmount > 0) {
        bounds.size.height += MIN(15.0, LLBLiftAmount);
    }
    return bounds;
}

- (void)layoutSubviews {
    %orig;
    [LLBDockBar syncWithDockView:(UIView *)self];
}

%end

// Fallback hosting for the dock bar (see DockBar.m): on Home-button
// devices the dock view may never get a usable frame, but the peripheral
// host view always spans the whole keyboard, lifted strip included.
%hook UIPeripheralHostView

- (void)layoutSubviews {
    %orig;
    [LLBDockBar syncWithHostView:(UIView *)self];
}

%end

%hook UIKeyboardLayoutStar

- (void)layoutSubviews {
    %orig;
    UIView *superview = [(UIView *)self superview];
    if ([superview isKindOfClass:NSClassFromString(@"UIPeripheralHostView")]) {
        [LLBDockBar syncWithHostView:superview];
    }
}

%end

// Last-resort hosting: the keyboard window itself. Its bounds are the
// whole keyboard, so the bar can sit in the lifted strip at its bottom
// no matter how the views inside are laid out.
%hook UITextEffectsWindow

- (void)layoutSubviews {
    %orig;
    // UITextEffectsWindow also hosts non-keyboard effects; where the
    // dedicated remote keyboard window class exists, only it counts.
    Class remoteKeyboardWindow = NSClassFromString(@"UIRemoteKeyboardWindow");
    if (!remoteKeyboardWindow || [(UIWindow *)self isKindOfClass:remoteKeyboardWindow]) {
        [LLBDockBar syncWithWindow:(UIWindow *)self];
    }
}

%end

%hook UIRemoteKeyboardWindow

- (void)layoutSubviews {
    %orig;
    [LLBDockBar syncWithWindow:(UIWindow *)self];
}

%end

%end

%ctor {
    @autoreleasepool {
        if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
            return;
        }
        LLBReloadPrefs();
        LLBStartObservingPrefs();
        %init(LilLiftBoard);
        // One more trigger for the window-hosted bar, in case the
        // keyboard window does not lay out again after it appears.
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
            [LLBDockBar syncKeyboardWindows];
        }];
    }
}
