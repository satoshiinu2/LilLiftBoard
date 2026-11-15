#import "LLBPrefsRootListController.h"
#include <spawn.h>

@implementation LLBPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
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
