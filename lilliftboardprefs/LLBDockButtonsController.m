#import "LLBDockButtonsController.h"
#import "LLBDockButtonDetailController.h"
#import "LLBActionPickerController.h"
#import "LLBActionCatalog.h"
#import "LLBDockStore.h"

static const NSInteger LLBGroupCount = 3;
static const NSInteger LLBSectionReset = 3;

@interface LLBDockButtonsController () <UITableViewDragDelegate, UITableViewDropDelegate>
@property (nonatomic, strong) NSArray<NSMutableArray<NSMutableDictionary *> *> *groups;
@end

@implementation LLBDockButtonsController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        [self reloadGroups];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Dock Buttons";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButton)];
    // No edit button: it would take the back button's place in the
    // navigation bar. Reordering is long-press drag, deleting is swipe
    // (or the detail screen), so edit mode is never needed here.
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    self.tableView.dragInteractionEnabled = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadGroups];
    [self.tableView reloadData];
}

- (void)reloadGroups {
    self.groups = @[ LLBLoadDockButtons(), LLBLoadCenterDockButtons(), LLBLoadRightDockButtons() ];
}

- (NSMutableArray<NSMutableDictionary *> *)buttonsInSection:(NSInteger)section {
    if (section < 0 || section >= LLBGroupCount) {
        return nil;
    }
    return self.groups[(NSUInteger)section];
}

- (void)saveSection:(NSInteger)section {
    if (section == 0) {
        LLBSaveDockButtons(self.groups[0]);
    } else if (section == 1) {
        LLBSaveCenterDockButtons(self.groups[1]);
    } else if (section == 2) {
        LLBSaveRightDockButtons(self.groups[2]);
    }
}

- (NSString *)nameForSection:(NSInteger)section {
    if (section == 0) {
        return @"Left Buttons";
    }
    if (section == 1) {
        return @"Center Buttons";
    }
    return @"Right Buttons";
}

- (void)addButton {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Add Button" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger section = 0; section < LLBGroupCount; section++) {
        NSString *title = [@"Add to " stringByAppendingString:[self nameForSection:section]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self addButtonToSection:section];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)addButtonToSection:(NSInteger)section {
    LLBActionPickerController *picker = [[LLBActionPickerController alloc] initWithAction:LLBActionCopy text:nil completion:^(LLBAction action, NSString *text) {

        NSMutableDictionary *button = [NSMutableDictionary dictionary];
        button[@"action"] = LLBActionIdentifier(action);
        if (text.length > 0) {
            button[@"text"] = text;
        }
        button[@"popup"] = [NSMutableArray array];
        [[self buttonsInSection:section] addObject:button];
        [self saveSection:section];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)section] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
    picker.addsImmediately = YES;
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)openDetailForRow:(NSInteger)row inSection:(NSInteger)section {
    if (row < 0 || row >= (NSInteger)[self buttonsInSection:section].count) {
        return;
    }
    LLBDockButtonDetailController *detail = [[LLBDockButtonDetailController alloc] initWithButtonIndex:row group:section];
    [self.navigationController pushViewController:detail animated:YES];
}

