#import "LLBDockButtonDetailController.h"
#import "LLBActionPickerController.h"
#import "LLBActionCatalog.h"
#import "LLBDockStore.h"

static const NSInteger LLBSectionTap = 0;
static const NSInteger LLBSectionPopup = 1;
static const NSInteger LLBSectionDelete = 2;

@interface LLBDockButtonDetailController () <UITextFieldDelegate, UITableViewDragDelegate, UITableViewDropDelegate>
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *buttons;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) NSInteger group;
@property (nonatomic, weak) UITextField *textField;
@end

@implementation LLBDockButtonDetailController

- (instancetype)initWithButtonIndex:(NSInteger)index {
    return [self initWithButtonIndex:index group:0];
}

- (instancetype)initWithButtonIndex:(NSInteger)index group:(NSInteger)group {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _index = index;
        _group = group;
        if (group == 1) {
            _buttons = LLBLoadCenterDockButtons();
        } else if (group == 2) {
            _buttons = LLBLoadRightDockButtons();
        } else {
            _buttons = LLBLoadDockButtons();
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    self.tableView.dragInteractionEnabled = YES;
    [self refreshTitle];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.textField.isFirstResponder) {
        [self.textField resignFirstResponder];
    }
}

- (NSMutableDictionary *)button {
    if (self.index < 0 || self.index >= (NSInteger)self.buttons.count) {
        return nil;
    }
    return self.buttons[(NSUInteger)self.index];
}

- (NSMutableArray *)popupItems {
    NSMutableArray *popup = self.button[@"popup"];
    if (![popup isKindOfClass:[NSMutableArray class]]) {
        popup = [NSMutableArray array];
        self.button[@"popup"] = popup;
    }
    return popup;
}

- (LLBAction)buttonAction {
    return LLBActionFromIdentifier(self.button[@"action"]);
}

- (void)refreshTitle {
    self.title = LLBActionTitle([self buttonAction]) ?: @"Button";
}

- (void)save {
    if (self.group == 1) {
        LLBSaveCenterDockButtons(self.buttons);
    } else if (self.group == 2) {
        LLBSaveRightDockButtons(self.buttons);
    } else {
        LLBSaveDockButtons(self.buttons);
    }
    [self refreshTitle];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == LLBSectionTap) {
        return [self buttonAction] == LLBActionInsertText ? 2 : 1;
    }
    if (section == LLBSectionPopup) {
        return (NSInteger)[self popupItems].count + 1;
    }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == LLBSectionTap) {
        return @"Tap";
    }
    if (section == LLBSectionPopup) {
        return @"Long-Press Popup";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == LLBSectionPopup) {
        return @"Items shown in a panel above the button when it is long-pressed. Drag to reorder.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == LLBSectionTap && indexPath.row == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TextCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TextCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UITextField *field = [[UITextField alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 16.0, 0.0)];
            field.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            field.placeholder = @"Text to Insert";
            field.returnKeyType = UIReturnKeyDone;
            field.delegate = self;
            [cell.contentView addSubview:field];
            self.textField = field;
        }
        self.textField.text = self.button[@"text"];
        return cell;
    }

    NSString *identifier = indexPath.section == LLBSectionDelete ? @"DeleteCell" : @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
    }
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == LLBSectionTap) {
        cell.textLabel.text = @"Action";
        cell.detailTextLabel.text = LLBActionTitle([self buttonAction]);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == LLBSectionPopup) {
        if (indexPath.row < (NSInteger)[self popupItems].count) {
            NSDictionary *item = [self popupItems][(NSUInteger)indexPath.row];
            LLBAction itemAction = LLBActionFromIdentifier(item[@"action"]);
            cell.textLabel.text = LLBActionTitle(itemAction);
            if (itemAction == LLBActionInsertText && [item[@"text"] length] > 0) {
                cell.detailTextLabel.text = item[@"text"];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"Add Item";
            cell.textLabel.textColor = self.view.tintColor;
        }
    } else {
        cell.textLabel.text = @"Delete Button";
        cell.textLabel.textColor = [UIColor systemRedColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == LLBSectionTap && indexPath.row == 0) {
        [self editItem:self.button isPopupItem:NO];
    } else if (indexPath.section == LLBSectionPopup) {
        if (indexPath.row < (NSInteger)[self popupItems].count) {
            [self editItem:[self popupItems][(NSUInteger)indexPath.row] isPopupItem:YES];
        } else {
            [self addPopupItem];
        }
    } else if (indexPath.section == LLBSectionDelete) {
        [self confirmDelete];
    }
}

- (void)editItem:(NSMutableDictionary *)item isPopupItem:(BOOL)isPopupItem {
    LLBActionPickerController *picker = [[LLBActionPickerController alloc] initWithAction:LLBActionFromIdentifier(item[@"action"]) text:item[@"text"] completion:^(LLBAction action, NSString *text) {
        item[@"action"] = LLBActionIdentifier(action);
        if (text.length > 0) {
            item[@"text"] = text;
        } else {
            [item removeObjectForKey:@"text"];
        }
        [self save];
        [self.tableView reloadData];
    }];
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)addPopupItem {
    LLBActionPickerController *picker = [[LLBActionPickerController alloc] initWithAction:LLBActionCopy text:nil completion:^(LLBAction action, NSString *text) {
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        item[@"action"] = LLBActionIdentifier(action);
        if (text.length > 0) {
            item[@"text"] = text;
        }
        [[self popupItems] addObject:item];
        [self save];
        [self.tableView reloadData];
    }];
    picker.addsImmediately = YES;
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)confirmDelete {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete this button?" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.buttons removeObjectAtIndex:(NSUInteger)self.index];
        [self save];
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.tableView;
    alert.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:LLBSectionDelete]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != LLBSectionPopup || indexPath.row >= (NSInteger)[self popupItems].count) {
        return nil;
    }
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[self popupItems] removeObjectAtIndex:(NSUInteger)indexPath.row];
        [self save];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
}

#pragma mark - Text field

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.text.length > 0) {
        self.button[@"text"] = textField.text;
    } else {
        [self.button removeObjectForKey:@"text"];
    }
    [self save];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Drag & drop reorder (popup items)

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != LLBSectionPopup || indexPath.row >= (NSInteger)[self popupItems].count) {
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
    if (session.localDragSession == nil || (destinationIndexPath && destinationIndexPath.section != LLBSectionPopup)) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationForbidden];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    if (coordinator.items.count == 0) {
        return;
    }
    NSIndexPath *source = coordinator.items.firstObject.dragItem.localObject;
    if (!source || source.section != LLBSectionPopup) {
        return;
    }
    NSInteger destinationRow = coordinator.destinationIndexPath ? coordinator.destinationIndexPath.row : (NSInteger)[self popupItems].count - 1;
    destinationRow = MIN(MAX(destinationRow, 0), (NSInteger)[self popupItems].count - 1);
    NSMutableDictionary *item = [self popupItems][(NSUInteger)source.row];
    [[self popupItems] removeObjectAtIndex:(NSUInteger)source.row];
    [[self popupItems] insertObject:item atIndex:(NSUInteger)destinationRow];
    [self save];
    NSIndexPath *destination = [NSIndexPath indexPathForRow:destinationRow inSection:LLBSectionPopup];
    [coordinator dropItem:coordinator.items.firstObject.dragItem toRowAtIndexPath:destination];
}

@end
