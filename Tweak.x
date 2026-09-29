#import <UIKit/UIKit.h>

@interface AutoClickerWindow : UIWindow
@property (nonatomic, strong) UIButton *clickButton;
@property (nonatomic, assign) BOOL isClicking;
@end

@implementation AutoClickerWindow

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // 1. 设置极高的窗口层级，确保凌驾于支付宝所有原生界面之上
        self.windowLevel = UIWindowLevelAlert + 9999;
        self.backgroundColor = [UIColor clearColor];
        
        // 2. 【核心修复】iOS 16 必须赋予根视图控制器，否则窗口无法渲染！
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        self.rootViewController = rootVC;

        // 3. 创建悬浮按钮（稍微加大 Window 尺寸以容纳和响应点击）
        self.clickButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.clickButton.frame = CGRectMake(0, 0, 60, 60);
        self.clickButton.backgroundColor = [UIColor systemBlueColor];
        [self.clickButton setTitle:@"点击" forState:UIControlStateNormal];
        [self.clickButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.clickButton.layer.cornerRadius = 30;
        self.clickButton.clipsToBounds = YES;
        
        [self.clickButton addTarget:self action:@selector(startClicking) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.clickButton addGestureRecognizer:pan];

        // 将按钮加到根控制器的视图上
        [rootVC.view addSubview:self.clickButton];
        
        // 4. 【核心修复】显式让窗口可见并成为 KeyWindow
        self.hidden = NO;
        [self makeKeyAndVisible];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    CGPoint center = self.clickButton.center;
    self.clickButton.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self];
}

- (void)startClicking {
    self.isClicking = !self.isClicking;
    if (self.isClicking) {
        self.clickButton.backgroundColor = [UIColor systemRedColor];
        [self.clickButton setTitle:@"停止" forState:UIControlStateNormal];
        [self performSelector:@selector(simulateClickLoop) withObject:nil afterDelay:0.5];
    } else {
        self.clickButton.backgroundColor = [UIColor systemBlueColor];
        [self.clickButton setTitle:@"点击" forState:UIControlStateNormal];
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
}

- (void)simulateClickLoop {
    if (!self.isClicking) return;

    CGPoint point = [self.clickButton.superview convertPoint:self.clickButton.center toView:nil];
    NSLog(@"[AutoClicker] 触发点击位置: x=%.1f, y=%.1f", point.x, point.y);

    [self performSelector:@selector(simulateClickLoop) withObject:nil afterDelay:1.0];
}

@end

static AutoClickerWindow *floatingWindow = nil;

%ctor {
    // 延迟 3 秒，等支付宝主界面完全加载渲染完毕后再创建
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!floatingWindow) {
            // 针对 iPhone 14 Pro Max 屏幕右侧偏下安全区域计算初始坐标 (宽 430 x 高 932)
            // 初始放在距离右侧 20pt，距离底部 220pt 的位置，绝对不会被灵动岛或手势条挡住
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            
            CGRect winRect = CGRectMake(screenWidth - 80, screenHeight - 250, 60, 60);
            floatingWindow = [[AutoClickerWindow alloc] initWithFrame:winRect];
        }
    });
}
