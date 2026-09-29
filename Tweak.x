#import <UIKit/UIKit.h>

@interface AutoClickerWindow : UIWindow
@property (nonatomic, strong) UIButton *clickButton;
@end

@implementation AutoClickerWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // 提升到最高窗口层级，凌驾于所有桌面图标和弹窗之上
        self.windowLevel = UIWindowLevelAlert + 9999;
        self.backgroundColor = [UIColor clearColor];
        
        // iOS 16 必须配置根视图控制器
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        self.rootViewController = rootVC;

        // 创建蓝色圆形悬浮按钮
        self.clickButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.clickButton.frame = CGRectMake(0, 0, 60, 60);
        self.clickButton.backgroundColor = [UIColor systemBlueColor];
        [self.clickButton setTitle:@"点击" forState:UIControlStateNormal];
        [self.clickButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.clickButton.layer.cornerRadius = 30;
        self.clickButton.clipsToBounds = YES;
        
        // 添加点击事件测试
        [self.clickButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        [rootVC.view addSubview:self.clickButton];
        
        self.hidden = NO;
        [self makeKeyAndVisible];
        NSLog(@"[AutoClicker] 悬浮窗 UIWindow 已成功创建并显示！");
    }
    return self;
}

- (void)buttonTapped {
    NSLog(@"[AutoClicker] 悬浮按钮被成功点击了！");
}

@end

static AutoClickerWindow *floatingWindow = nil;

%ctor {
    NSLog(@"[AutoClicker] 插件构造函数开始执行！");
    
    // 延迟 3 秒确保 SpringBoard 桌面完全加载完毕
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!floatingWindow) {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            
            // 放置在屏幕右侧偏下位置
            CGRect winRect = CGRectMake(screenWidth - 80, screenHeight - 260, 60, 60);
            floatingWindow = [[AutoClickerWindow alloc] initWithFrame:winRect];
        }
    });
}
