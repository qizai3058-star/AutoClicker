#import <Preferences/Preferences.h>

@interface AutoClickerPrefsListController : PSListController
@end

@implementation AutoClickerPrefsListController
- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end
