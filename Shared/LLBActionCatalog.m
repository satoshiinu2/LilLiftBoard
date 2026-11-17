#import "LLBActionCatalog.h"

// Indexed by LLBAction (LLBActionCut == 0). The identifiers are the stored
// form in the preferences plist and must not change.
static NSString *const LLBActionIdentifiers[] = {
    @"cut", @"copy", @"paste", @"selectAll", @"undo", @"redo",
    @"cursorLeft", @"cursorRight", @"lineStart", @"lineEnd",
    @"insertText", @"dismiss", @"deleteBackward", @"return",
};

static NSString *const LLBActionTitles[] = {
    @"Cut", @"Copy", @"Paste", @"Select All", @"Undo", @"Redo",
    @"Cursor Left", @"Cursor Right", @"Start of Line", @"End of Line",
    @"Insert Text", @"Dismiss Keyboard", @"Delete", @"Return",
};

static NSString *const LLBActionSymbols[] = {
    @"scissors", @"doc.on.doc", @"doc.on.clipboard", @"selection.pin.in.out",
    @"arrow.uturn.backward", @"arrow.uturn.forward",
    @"chevron.left", @"chevron.right",
    @"arrow.left.to.line", @"arrow.right.to.line",
    @"text.cursor", @"keyboard.chevron.compact.down",
    @"delete.left", @"return",
};

static const NSInteger LLBActionValueCount = (NSInteger)(sizeof(LLBActionIdentifiers) / sizeof(LLBActionIdentifiers[0]));

NSArray<NSNumber *> *LLBAllActions(void) {
    static NSArray *actions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *list = [NSMutableArray arrayWithCapacity:(NSUInteger)LLBActionValueCount];
        for (NSInteger value = 0; value < LLBActionValueCount; value++) {
            [list addObject:@(value)];
        }
        actions = [list copy];
    });
    return actions;
}

BOOL LLBIsValidAction(LLBAction action) {
    return action >= 0 && action < LLBActionValueCount;
}

NSString *LLBActionTitle(LLBAction action) {
    return LLBIsValidAction(action) ? LLBActionTitles[action] : nil;
}

NSString *LLBActionSymbol(LLBAction action) {
    return LLBIsValidAction(action) ? LLBActionSymbols[action] : nil;
}

LLBAction LLBActionFromIdentifier(NSString *identifier) {
    if (![identifier isKindOfClass:[NSString class]]) {
        return LLBActionUnknown;
    }
    for (NSInteger value = 0; value < LLBActionValueCount; value++) {
        if ([LLBActionIdentifiers[value] isEqualToString:identifier]) {
            return (LLBAction)value;
        }
    }
    return LLBActionUnknown;
}

NSString *LLBActionIdentifier(LLBAction action) {
    return LLBIsValidAction(action) ? LLBActionIdentifiers[action] : nil;
}
