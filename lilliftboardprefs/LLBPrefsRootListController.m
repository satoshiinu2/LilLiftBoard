#import "LLBPrefsRootListController.h"
#import "LLBDockButtonsController.h"
#include <spawn.h>

@implementation LLBPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)openDockButtons {
    LLBDockButtonsController *controller = [[LLBDockButtonsController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Icon Weight

// Chosen with an action sheet in this controller instead of a
// PSLinkListCell: the standard list-items controller crashed on tap
// with this bundle's specifier (NSNumber values), so the selection is
// kept in plain code here. The stored value is the index into these
// names, matching the tweak's ordered symbol-weight list.
- (NSArray<NSString *> *)iconWeightNames {
    return @[@"Ultralight", @"Thin", @"Light", @"Regular", @"Medium", @"Semibold", @"Bold", @"Heavy", @"Black"];
}

- (NSInteger)iconWeightIndex {
    NSNumber *stored = [[[NSUserDefaults alloc] initWithSuiteName:@"com.satoshiinu.lilliftboard"] objectForKey:@"dockSymbolWeight"];
    NSInteger index = stored ? stored.integerValue : 2;
    return MIN(MAX(index, 0), 8);
}

- (id)iconWeightTitle:(PSSpecifier *)specifier {
    return [self iconWeightNames][(NSUInteger)[self iconWeightIndex]];
}

- (void)selectIconWeight {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Icon Weight" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger current = [self iconWeightIndex];
    [[self iconWeightNames] enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, BOOL *stop) {
        NSString *title = (NSInteger)index == current ? [name stringByAppendingString:@" ✓"] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.satoshiinu.lilliftboard"];
            [defaults setObject:@(index) forKey:@"dockSymbolWeight"];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.satoshiinu.lilliftboard/prefschanged"), NULL, NULL, true);
            [self reloadSpecifiers];
        }]];
    }];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = self.view.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openGitHub {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/satoshiinu2/LilLiftBoard"] options:@{} completionHandler:nil];
}

- (void)respring {
    const char *candidates[] = {
        "/var/jb/usr/bin/sbreload",
        "/usr/bin/sbreload",
        NULL
    };
    for (int i = 0; candidates[i] != NULL; i++) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:@(candidates[i])]) {
            continue;
        }
        pid_t pid;
        char *argv[] = { (char *)candidates[i], NULL };
        extern char **environ;
        if (posix_spawn(&pid, candidates[i], NULL, NULL, argv, environ) == 0) {
            return;
        }
    }
}

@end
