#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern "C" {
#endif

extern BOOL LLBEnabled;
extern CGFloat LLBLiftAmount;
extern BOOL LLBDockButtonsEnabled;
extern NSArray<NSDictionary *> *LLBDockButtons;
// The center- and right-aligned button groups; LLBDockButtons is the
// left-aligned one.
extern NSArray<NSDictionary *> *LLBDockButtonsCenter;
extern NSArray<NSDictionary *> *LLBDockButtonsRight;
// Square dock buttons: side length cap (the effective side is the smaller
// of this and the dock height) and the gap between neighbouring buttons.
extern CGFloat LLBDockButtonSize;
extern CGFloat LLBDockButtonSpacing;
// Horizontal inset of the button groups from the bar's left / right edges.
extern CGFloat LLBDockBarMargin;
// SF Symbol weight of the button icons, as an index into the ordered
// weight list (0 = Ultralight … 8 = Black, default 2 = Light).
extern NSInteger LLBDockSymbolWeightIndex;

void LLBReloadPrefs(void);
void LLBStartObservingPrefs(void);

#ifdef __cplusplus
}
#endif
