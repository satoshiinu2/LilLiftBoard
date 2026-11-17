#import <UIKit/UIKit.h>
#import "LLBActionCatalog.h"

typedef void (^LLBActionPickerCompletion)(LLBAction action, NSString *text);

@interface LLBActionPickerController : UITableViewController

// When YES (the "add" flows), tapping an action adds it immediately
// instead of selecting it and waiting for Done. Insert Text is the
// exception: it first shows its text field, and Done adds it.
@property (nonatomic) BOOL addsImmediately;

- (instancetype)initWithAction:(LLBAction)action text:(NSString *)text completion:(LLBActionPickerCompletion)completion;

@end
