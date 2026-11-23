#import "DockBar.h"
#import "Prefs.h"
#import "Actions.h"
#import "LLBActionCatalog.h"
#import <objc/runtime.h>

static const void *LLBDockBarKey = &LLBDockBarKey;
static const void *LLBHostBarKey = &LLBHostBarKey;
static const void *LLBWindowBarKey = &LLBWindowBarKey;
static const CGFloat LLBMinimumLiftForButtons = 20.0;
static const CGFloat LLBMinimumDockHeight = 24.0;
// Horizontal travel (pt) before a touch on the bar counts as a caret
// drag instead of a tap. A press that has already fired (popup open)
// is exempt: the scrub recognizer refuses to begin while a popup is
// up, so the same finger can slide to a popup item instead.
static const CGFloat LLBScrubThreshold = 8.0;
static const CGFloat LLBScrubPointsPerCharacter = 10.0;

// A pan recognizer that stays Possible — leaving taps and long
// presses untouched — until the touch has travelled past the scrub
// threshold horizontally. A vertically dominant travel fails it, so
// only deliberate horizontal drags are claimed.
@interface LLBScrubPanGestureRecognizer : UIPanGestureRecognizer
@end

@interface LLBScrubPanGestureRecognizer ()
@property (nonatomic) CGPoint startLocation;
@property (nonatomic) BOOL passedThreshold;
@end

@implementation LLBScrubPanGestureRecognizer

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.startLocation = [touches.anyObject locationInView:self.view];
    self.passedThreshold = NO;
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.passedThreshold && self.state == UIGestureRecognizerStatePossible) {
        CGPoint location = [touches.anyObject locationInView:self.view];
        CGFloat dx = location.x - self.startLocation.x;
        CGFloat dy = location.y - self.startLocation.y;
        if (fabs(dy) >= LLBScrubThreshold && fabs(dy) > fabs(dx)) {
            self.state = UIGestureRecognizerStateFailed;
            return;
        }
        if (fabs(dx) < LLBScrubThreshold) {
            return;
        }
        self.passedThreshold = YES;
    }
    [super touchesMoved:touches withEvent:event];
}

- (void)reset {
    self.passedThreshold = NO;
    [super reset];
}

@end

@interface LLBDockBar () <UIGestureRecognizerDelegate>
@property (nonatomic) BOOL isHostBar;
@property (nonatomic) NSUInteger leftButtonCount;
@property (nonatomic) NSUInteger centerButtonCount;
@property (nonatomic, copy) NSString *syncSignature;
@property (nonatomic, strong) NSArray<NSDictionary *> *buttonConfigs;
@property (nonatomic, strong) UIView *popupOverlay;
@property (nonatomic, copy) NSArray<NSDictionary *> *popupItems;
@property (nonatomic, strong) NSArray<UIButton *> *popupButtons;
@property (nonatomic, weak) UIButton *popupAnchor;
@property (nonatomic, weak) UIButton *popupHighlighted;
@property (nonatomic) BOOL scrubbing;
@property (nonatomic) NSInteger scrubCharacters;
@end

@implementation LLBDockBar

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        LLBScrubPanGestureRecognizer *scrub = [[LLBScrubPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleScrubPan:)];
        scrub.maximumNumberOfTouches = 1;
        scrub.delegate = self;
        [self addGestureRecognizer:scrub];
    }
    return self;
}

+ (NSHashTable<LLBDockBar *> *)liveBars {
    static NSHashTable *bars = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bars = [NSHashTable weakObjectsHashTable];
    });
    return bars;
}

