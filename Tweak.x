#import <UIKit/UIKit.h>

// 声明控制面板控制器
@interface AutoClickerPanelController : UIViewController
@property (nonatomic, strong) UIButton *startStopButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) NSTimer *clickTimer;
@end

@implementation AutoClickerPanelController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 面板背景（半透明毛玻璃效果）
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlpha:0.8];
    self.view.layer.cornerRadius = 16;
    self.view.clipsToBounds = YES;
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 200, 30)];
    titleLabel.text = @"🤖 连点器控制面板";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.view addSubview:titleLabel];
    
    // 状态显示
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 200, 25)];
    self.statusLabel.text = @"状态: 已停止";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.statusLabel];
    
    // 开始/停止 切换按钮
    self.startStopButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.startStopButton.frame = CGRectMake(20, 85, 220, 44);
    self.startStopButton.backgroundColor = [UIColor systemBlueColor];
    [self.startStopButton setTitle:@"启动自动点击" forState:UIControlStateNormal];
    [self.startStopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startStopButton.layer.cornerRadius = 8;
    [self.startStopButton addTarget:self action:@selector(toggleClicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startStopButton];
    
    // 关闭面板按钮
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(245, 10, 30, 30);
    [closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
    
    self.isRunning = NO;
}

- (void)toggleClicker {
    self.isRunning = !self.isRunning;
    if (self.isRunning) {
        self.statusLabel.text = @"状态: 正在连点中...";
        self.statusLabel.textColor = [UIColor greenColor];
        [self.startStopButton setTitle:@"停止自动点击" forState:UIControlStateNormal];
        self.startStopButton.backgroundColor = [UIColor systemRedColor];
        
        // 开启定时器模拟连点（每秒点击一次，可根据需要调整时间间隔）
        self.clickTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(performClickAction) userInfo:nil repeats:YES];
        NSLog(@"[AutoClicker] 自动连点已启动");
    } else {
        [self stopClicker];
    }
}

- (void)stopClicker {
    self.isRunning = NO;
    self.statusLabel.text = @"状态: 已停止";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    [self.startStopButton setTitle:@"启动自动点击" forState:UIControlStateNormal];
    self.startStopButton.backgroundColor = [UIColor systemBlueColor];
    
    [self.clickTimer invalidate];
    self.clickTimer = nil;
    NSLog(@"[AutoClicker] 自动连点已停止");
}

- (void)performClickAction {
    // 核心连点触发逻辑（可以在这里加入模拟触摸事件）
    NSLog(@"[AutoClicker] 正在执行一次自动点击...");
}

- (void)hidePanel {
    [self stopClicker];
    // 让面板淡出并隐藏
    [UIView animateWithDuration:0.3 animations:^{
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
}

@end


// 主悬浮球窗口
@interface AutoClickerFloatingWindow : UIWindow
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) AutoClickerPanelController *panelVC;
@end

@implementation AutoClickerFloatingWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 9999;
        self.backgroundColor = [UIColor clearColor];
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        self.rootViewController = rootVC;
        
        // 创建入口悬浮球（像插件精灵一样的浮标）
        self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatingButton.frame = CGRectMake(0, 0, 60, 60);
        self.floatingButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.85];
        [self.floatingButton setTitle:@"🤖" forState:UIControlStateNormal];
        self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:28];
        self.floatingButton.layer.cornerRadius = 30;
        self.floatingButton.layer.borderWidth = 2;
        self.floatingButton.layer.borderColor = [UIColor systemBlueColor].CGColor;
        self.floatingButton.clipsToBounds = YES;
        
        // 绑定点击事件：呼出控制面板
        [self.floatingButton addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加拖动手势，让悬浮球可以随意拖动位置
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.floatingButton addGestureRecognizer:pan];
        
        [rootVC.view addSubview:self.floatingButton];
        
        self.hidden = NO;
        [self makeKeyAndVisible];
        NSLog(@"[AutoClicker] 插件精灵悬浮球已成功加载！");
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *__kindof)sender {
    CGPoint translation = [sender translationInView:self];
    CGPoint center = self.center;
    self.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [sender setTranslation:CGPointZero inView:self];
}

- (void)openPanel {
    if (!self.panelVC || !self.panelVC.view.superview) {
        self.panelVC = [[AutoClickerPanelController alloc] init];
        self.panelVC.view.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - 285) / 2, 200, 285, 150);
        
        // 将面板加到当前窗口的根视图上
        [self.rootViewController.view addSubview:self.panelVC.view];
        [self.rootViewController addChildViewController:self.panelVC];
        
        // 弹出动画
        self.panelVC.view.transform = CGAffineTransformMakeScale(0.7, 0.7);
        self.panelVC.view.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            self.panelVC.view.transform = CGAffineTransformIdentity;
            self.panelVC.view.alpha = 1.0;
        }];
    }
}

@end

static AutoClickerFloatingWindow *sharedWindow = nil;

%ctor {
    NSLog(@"[AutoClicker] 插件精灵模块开始初始化...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!sharedWindow) {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            // 默认放在屏幕右侧中部
            CGRect rect = CGRectMake(screenWidth - 70, screenHeight / 2 - 30, 60, 60);
            sharedWindow = [[AutoClickerFloatingWindow alloc] initWithFrame:rect];
        }
    });
}
