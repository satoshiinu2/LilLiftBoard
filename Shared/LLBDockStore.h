#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Dock button configuration, stored under the "dockButtons" key of the
// com.satoshiinu.lilliftboard preferences domain. This store is the
// storage boundary: on disk each button is a dictionary whose "action"
// value is the string identifier of an LLBAction (see LLBActionCatalog):
//   @{ @"action": NSString,
//      @"text":   NSString (optional, used by the insertText action),
//      @"popup":  NSArray of item dictionaries (optional) }
// Popup items have the same shape minus their own "popup". Callers convert
// the identifier to LLBAction as soon as they read an item.

// The whole preferences domain as one dictionary, merged from the
// plist file (rootless path first, then the rootful one) and the
// NSUserDefaults suite, with the suite winning: inside sandboxed app
// processes the suite can come back empty even though settings exist
// (the file covers those), while in processes where the suite works it
// holds the newest values — a just-saved setting must not be hidden by
// a not-yet-flushed plist file.
NSDictionary *LLBLoadPrefsDictionary(void);

NSArray<NSDictionary *> *LLBDefaultDockButtons(void);
NSArray<NSDictionary *> *LLBDefaultCenterDockButtons(void);
NSArray<NSDictionary *> *LLBDefaultRightDockButtons(void);

// Validated, mutable deep copies. Returns the default configuration when
// nothing valid is stored.
NSMutableArray<NSMutableDictionary *> *LLBLoadDockButtons(void);

void LLBSaveDockButtons(NSArray<NSDictionary *> *buttons);

// The center- and right-aligned groups, each stored under its own key,
// each with its own default list.
NSMutableArray<NSMutableDictionary *> *LLBLoadCenterDockButtons(void);
void LLBSaveCenterDockButtons(NSArray<NSDictionary *> *buttons);
NSMutableArray<NSMutableDictionary *> *LLBLoadRightDockButtons(void);
void LLBSaveRightDockButtons(NSArray<NSDictionary *> *buttons);

// Restores all groups to the defaults.
void LLBResetDockButtons(void);

void LLBPostPrefsChangedNotification(void);

#ifdef __cplusplus
}
#endif
