#import <UIKit/UIKit.h>
#import "Prefs.h"

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
    }
}
