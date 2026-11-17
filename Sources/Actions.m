#import "Actions.h"
#import <UIKit/UIKit.h>

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
@property (nonatomic, readonly) UIResponder<UITextInput> *inputDelegate;
@property (nonatomic, readonly) UIResponder<UITextInput> *privateInputDelegate;
- (void)insertText:(NSString *)text;
- (void)dismissKeyboard;
@end

static UIKeyboardImpl *LLBKeyboardImpl(void) {
    return [UIKeyboardImpl activeInstance];
}

static UIResponder<UITextInput> *LLBTextInput(void) {
    UIKeyboardImpl *impl = LLBKeyboardImpl();
    UIResponder<UITextInput> *input = nil;
    if ([impl respondsToSelector:@selector(privateInputDelegate)]) {
        input = impl.privateInputDelegate;
    }
    if (!input && [impl respondsToSelector:@selector(inputDelegate)]) {
        input = impl.inputDelegate;
    }
    return input;
}

static void LLBMoveCaret(UIResponder<UITextInput> *input, NSInteger offset, BOOL toEndOnSelection) {
    UITextRange *range = input.selectedTextRange;
    if (!range) {
        return;
    }
    UITextPosition *caret = range.empty || !toEndOnSelection ? range.start : range.end;
    if (!range.empty) {
        input.selectedTextRange = [input textRangeFromPosition:caret toPosition:caret];
        return;
    }
    UITextPosition *target = [input positionFromPosition:caret offset:offset];
    if (target) {
        input.selectedTextRange = [input textRangeFromPosition:target toPosition:target];
    }
}

static void LLBMoveToLineBoundary(UIResponder<UITextInput> *input, BOOL toStart) {
    UITextRange *range = input.selectedTextRange;
    if (!range) {
        return;
    }
    UITextPosition *anchor = toStart ? range.start : range.end;
    // UITextDirectionBackward (== 1); the constant is not exported by the
    // 16.5 SDK headers, UITextStorageDirectionBackward has the same value.
    UITextRange *line = [input.tokenizer rangeEnclosingPosition:anchor withGranularity:UITextGranularityLine inDirection:(UITextDirection)UITextStorageDirectionBackward];
    UITextPosition *target = line ? (toStart ? line.start : line.end) : anchor;
    input.selectedTextRange = [input textRangeFromPosition:target toPosition:target];
}

static void LLBInsertText(UIKeyboardImpl *impl, UIResponder<UITextInput> *input, NSString *text) {
    if (text.length == 0) {
        return;
    }
    if ([impl respondsToSelector:@selector(insertText:)]) {
        [impl insertText:text];
    } else if (input && [input respondsToSelector:@selector(insertText:)]) {
        [input insertText:text];
    }
}

// No default case on purpose: the compiler warns when an LLBAction value
// is not handled here.
void LLBPerformAction(LLBAction action, NSString *text) {
    @try {
        UIKeyboardImpl *impl = LLBKeyboardImpl();
        UIResponder<UITextInput> *input = LLBTextInput();

        switch (action) {
            case LLBActionUnknown:
                break;
            case LLBActionCut:
                if (input && [input respondsToSelector:@selector(cut:)]) {
                    [input cut:nil];
                } else if (input.selectedTextRange) {
                    NSString *selected = [input textInRange:input.selectedTextRange];
                    if (selected.length > 0) {
                        [UIPasteboard generalPasteboard].string = selected;
                        [input replaceRange:input.selectedTextRange withText:@""];
                    }
                }
                break;
            case LLBActionCopy:
                if (input && [input respondsToSelector:@selector(copy:)]) {
                    [input copy:nil];
                } else if (input.selectedTextRange) {
                    NSString *selected = [input textInRange:input.selectedTextRange];
                    if (selected.length > 0) {
                        [UIPasteboard generalPasteboard].string = selected;
                    }
                }
                break;
            case LLBActionPaste:
                if (input && [input respondsToSelector:@selector(paste:)]) {
                    [input paste:nil];
                } else {
                    NSString *string = [UIPasteboard generalPasteboard].string;
                    if (string.length > 0) {
                        LLBInsertText(impl, input, string);
                    }
                }
                break;
            case LLBActionSelectAll:
                if (input && [input respondsToSelector:@selector(selectAll:)]) {
                    [input selectAll:nil];
                } else if (input) {
                    input.selectedTextRange = [input textRangeFromPosition:input.beginningOfDocument toPosition:input.endOfDocument];
                }
                break;
            case LLBActionUndo: {
                NSUndoManager *manager = input.undoManager;
                if (manager.canUndo) {
                    [manager undo];
                }
                break;
            }
            case LLBActionRedo: {
                NSUndoManager *manager = input.undoManager;
                if (manager.canRedo) {
                    [manager redo];
                }
                break;
            }
            case LLBActionCursorLeft:
                if (input) {
                    LLBMoveCaret(input, -1, NO);
                }
                break;
            case LLBActionCursorRight:
                if (input) {
                    LLBMoveCaret(input, 1, YES);
                }
                break;
            case LLBActionLineStart:
                if (input) {
                    LLBMoveToLineBoundary(input, YES);
                }
                break;
            case LLBActionLineEnd:
                if (input) {
                    LLBMoveToLineBoundary(input, NO);
                }
                break;
            case LLBActionInsertText:
                LLBInsertText(impl, input, text);
                break;
            case LLBActionDismiss:
                if ([impl respondsToSelector:@selector(dismissKeyboard)]) {
                    [impl dismissKeyboard];
                } else {
                    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
                }
                break;
            case LLBActionDeleteBackward:
                if (input && [input respondsToSelector:@selector(deleteBackward)]) {
                    [input deleteBackward];
                } else if (input.selectedTextRange && !input.selectedTextRange.empty) {
                    [input replaceRange:input.selectedTextRange withText:@""];
                }
                break;
            case LLBActionReturn:
                LLBInsertText(impl, input, @"\n");
                break;
        }
    } @catch (NSException *exception) {
    }
}
