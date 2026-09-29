#import <UIKit/UIKit.h>

// 读取偏好设置的路径（对应包名）
#define PLIST_PATH @"/var/mobile/Library/Preferences/com.yourname.autoclicker.plist"

static BOOL isPluginEnabled() {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH];
    id enabled = dict[@"isEnabled"];
    return enabled ? [enabled boolValue] : YES; // 默认开启
}

@interface AutoClickerWindow : UIWindow
@property (nonatomic, strong) UIButton *clickButton;
@end

@implementation AutoClickerWindow
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 9999;
        self.backgroundColor = [UIColor clearColor];
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        self.rootViewController = rootVC;

        self.clickButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.clickButton.frame = CGRectMake(0, 0, 60, 60);
        self.clickButton.backgroundColor = [UIColor systemBlueColor];
        [self.clickButton setTitle:@"点击" forState:UIControlStateNormal];
        [self.clickButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.clickButton.layer.cornerRadius = 30;
        self.clickButton.clipsToBounds = YES;
        
        [rootVC.view addSubview:self.clickButton];
        self.hidden = NO;
        [self makeKeyAndVisible];
    }
    return self;
}
@end

static AutoClickerWindow *floatingWindow = nil;

%ctor {
    // 如果总开关关闭，直接返回不加载
    if (!isPluginEnabled()) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!floatingWindow) {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            CGRect winRect = CGRectMake(screenWidth - 80, screenHeight - 250, 60, 60);
            floatingWindow = [[AutoClickerWindow alloc] initWithFrame:winRect];
        }
    });
}
