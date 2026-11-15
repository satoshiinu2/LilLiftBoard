#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

extern BOOL LLBEnabled;
extern CGFloat LLBLiftAmount;

void LLBReloadPrefs(void);
void LLBStartObservingPrefs(void);

#ifdef __cplusplus
}
#endif
