#import "Prefs.h"
#import "LLBDockStore.h"
#import "DockBar.h"

static NSString *const LLBPrefsChangedNotification = @"com.satoshiinu.lilliftboard/prefschanged";

static const CGFloat LLBDefaultLift = 30.0;
static const CGFloat LLBMaxLift = 50.0;

// Matches the pre-setting layout: button width was capped at 56 pt and the
// height filled the dock, so a 56 pt cap on the square side keeps the
// default appearance unchanged; buttons were adjacent, hence spacing 0.
static const CGFloat LLBDefaultDockButtonSize = 56.0;
static const CGFloat LLBMinDockButtonSize = 20.0;
static const CGFloat LLBMaxDockButtonSize = 60.0;
static const CGFloat LLBDefaultDockButtonSpacing = 0.0;
static const CGFloat LLBMaxDockButtonSpacing = 24.0;
static const CGFloat LLBDefaultDockBarMargin = 20.0;
static const CGFloat LLBMaxDockBarMargin = 40.0;

BOOL LLBEnabled = YES;
CGFloat LLBLiftAmount = LLBDefaultLift;
BOOL LLBDockButtonsEnabled = YES;
NSArray<NSDictionary *> *LLBDockButtons = nil;
NSArray<NSDictionary *> *LLBDockButtonsCenter = nil;
NSArray<NSDictionary *> *LLBDockButtonsRight = nil;
CGFloat LLBDockButtonSize = LLBDefaultDockButtonSize;
CGFloat LLBDockButtonSpacing = LLBDefaultDockButtonSpacing;
CGFloat LLBDockBarMargin = LLBDefaultDockBarMargin;
NSInteger LLBDockSymbolWeightIndex = 2;
BOOL LLBDockDragCursorEnabled = YES;

void LLBReloadPrefs(void) {
    NSDictionary *defaults = LLBLoadPrefsDictionary();

    NSNumber *enabled = [defaults objectForKey:@"enabled"];
    LLBEnabled = enabled ? enabled.boolValue : YES;

    NSNumber *lift = [defaults objectForKey:@"lift"];
    CGFloat value = lift ? (CGFloat)lift.doubleValue : LLBDefaultLift;
    LLBLiftAmount = MIN(MAX(value, 0.0), LLBMaxLift);

    NSNumber *dockEnabled = [defaults objectForKey:@"dockButtonsEnabled"];
    LLBDockButtonsEnabled = dockEnabled ? dockEnabled.boolValue : YES;

    NSNumber *buttonSize = [defaults objectForKey:@"dockButtonSize"];
    CGFloat size = buttonSize ? (CGFloat)buttonSize.doubleValue : LLBDefaultDockButtonSize;
    LLBDockButtonSize = MIN(MAX(size, LLBMinDockButtonSize), LLBMaxDockButtonSize);

    NSNumber *buttonSpacing = [defaults objectForKey:@"dockButtonSpacing"];
    CGFloat spacing = buttonSpacing ? (CGFloat)buttonSpacing.doubleValue : LLBDefaultDockButtonSpacing;
    LLBDockButtonSpacing = MIN(MAX(spacing, 0.0), LLBMaxDockButtonSpacing);

    NSNumber *barMargin = [defaults objectForKey:@"dockBarMargin"];
    CGFloat margin = barMargin ? (CGFloat)barMargin.doubleValue : LLBDefaultDockBarMargin;
    LLBDockBarMargin = MIN(MAX(margin, 0.0), LLBMaxDockBarMargin);

    NSNumber *symbolWeight = [defaults objectForKey:@"dockSymbolWeight"];
    NSInteger weightIndex = symbolWeight ? symbolWeight.integerValue : 2;
    LLBDockSymbolWeightIndex = MIN(MAX(weightIndex, 0), 8);

    NSNumber *dragCursor = [defaults objectForKey:@"dockDragCursor"];
    LLBDockDragCursorEnabled = dragCursor ? dragCursor.boolValue : YES;

    LLBDockButtons = [LLBLoadDockButtons() copy];
    LLBDockButtonsCenter = [LLBLoadCenterDockButtons() copy];
    LLBDockButtonsRight = [LLBLoadRightDockButtons() copy];
}

static void LLBPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    LLBReloadPrefs();
    dispatch_async(dispatch_get_main_queue(), ^{
        [LLBDockBar refreshAllBars];
    });
}

void LLBStartObservingPrefs(void) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, LLBPrefsChanged, (CFStringRef)LLBPrefsChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
