#import <UIKit/UIKit.h>

@interface LLBDockButtonDetailController : UITableViewController

- (instancetype)initWithButtonIndex:(NSInteger)index;

// Group selects the button list: 0 = left, 1 = center, 2 = right,
// matching the sections of the dock buttons list.
- (instancetype)initWithButtonIndex:(NSInteger)index group:(NSInteger)group;

@end
