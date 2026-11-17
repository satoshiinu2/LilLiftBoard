#import <Foundation/Foundation.h>
#import "LLBActionCatalog.h"

#ifdef __cplusplus
extern "C" {
#endif

// Performs one action from the catalog (Shared/LLBActionCatalog) on the
// current keyboard text input. `text` is only used by the insertText
// action and may be nil.
void LLBPerformAction(LLBAction action, NSString *text);

#ifdef __cplusplus
}
#endif
