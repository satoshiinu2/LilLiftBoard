#import "LLBActionPickerController.h"
#import "LLBActionCatalog.h"

@interface LLBActionPickerController () <UITextFieldDelegate>
@property (nonatomic, assign) LLBAction selectedAction;
@property (nonatomic, copy) NSString *initialText;
@property (nonatomic, copy) LLBActionPickerCompletion completion;
@property (nonatomic, weak) UITextField *textField;
@end

@implementation LLBActionPickerController

- (instancetype)initWithAction:(LLBAction)action text:(NSString *)text completion:(LLBActionPickerCompletion)completion {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _selectedAction = LLBIsValidAction(action) ? action : LLBActionCopy;
        _initialText = [text copy];
        _completion = [completion copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Action";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    [self updateDoneButton];
}

// Done is only needed where a selection alone does not finish: the
// edit flow, and Insert Text (whose text still has to be typed) in the
// add flow. Everywhere else in the add flow a tap finishes at once.
- (void)updateDoneButton {
    BOOL needsDone = !self.addsImmediately || self.selectedAction == LLBActionInsertText;
    if (needsDone) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)finish {
    NSString *text = nil;
    if (self.selectedAction == LLBActionInsertText) {
        text = self.textField.text ?: self.initialText;
        if (text.length == 0) {
            text = nil;
        }
    }
    if (self.completion) {
        self.completion(self.selectedAction, text);
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)done {
    [self finish];
}

- (void)cancel {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.selectedAction == LLBActionInsertText ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)LLBAllActions().count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 1 ? @"Text to Insert" : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0 && self.selectedAction == LLBActionInsertText) {
        return @"Types the text below at the cursor. A single symbol works too — just type it here with the keyboard.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TextCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TextCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UITextField *field = [[UITextField alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 16.0, 0.0)];
            field.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            field.placeholder = @"Text";
            field.returnKeyType = UIReturnKeyDone;
            field.delegate = self;
            [cell.contentView addSubview:field];
            self.textField = field;
        }
        self.textField.text = self.initialText;
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ActionCell"];
    }
    LLBAction action = (LLBAction)LLBAllActions()[(NSUInteger)indexPath.row].integerValue;
    cell.textLabel.text = LLBActionTitle(action);
    cell.accessoryType = action == self.selectedAction ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0) {
        return;
    }
    if (self.textField) {
        self.initialText = self.textField.text;
    }
    self.selectedAction = (LLBAction)LLBAllActions()[(NSUInteger)indexPath.row].integerValue;
    if (self.addsImmediately && self.selectedAction != LLBActionInsertText) {
        [self finish];
        return;
    }
    [self updateDoneButton];
    [tableView reloadData];
}

#pragma mark - Text field

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
