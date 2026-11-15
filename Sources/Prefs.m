#import "Prefs.h"

static NSString *const LLBPrefsDomain = @"com.satoshiinu.lilliftboard";
static NSString *const LLBPrefsChangedNotification = @"com.satoshiinu.lilliftboard/prefschanged";

static const CGFloat LLBDefaultLift = 30.0;
static const CGFloat LLBMaxLift = 50.0;

BOOL LLBEnabled = YES;
CGFloat LLBLiftAmount = LLBDefaultLift;

void LLBReloadPrefs(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:LLBPrefsDomain];

    NSNumber *enabled = [defaults objectForKey:@"enabled"];
    LLBEnabled = enabled ? enabled.boolValue : YES;

    NSNumber *lift = [defaults objectForKey:@"lift"];
    CGFloat value = lift ? (CGFloat)lift.doubleValue : LLBDefaultLift;
    LLBLiftAmount = MIN(MAX(value, 0.0), LLBMaxLift);
}

static void LLBPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    LLBReloadPrefs();
}

void LLBStartObservingPrefs(void) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, LLBPrefsChanged, (CFStringRef)LLBPrefsChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
