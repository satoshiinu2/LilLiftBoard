#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Every action a dock button (or a long-press popup item) can perform.
// In code, actions are always handled as this enum; the string identifiers
// exist only at the preferences-storage boundary, where LLBActionFromIdentifier
// and LLBActionIdentifier convert between the two representations.
typedef NS_ENUM(NSInteger, LLBAction) {
    LLBActionUnknown = -1,
    LLBActionCut = 0,
    LLBActionCopy,
    LLBActionPaste,
    LLBActionSelectAll,
    LLBActionUndo,
    LLBActionRedo,
    LLBActionCursorLeft,
    LLBActionCursorRight,
    LLBActionLineStart,
    LLBActionLineEnd,
    LLBActionInsertText,
    LLBActionDismiss,
    // Appended after the original values: existing values are the catalog
    // order used for display and must not shift.
    LLBActionDeleteBackward,
    LLBActionReturn,
};

// All valid actions, in catalog (display) order.
NSArray<NSNumber *> *LLBAllActions(void);

BOOL LLBIsValidAction(LLBAction action);
NSString *LLBActionTitle(LLBAction action);
NSString *LLBActionSymbol(LLBAction action);

// Storage-boundary conversions. LLBActionFromIdentifier returns
// LLBActionUnknown for nil, non-string, or unrecognized input;
// LLBActionIdentifier returns nil for LLBActionUnknown.
LLBAction LLBActionFromIdentifier(NSString *identifier);
NSString *LLBActionIdentifier(LLBAction action);

#ifdef __cplusplus
}
#endif
