#import "LLBDockStore.h"
#import "LLBActionCatalog.h"

static NSString *const LLBDockStoreDomain = @"com.satoshiinu.lilliftboard";
static NSString *const LLBDockStoreKey = @"dockButtons";
static NSString *const LLBDockStoreCenterKey = @"dockButtonsCenter";
static NSString *const LLBDockStoreRightKey = @"dockButtonsRight";
static NSString *const LLBDockStoreChangedNotification = @"com.satoshiinu.lilliftboard/prefschanged";

static NSDictionary *LLBStoredItem(LLBAction action, NSArray<NSDictionary *> *popup) {
    NSMutableDictionary *item = [NSMutableDictionary dictionary];
    item[@"action"] = LLBActionIdentifier(action);
    if (popup) {
        item[@"popup"] = popup;
    }
    return item;
}

NSArray<NSDictionary *> *LLBDefaultDockButtons(void) {
    return @[
        LLBStoredItem(LLBActionCopy, @[ LLBStoredItem(LLBActionCut, nil), LLBStoredItem(LLBActionSelectAll, nil) ]),
        LLBStoredItem(LLBActionPaste, nil),
        LLBStoredItem(LLBActionUndo, @[ LLBStoredItem(LLBActionRedo, nil) ]),
    ];
}

NSArray<NSDictionary *> *LLBDefaultCenterDockButtons(void) {
    return @[
        LLBStoredItem(LLBActionCursorLeft, @[ LLBStoredItem(LLBActionLineStart, nil), LLBStoredItem(LLBActionDismiss, nil) ]),
        LLBStoredItem(LLBActionCursorRight, @[ LLBStoredItem(LLBActionLineEnd, nil), LLBStoredItem(LLBActionDismiss, nil) ]),
    ];
}

NSArray<NSDictionary *> *LLBDefaultRightDockButtons(void) {
    return @[
        LLBStoredItem(LLBActionDismiss, nil),
    ];
}

static NSMutableDictionary *LLBSanitizedItem(NSDictionary *item, BOOL allowPopup) {
    if (![item isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    LLBAction action = LLBActionFromIdentifier(item[@"action"]);
    if (action == LLBActionUnknown) {
        return nil;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"action"] = LLBActionIdentifier(action);
    NSString *text = item[@"text"];
    if ([text isKindOfClass:[NSString class]] && text.length > 0) {
        result[@"text"] = text;
    }
    if (allowPopup) {
        NSMutableArray *popup = [NSMutableArray array];
        NSArray *rawPopup = item[@"popup"];
        if ([rawPopup isKindOfClass:[NSArray class]]) {
            for (id entry in rawPopup) {
                NSMutableDictionary *sub = LLBSanitizedItem(entry, NO);
                if (sub) {
                    [popup addObject:sub];
                }
            }
        }
        result[@"popup"] = popup;
    }
    return result;
}

static NSArray<NSString *> *LLBPrefsFilePaths(void) {
    NSString *fileName = [LLBDockStoreDomain stringByAppendingPathExtension:@"plist"];
    return @[
        [@"/var/jb/var/mobile/Library/Preferences" stringByAppendingPathComponent:fileName],
        [@"/var/mobile/Library/Preferences" stringByAppendingPathComponent:fileName],
    ];
}

NSDictionary *LLBLoadPrefsDictionary(void) {
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    for (NSString *path in LLBPrefsFilePaths()) {
        NSDictionary *fromFile = [NSDictionary dictionaryWithContentsOfFile:path];
        if (fromFile.count > 0) {
            [merged addEntriesFromDictionary:fromFile];
            break;
        }
    }
    NSDictionary *fromSuite = [[[NSUserDefaults alloc] initWithSuiteName:LLBDockStoreDomain] dictionaryRepresentation];
    [merged addEntriesFromDictionary:fromSuite];
    return merged;
}

// Best-effort write-through to the plist file, so processes that can
// only read the file (sandboxed apps) see button changes at once
// instead of waiting for cfprefsd to flush the suite to disk.
static void LLBWritePrefsValueToFile(id value, NSString *key) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *targetPath = nil;
    for (NSString *path in LLBPrefsFilePaths()) {
        if ([fileManager fileExistsAtPath:path]) {
            targetPath = path;
            break;
        }
    }
    if (!targetPath) {
        for (NSString *path in LLBPrefsFilePaths()) {
            if ([fileManager fileExistsAtPath:path.stringByDeletingLastPathComponent]) {
                targetPath = path;
                break;
            }
        }
    }
    if (!targetPath) {
        return;
    }
    NSMutableDictionary *dictionary = [LLBLoadPrefsDictionary() mutableCopy];
    dictionary[key] = value;
    [dictionary writeToFile:targetPath atomically:YES];
}

static NSMutableArray<NSMutableDictionary *> *LLBLoadButtonsForKey(NSString *key, NSArray<NSDictionary *> *defaultButtons) {
    NSArray *raw = LLBLoadPrefsDictionary()[key];
    NSMutableArray *buttons = [NSMutableArray array];
    if ([raw isKindOfClass:[NSArray class]]) {
        for (id entry in raw) {
            NSMutableDictionary *button = LLBSanitizedItem(entry, YES);
            if (button) {
                [buttons addObject:button];
            }
        }
    }
    if (buttons.count == 0 && ![raw isKindOfClass:[NSArray class]]) {
        for (NSDictionary *entry in defaultButtons) {
            [buttons addObject:LLBSanitizedItem(entry, YES)];
        }
    }
    return buttons;
}

static void LLBSaveButtonsForKey(NSArray<NSDictionary *> *buttons, NSString *key) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:LLBDockStoreDomain];
    [defaults setObject:buttons forKey:key];
    LLBWritePrefsValueToFile(buttons, key);
    LLBPostPrefsChangedNotification();
}

NSMutableArray<NSMutableDictionary *> *LLBLoadDockButtons(void) {
    return LLBLoadButtonsForKey(LLBDockStoreKey, LLBDefaultDockButtons());
}

void LLBSaveDockButtons(NSArray<NSDictionary *> *buttons) {
    LLBSaveButtonsForKey(buttons, LLBDockStoreKey);
}

NSMutableArray<NSMutableDictionary *> *LLBLoadCenterDockButtons(void) {
    return LLBLoadButtonsForKey(LLBDockStoreCenterKey, LLBDefaultCenterDockButtons());
}

void LLBSaveCenterDockButtons(NSArray<NSDictionary *> *buttons) {
    LLBSaveButtonsForKey(buttons, LLBDockStoreCenterKey);
}

NSMutableArray<NSMutableDictionary *> *LLBLoadRightDockButtons(void) {
    return LLBLoadButtonsForKey(LLBDockStoreRightKey, LLBDefaultRightDockButtons());
}

void LLBSaveRightDockButtons(NSArray<NSDictionary *> *buttons) {
    LLBSaveButtonsForKey(buttons, LLBDockStoreRightKey);
}

void LLBResetDockButtons(void) {
    LLBSaveDockButtons(LLBDefaultDockButtons());
    LLBSaveCenterDockButtons(LLBDefaultCenterDockButtons());
    LLBSaveRightDockButtons(LLBDefaultRightDockButtons());
}

void LLBPostPrefsChangedNotification(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)LLBDockStoreChangedNotification, NULL, NULL, true);
}
