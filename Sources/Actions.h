#import <Foundation/Foundation.h>
#import "LLBActionCatalog.h"

#ifdef __cplusplus
extern "C" {
#endif

// Performs one action from the catalog (Shared/LLBActionCatalog) on the
// current keyboard text input. `text` is only used by the insertText
// action and may be nil.
void LLBPerformAction(LLBAction action, NSString *text);

// Caret scrubbing for the dock bar drag: LLBScrubBegin anchors at the
// current caret (the selection start), LLBScrubMoveToOffset moves the
// caret to anchor + totalCharacters (the drag's accumulated character
// count, not a per-event delta), LLBScrubEnd releases the anchor.
// Moves are no-ops without a text input or after the input changes.
void LLBScrubBegin(void);
void LLBScrubMoveToOffset(NSInteger totalCharacters);
void LLBScrubEnd(void);

#ifdef __cplusplus
}
#endif