- (void)infoTapped:(UIButton *)sender {
    // The button's tag packs section and row: section * 1000 + row.
    [self openDetailForRow:sender.tag % 1000 inSection:sender.tag / 1000];
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset all buttons to the defaults?" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        LLBResetDockButtons();
        [self reloadGroups];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.tableView;
    alert.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:LLBSectionReset]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return LLBGroupCount + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == LLBSectionReset) {
        return 1;
    }
    NSUInteger count = [self buttonsInSection:section].count;
    return (NSInteger)MAX(count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == LLBSectionReset) {
        return nil;
    }
    return [self nameForSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == LLBSectionReset) {
        return @"Restores the default buttons: Copy, Paste and Undo on the left, the cursor keys in the center, and Dismiss Keyboard on the right.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == LLBSectionReset) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ResetCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ResetCell"];
        }
        cell.textLabel.text = @"Reset to Defaults";
        cell.textLabel.textColor = [UIColor systemRedColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    }

    NSMutableArray *buttons = [self buttonsInSection:indexPath.section];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ButtonCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ButtonCell"];
    }
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    if (buttons.count == 0) {
        cell.textLabel.text = @"No Buttons";
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    cell.textLabel.textColor = [UIColor labelColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    NSDictionary *button = buttons[(NSUInteger)indexPath.row];
    LLBAction action = LLBActionFromIdentifier(button[@"action"]);
    cell.textLabel.text = LLBActionTitle(action);
    NSString *subtitle = nil;
    if (action == LLBActionInsertText && [button[@"text"] length] > 0) {
        subtitle = button[@"text"];
    } else {
        NSArray *popup = button[@"popup"];
        if ([popup isKindOfClass:[NSArray class]] && popup.count > 0) {
            NSMutableArray *titles = [NSMutableArray array];
            for (NSDictionary *item in popup) {
                NSString *title = LLBActionTitle(LLBActionFromIdentifier(item[@"action"]));
                if (title) {
                    [titles addObject:title];
                }
            }
            subtitle = [@"Long press: " stringByAppendingString:[titles componentsJoinedByString:@", "]];
        }
    }
    cell.detailTextLabel.text = subtitle;

    UIButton *info = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    info.tag = indexPath.section * 1000 + indexPath.row;
    [info addTarget:self action:@selector(infoTapped:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = info;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == LLBSectionReset) {
        [self confirmReset];
        return;
    }
    if ([self buttonsInSection:indexPath.section].count > 0) {
        [self openDetailForRow:indexPath.row inSection:indexPath.section];
    }
}

#pragma mark - Editing (the standard list editing, like Control Center)

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section < LLBGroupCount && [self buttonsInSection:indexPath.section].count > 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView canEditRowAtIndexPath:indexPath];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    [[self buttonsInSection:indexPath.section] removeObjectAtIndex:(NSUInteger)indexPath.row];
    [self saveSection:indexPath.section];
    [tableView reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSMutableArray *source = [self buttonsInSection:sourceIndexPath.section];
    NSMutableDictionary *button = source[(NSUInteger)sourceIndexPath.row];
    [source removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
    [[self buttonsInSection:destinationIndexPath.section] insertObject:button atIndex:(NSUInteger)destinationIndexPath.row];
    [self saveSection:sourceIndexPath.section];
    if (destinationIndexPath.section != sourceIndexPath.section) {
        [self saveSection:destinationIndexPath.section];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    // Rows can move between the alignment groups, but not into the
    // reset section, and not past the end of a group.
    if (proposedDestinationIndexPath.section >= LLBGroupCount) {
        return sourceIndexPath;
    }
    NSInteger lastRow = (NSInteger)[self buttonsInSection:proposedDestinationIndexPath.section].count;
    if (proposedDestinationIndexPath.section == sourceIndexPath.section) {
        lastRow -= 1;
    }
    if (proposedDestinationIndexPath.row > lastRow) {
        return [NSIndexPath indexPathForRow:MAX(lastRow, 0) inSection:proposedDestinationIndexPath.section];
    }
    return proposedDestinationIndexPath;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self tableView:tableView canEditRowAtIndexPath:indexPath]) {
        return nil;
    }
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[self buttonsInSection:indexPath.section] removeObjectAtIndex:(NSUInteger)indexPath.row];
        [self saveSection:indexPath.section];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
}

#pragma mark - Drag & drop reorder (without edit mode)

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (tableView.isEditing || ![self tableView:tableView canEditRowAtIndexPath:indexPath]) {
        return @[];
    }
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] init]];
    item.localObject = indexPath;
    return @[item];
}

- (BOOL)tableView:(UITableView *)tableView canHandleDragSession:(id<UIDropSession>)session {
    return session.localDragSession != nil;
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession == nil || (destinationIndexPath && destinationIndexPath.section >= LLBGroupCount)) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationForbidden];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    if (coordinator.items.count == 0) {
        return;
    }
    NSIndexPath *source = coordinator.items.firstObject.dragItem.localObject;
    if (!source || source.section >= LLBGroupCount) {
        return;
    }
    NSIndexPath *destination = coordinator.destinationIndexPath;
    if (!destination || destination.section >= LLBGroupCount) {
        destination = source;
    }
    NSMutableArray *sourceButtons = [self buttonsInSection:source.section];
    NSMutableArray *destinationButtons = [self buttonsInSection:destination.section];
    NSInteger destinationRow = MIN(destination.row, (NSInteger)destinationButtons.count - (destination.section == source.section ? 1 : 0));
    destinationRow = MAX(destinationRow, 0);
    NSMutableDictionary *button = sourceButtons[(NSUInteger)source.row];
    [sourceButtons removeObjectAtIndex:(NSUInteger)source.row];
    [destinationButtons insertObject:button atIndex:(NSUInteger)destinationRow];
    [self saveSection:source.section];
    if (destination.section != source.section) {
        [self saveSection:destination.section];
    }
    NSIndexPath *finalIndexPath = [NSIndexPath indexPathForRow:destinationRow inSection:destination.section];
    [coordinator dropItem:coordinator.items.firstObject.dragItem toRowAtIndexPath:finalIndexPath];
    // A group that became empty (or stops being empty) changes its row
    // count by the placeholder row; settle that after the drop animation.
    dispatch_async(dispatch_get_main_queue(), ^{
        [tableView reloadData];
    });
}

@end