+ (void)syncWithDockView:(UIView *)dockView {
    if (!dockView) {
        return;
    }
    LLBDockBar *bar = objc_getAssociatedObject(dockView, LLBDockBarKey);
    if (!bar) {
        bar = [[LLBDockBar alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(dockView, LLBDockBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [dockView addSubview:bar];
        [[self liveBars] addObject:bar];
    }
    [bar syncInDockView:dockView];
}

+ (void)syncWithHostView:(UIView *)hostView {
    if (!hostView) {
        return;
    }
    LLBDockBar *bar = objc_getAssociatedObject(hostView, LLBHostBarKey);
    if (!bar) {
        bar = [[LLBDockBar alloc] initWithFrame:CGRectZero];
        bar.isHostBar = YES;
        objc_setAssociatedObject(hostView, LLBHostBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [hostView addSubview:bar];
        [[self liveBars] addObject:bar];
    }
    [bar syncInHostView:hostView];
}

+ (void)syncWithWindow:(UIWindow *)window {
    if (!window) {
        return;
    }
    LLBDockBar *bar = objc_getAssociatedObject(window, LLBWindowBarKey);
    if (!bar) {
        bar = [[LLBDockBar alloc] initWithFrame:CGRectZero];
        bar.isHostBar = YES;
        objc_setAssociatedObject(window, LLBWindowBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [window addSubview:bar];
        [[self liveBars] addObject:bar];
    }
    [bar syncInHostView:window];
}

+ (void)syncKeyboardWindows {
    Class remoteKeyboardWindow = NSClassFromString(@"UIRemoteKeyboardWindow");
    Class keyboardWindowClass = remoteKeyboardWindow ?: NSClassFromString(@"UITextEffectsWindow");
    if (!keyboardWindowClass) {
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // The scene-based window lists cannot be used here: the keyboard
    // window is exactly the window that may belong to no scene.
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if ([window isKindOfClass:keyboardWindowClass]) {
            [self syncWithWindow:window];
        }
    }
#pragma clang diagnostic pop
}

+ (void)refreshAllBars {
    for (LLBDockBar *bar in [[self liveBars] allObjects]) {
        bar.syncSignature = nil;
        if (bar.isHostBar) {
            [bar syncInHostView:bar.superview];
        } else {
            [bar syncInDockView:bar.superview];
        }
    }
}

- (void)dealloc {
    [self.popupOverlay removeFromSuperview];
}

#pragma mark - Layout

// Portrait check. This must not consult the keyboard window: it has no
// window scene of its own (its interfaceOrientation reads Unknown), and
// its bounds are the keyboard's own rectangle — wider than tall even in
// portrait — so the old fallback read every portrait keyboard as
// landscape and hid the bar in every host. Ask the app's active scene
// instead, with the screen bounds as the last resort.
- (BOOL)isPortrait {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            return UIInterfaceOrientationIsPortrait(((UIWindowScene *)scene).interfaceOrientation);
        }
    }
    CGRect bounds = [UIScreen mainScreen].bounds;
    return bounds.size.height >= bounds.size.width;
}

// The color of the characters on the keyboard's own keys. The keyboard
// layout view (the key plane) is the part of the hierarchy whose traits
// carry the keyboard's appearance — the dock and the host views keep
// the host app's traits instead, which visibly mismatches in places
// like Spotlight (dark surroundings, light keyboard). Resolve the
// label color against the layout's traits, falling back to the bar's
// own traits when no layout view is found.
- (UIView *)findViewOfClassNamed:(NSString *)name inView:(UIView *)view {
    if ([NSStringFromClass(view.class) isEqualToString:name]) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *found = [self findViewOfClassNamed:name inView:subview];
        if (found) {
            return found;
        }
    }
    return nil;
}

- (UIColor *)keyTextColor {
    UIView *root = self;
    while (root.superview) {
        root = root.superview;
    }
    UIView *layout = [self findViewOfClassNamed:@"UIKeyboardLayoutStar" inView:root];
    UITraitCollection *traits = layout ? layout.traitCollection : self.traitCollection;
    return [[UIColor labelColor] resolvedColorWithTraitCollection:traits];
}

- (NSUInteger)totalButtonCount {
    return LLBDockButtons.count + LLBDockButtonsCenter.count + LLBDockButtonsRight.count;
}

- (void)syncInDockView:(UIView *)dockView {
    if (!dockView) {
        return;
    }
    BOOL show = LLBEnabled && LLBDockButtonsEnabled && [self totalButtonCount] > 0
        && LLBLiftAmount >= LLBMinimumLiftForButtons
        && dockView.bounds.size.height >= LLBMinimumDockHeight
        && [self isPortrait];
    if (!show) {
        self.hidden = YES;
        [self dismissPopup];
        return;
    }

    // On the target devices (Home-button iPhones) the globe and dictation
    // keys live in the keyboard's bottom key row, not in the dock, so the
    // whole dock width is free space: span it and let layoutButtons center.
    CGRect frame = CGRectMake(0, 0, dockView.bounds.size.width, dockView.bounds.size.height);
    if (!CGRectEqualToRect(self.frame, frame)) {
        self.frame = frame;
    }
    self.hidden = NO;
    [dockView bringSubviewToFront:self];
    [self hideOtherHostBars];

    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%.1f|%.1f|%.1f|%ld", LLBDockButtons, LLBDockButtonsCenter, LLBDockButtonsRight, NSStringFromCGRect(frame), LLBDockButtonSize, LLBDockButtonSpacing, LLBDockBarMargin, (long)LLBDockSymbolWeightIndex];
    if (![signature isEqualToString:self.syncSignature]) {
        self.syncSignature = signature;
        [self rebuildButtons];
    }
    UIColor *tint = [self keyTextColor];
    for (UIButton *button in self.subviews) {
        button.tintColor = tint;
    }
}

#pragma mark - Host fallback

// On Home-button iPhones the system may not give UIKeyboardDockView a
// usable frame at all (the globe / dictation keys stay in the key row and
// the lifted space below the keys belongs to no dock view), so a bar
// hosted only by the dock view never appears there. This fallback hosts
// the bar in the bottom LLBLiftAmount of a container that spans the
// whole keyboard — the peripheral host view, or the keyboard window
// itself — where the lift leaves exactly that much empty background.
// It stays hidden while any other bar is already visible in the same
// container, so the hosts never stack two bars.
- (void)syncInHostView:(UIView *)hostView {
    if (!hostView) {
        return;
    }
    BOOL show = LLBEnabled && LLBDockButtonsEnabled && [self totalButtonCount] > 0
        && LLBLiftAmount >= LLBMinimumLiftForButtons
        && hostView.bounds.size.height > LLBLiftAmount
        && [self isPortrait]
        && ![self.class hasVisibleBarInView:hostView excluding:self];
    if (!show) {
        self.hidden = YES;
        [self dismissPopup];
        return;
    }

    CGRect frame = CGRectMake(0, hostView.bounds.size.height - LLBLiftAmount, hostView.bounds.size.width, LLBLiftAmount);
    if (!CGRectEqualToRect(self.frame, frame)) {
        self.frame = frame;
    }
    self.hidden = NO;
    [hostView bringSubviewToFront:self];

    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%.1f|%.1f|%.1f|%ld", LLBDockButtons, LLBDockButtonsCenter, LLBDockButtonsRight, NSStringFromCGRect(frame), LLBDockButtonSize, LLBDockButtonSpacing, LLBDockBarMargin, (long)LLBDockSymbolWeightIndex];
    if (![signature isEqualToString:self.syncSignature]) {
        self.syncSignature = signature;
        [self rebuildButtons];
    }
    UIColor *tint = [self keyTextColor];
    for (UIButton *button in self.subviews) {
        button.tintColor = tint;
    }
}

+ (BOOL)hasVisibleBarInView:(UIView *)root excluding:(LLBDockBar *)excluded {
    for (UIView *subview in root.subviews) {
        if ([subview isKindOfClass:[LLBDockBar class]] && subview != excluded) {
            LLBDockBar *bar = (LLBDockBar *)subview;
            if (!bar.hidden && bar.bounds.size.height > 0) {
                return YES;
            }
        }
        if ([self hasVisibleBarInView:subview excluding:excluded]) {
            return YES;
        }
    }
    return NO;
}

- (void)hideOtherHostBars {
    for (LLBDockBar *bar in [[self.class liveBars] allObjects]) {
        if (bar != self && bar.isHostBar && bar.window == self.window) {
            bar.hidden = YES;
            [bar dismissPopup];
        }
    }
}

#pragma mark - Buttons

- (void)rebuildButtons {
    [self dismissPopup];
    for (UIView *subview in [self.subviews copy]) {
        [subview removeFromSuperview];
    }
    // One flattened list (left, center, then right group) backs the tags
    // and the tap / popup handling; layoutButtons splits it back into
    // the three anchored groups.
    self.leftButtonCount = LLBDockButtons.count;
    self.centerButtonCount = LLBDockButtonsCenter.count;
    self.buttonConfigs = [[LLBDockButtons arrayByAddingObjectsFromArray:LLBDockButtonsCenter] arrayByAddingObjectsFromArray:LLBDockButtonsRight];
    for (NSUInteger i = 0; i < self.buttonConfigs.count; i++) {
        NSDictionary *config = self.buttonConfigs[i];
        UIButton *button = [self buttonForItem:config];
        button.tag = (NSInteger)i;
        NSArray *popup = config[@"popup"];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.35;
        // Generous: an early sideways drag is claimed by the scrub
        // recognizer (which cancels this one) well before the press
        // fires, and after the popup opens the finger must be free to
        // slide up to a popup item for flick selection.
        longPress.allowableMovement = 300.0;
        longPress.enabled = [popup isKindOfClass:[NSArray class]] && popup.count > 0;
        [button addGestureRecognizer:longPress];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [tap requireGestureRecognizerToFail:longPress];
        [button addGestureRecognizer:tap];
        [self addSubview:button];
    }
    [self layoutButtons];
}

- (UIButton *)buttonForItem:(NSDictionary *)item {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    LLBAction action = LLBActionFromIdentifier(item[@"action"]);
    NSString *text = item[@"text"];
    UIImage *image = nil;
    NSString *symbol = LLBActionSymbol(action);
    if (symbol) {
        // Explicit point size: the default symbol configuration renders
        // at the surrounding font size, small enough to overlook in the
        // strip even when the button is there. The weight is the
        // Icon Weight setting (index into this ordered list).
        static const UIImageSymbolWeight weights[] = {
            UIImageSymbolWeightUltraLight, UIImageSymbolWeightThin, UIImageSymbolWeightLight,
            UIImageSymbolWeightRegular, UIImageSymbolWeightMedium, UIImageSymbolWeightSemibold,
            UIImageSymbolWeightBold, UIImageSymbolWeightHeavy, UIImageSymbolWeightBlack,
        };
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:weights[LLBDockSymbolWeightIndex]];
        image = [[UIImage systemImageNamed:symbol] imageWithConfiguration:configuration];
    }
    if (image) {
        [button setImage:image forState:UIControlStateNormal];
    }
    BOOL showText = !image || action == LLBActionInsertText;
    if (showText) {
        NSString *title = LLBActionTitle(action);
        if (action == LLBActionInsertText && text.length > 0) {
            title = text.length > 10 ? [[text substringToIndex:10] stringByAppendingString:@"…"] : text;
        }
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    }
    button.accessibilityLabel = LLBActionTitle(action);
    return button;
}

- (void)layoutButtons {
    NSUInteger count = self.subviews.count;
    if (count == 0 || self.bounds.size.width <= 0 || self.bounds.size.height <= 0) {
        return;
    }
    // Buttons are square: the side is capped by the configured size and
    // by the bar height. Within the margin-inset area, the left group is
    // anchored to the left, the right group to the right, and the center
    // group is centered in the space between them; all are centered
    // vertically.
    CGFloat spacing = LLBDockButtonSpacing;
    CGFloat margin = MIN(LLBDockBarMargin, self.bounds.size.width / 2.0);
    CGFloat availableWidth = self.bounds.size.width - 2.0 * margin;
    CGFloat side = MIN(LLBDockButtonSize, self.bounds.size.height);
    if (side * (CGFloat)count + spacing * (CGFloat)(count - 1) > availableWidth) {
        side = (availableWidth - spacing * (CGFloat)(count - 1)) / (CGFloat)count;
        if (side < 0) {
            side = availableWidth / (CGFloat)count;
            spacing = 0;
        }
    }
    CGFloat y = (self.bounds.size.height - side) / 2.0;
    NSUInteger leftCount = MIN(self.leftButtonCount, count);
    NSUInteger centerCount = MIN(self.centerButtonCount, count - leftCount);
    NSUInteger rightCount = count - leftCount - centerCount;
    CGFloat leftWidth = leftCount > 0 ? side * (CGFloat)leftCount + spacing * (CGFloat)(leftCount - 1) : 0;
    CGFloat centerWidth = centerCount > 0 ? side * (CGFloat)centerCount + spacing * (CGFloat)(centerCount - 1) : 0;
    CGFloat rightWidth = rightCount > 0 ? side * (CGFloat)rightCount + spacing * (CGFloat)(rightCount - 1) : 0;

    CGFloat x = margin;
    for (NSUInteger i = 0; i < leftCount; i++) {
        self.subviews[i].frame = CGRectMake(x, y, side, side);
        x += side + spacing;
    }
    x = margin + leftWidth + (availableWidth - leftWidth - rightWidth - centerWidth) / 2.0;
    for (NSUInteger i = leftCount; i < leftCount + centerCount; i++) {
        self.subviews[i].frame = CGRectMake(x, y, side, side);
        x += side + spacing;
    }
    x = self.bounds.size.width - margin - rightWidth;
    for (NSUInteger i = leftCount + centerCount; i < count; i++) {
        self.subviews[i].frame = CGRectMake(x, y, side, side);
        x += side + spacing;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layoutButtons];
}

#pragma mark - Actions

- (void)performItem:(NSDictionary *)item {
    [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
    LLBPerformAction(LLBActionFromIdentifier(item[@"action"]), item[@"text"]);
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    NSUInteger index = (NSUInteger)recognizer.view.tag;
    if (index < self.buttonConfigs.count) {
        [self performItem:self.buttonConfigs[index]];
    }
}

#pragma mark - Caret scrub drag

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if ([recognizer isKindOfClass:[LLBScrubPanGestureRecognizer class]]) {
        // While a popup is open the current touch belongs to flick
        // selection, not to scrubbing.
        return LLBDockDragCursorEnabled && !self.popupOverlay;
    }
    return YES;
}

// The drag's total horizontal travel maps to a character count: the
// threshold is subtracted so the caret does not jump when the drag
// engages, one character per LLBScrubPointsPerCharacter points, with
// the travel past 120 pt counting double so long texts stay reachable
// within the bar's width.
- (NSInteger)scrubCharactersForTranslation:(CGFloat)translation {
    CGFloat travel = fabs(translation) - LLBScrubThreshold;
    if (travel <= 0) {
        return 0;
    }
    CGFloat mapped = travel <= 120.0 ? travel : 120.0 + (travel - 120.0) * 2.0;
    NSInteger characters = (NSInteger)(mapped / LLBScrubPointsPerCharacter);
    return translation < 0 ? -characters : characters;
}

- (void)handleScrubPan:(UIPanGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            // A popup may already be open if the touch started as a
            // long press; the drag takes over from here.
            [self dismissPopup];
            self.scrubbing = YES;
            self.scrubCharacters = 0;
            LLBScrubBegin();
            break;
        case UIGestureRecognizerStateChanged: {
            if (!self.scrubbing) {
                return;
            }
            NSInteger characters = [self scrubCharactersForTranslation:[recognizer translationInView:self].x];
            if (characters != self.scrubCharacters) {
                self.scrubCharacters = characters;
                LLBScrubMoveToOffset(characters);
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            self.scrubbing = NO;
            LLBScrubEnd();
            break;
        default:
            break;
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            NSUInteger index = (NSUInteger)recognizer.view.tag;
            if (index >= self.buttonConfigs.count) {
                return;
            }
            NSArray *items = self.buttonConfigs[index][@"popup"];
            if ([items isKindOfClass:[NSArray class]] && items.count > 0) {
                [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
                [self showPopupWithItems:items anchoredTo:(UIButton *)recognizer.view];
            }
            break;
        }
        case UIGestureRecognizerStateChanged:
            // Flick selection: the finger that opened the popup is
            // sliding over the panel; highlight the item under it.
            if (self.popupOverlay) {
                [self highlightPopupButtonAtPoint:[recognizer locationInView:self.window]];
            }
            break;
        case UIGestureRecognizerStateEnded: {
            if (!self.popupOverlay) {
                return;
            }
            CGPoint point = [recognizer locationInView:self.window];
            UIButton *hit = [self popupButtonAtPoint:point];
            if (hit) {
                NSUInteger index = (NSUInteger)hit.tag;
                NSDictionary *item = index < self.popupItems.count ? self.popupItems[index] : nil;
                [self dismissPopup];
                if (item) {
                    [self performItem:item];
                }
            } else if ([self point:point isInView:self.popupAnchor]) {
                // A plain hold with no slide: leave the popup open so
                // an item can still be tapped.
                [self highlightPopupButton:nil];
            } else {
                // Slid away and released elsewhere: flick cancel.
                [self dismissPopup];
            }
            break;
        }
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self highlightPopupButton:nil];
            break;
        default:
            break;
    }
}

- (BOOL)point:(CGPoint)windowPoint isInView:(UIView *)view {
    if (!view) {
        return NO;
    }
    CGPoint local = [view convertPoint:windowPoint fromView:nil];
    return [view pointInside:local withEvent:nil];
}

- (UIButton *)popupButtonAtPoint:(CGPoint)windowPoint {
    for (UIButton *button in self.popupButtons) {
        if ([self point:windowPoint isInView:button]) {
            return button;
        }
    }
    return nil;
}

- (void)highlightPopupButtonAtPoint:(CGPoint)windowPoint {
    [self highlightPopupButton:[self popupButtonAtPoint:windowPoint]];
}

- (void)highlightPopupButton:(UIButton *)button {
    if (self.popupHighlighted == button) {
        return;
    }
    self.popupHighlighted.highlighted = NO;
    self.popupHighlighted = button;
    self.popupHighlighted.highlighted = YES;
    if (button) {
        [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
    }
}

#pragma mark - Popup

- (void)showPopupWithItems:(NSArray *)items anchoredTo:(UIButton *)anchor {
    [self dismissPopup];
    UIWindow *window = self.window;
    if (!window) {
        return;
    }
    self.popupItems = items;
    self.popupAnchor = anchor;

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor clearColor];
    [overlay addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPopup)]];

    CGFloat buttonWidth = 48.0;
    CGFloat buttonHeight = 44.0;
    CGFloat padding = 6.0;
    CGFloat panelWidth = (CGFloat)items.count * buttonWidth + padding * 2.0;
    CGFloat panelHeight = buttonHeight + padding * 2.0;

    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
    panel.layer.cornerRadius = 12.0;
    panel.clipsToBounds = YES;
    panel.layer.borderWidth = 0.5;
    panel.layer.borderColor = [UIColor separatorColor].CGColor;

    CGRect anchorFrame = [anchor convertRect:anchor.bounds toView:window];
    CGFloat x = CGRectGetMidX(anchorFrame) - panelWidth / 2.0;
    x = MIN(MAX(x, 8.0), window.bounds.size.width - panelWidth - 8.0);
    CGFloat y = CGRectGetMinY(anchorFrame) - panelHeight - 6.0;
    if (y < 8.0) {
        y = CGRectGetMaxY(anchorFrame) + 6.0;
    }
    panel.frame = CGRectMake(x, y, panelWidth, panelHeight);

    NSMutableArray<UIButton *> *popupButtons = [NSMutableArray array];
    for (NSUInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        UIButton *button = [self buttonForItem:item];
        button.tintColor = [self keyTextColor];
        button.frame = CGRectMake(padding + (CGFloat)i * buttonWidth, padding, buttonWidth, buttonHeight);
        button.tag = (NSInteger)i;
        [button addTarget:self action:@selector(handlePopupTap:) forControlEvents:UIControlEventTouchUpInside];
        [panel.contentView addSubview:button];
        [popupButtons addObject:button];
    }
    self.popupButtons = popupButtons;

    [overlay addSubview:panel];
    [window addSubview:overlay];
    self.popupOverlay = overlay;

    panel.transform = CGAffineTransformMakeScale(0.95, 0.95);
    panel.alpha = 0.0;
    [UIView animateWithDuration:0.15 animations:^{
        panel.transform = CGAffineTransformIdentity;
        panel.alpha = 1.0;
    }];
}

- (void)handlePopupTap:(UIButton *)sender {
    NSUInteger index = (NSUInteger)sender.tag;
    NSDictionary *item = index < self.popupItems.count ? self.popupItems[index] : nil;
    [self dismissPopup];
    if (item) {
        [self performItem:item];
    }
}

- (void)dismissPopup {
    [self.popupOverlay removeFromSuperview];
    self.popupOverlay = nil;
    self.popupItems = nil;
    self.popupButtons = nil;
    self.popupAnchor = nil;
    self.popupHighlighted = nil;
}

@end
