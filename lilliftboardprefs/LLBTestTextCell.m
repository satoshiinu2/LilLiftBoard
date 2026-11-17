#import "LLBTestTextCell.h"

static NSString *const LLBTestSampleText =
    @"The quick brown fox jumps over the lazy dog.\n"
    @"Pack my box with five dozen liquor jugs.\n"
    @"0123456789 - select, copy, paste, move the cursor.";

@interface LLBTestTextCell ()
@property (nonatomic, strong) UITextView *textView;
@end

@implementation LLBTestTextCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _textView = [[UITextView alloc] initWithFrame:CGRectZero];
        _textView.text = LLBTestSampleText;
        _textView.font = [UIFont systemFontOfSize:15];
        _textView.textColor = [UIColor labelColor];
        _textView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        _textView.layer.cornerRadius = 8;
        _textView.textContainerInset = UIEdgeInsetsMake(8, 6, 8, 6);
        [self.contentView addSubview:_textView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.textView.frame = CGRectInset(self.contentView.bounds, 16, 8);
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    // No-op on purpose: the field is a scratch area, so never load a
    // value into it or reset what the user has typed.
}

@end
