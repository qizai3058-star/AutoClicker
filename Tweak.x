#import <UIKit/UIKit.h>

@interface AutoClickerWindow : UIWindow
@property (nonatomic, strong) UIButton *clickButton;
@end

@implementation AutoClickerWindow
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 9999;
        self.backgroundColor = [UIColor clearColor];
        
        // 必须赋予根视图控制器，否则 iOS 16 无法渲染
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        self.rootViewController = rootVC;

        // 创建一个醒目的蓝色悬浮按钮
        self.clickButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.clickButton.frame = CGRectMake(0, 0, 60, 60);
        self.clickButton.backgroundColor = [UIColor systemBlueColor];
        [self.clickButton setTitle:@"点我" forState:UIControlStateNormal];
        [self.clickButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.clickButton.layer.cornerRadius = 30;
        self.clickButton.clipsToBounds = YES;
        
        [rootVC.view addSubview:self.clickButton];
        
        // 显式显示窗口
        self.hidden = NO;
        [self makeKeyAndVisible];
    }
    return self;
}
@end

static AutoClickerWindow *floatingWindow = nil;

%ctor {
    // 延迟 2 秒等桌面完全加载后创建
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!floatingWindow) {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            // 固定放在屏幕右下角显眼的位置
            CGRect winRect = CGRectMake(screenWidth - 90, screenHeight - 280, 60, 60);
            floatingWindow = [[AutoClickerWindow alloc] initWithFrame:winRect];
        }
    });
}
