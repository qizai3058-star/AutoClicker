#import <UIKit/UIKit.h>

@interface AutoClickerWindow : UIWindow
@property (nonatomic, strong) UIButton *clickButton;
@property (nonatomic, assign) BOOL isClicking;
@end

@implementation AutoClickerWindow

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 9999;
        self.hidden = NO;
        self.backgroundColor = [UIColor clearColor];

        self.clickButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.clickButton.frame = CGRectMake(0, 0, 60, 60);
        self.clickButton.backgroundColor = [UIColor systemBlueColor];
        [self.clickButton setTitle:@"点击" forState:UIControlStateNormal];
        [self.clickButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.clickButton.layer.cornerRadius = 30;
        
        [self.clickButton addTarget:self action:@selector(startClicking) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.clickButton addGestureRecognizer:pan];

        [self addSubview:self.clickButton];
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

    // 获取按钮在屏幕上的中心坐标
    CGPoint point = [self.clickButton.superview convertPoint:self.clickButton.center toView:nil];
    
    // 打印日志方便后续调试
    NSLog(@"[AutoClicker] 触发点击位置: x=%.1f, y=%.1f", point.x, point.y);

    // 循环间隔
    [self performSelector:@selector(simulateClickLoop) withObject:nil afterDelay:1.0];
}

@end

static AutoClickerWindow *floatingWindow = nil;

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!floatingWindow) {
            floatingWindow = [[AutoClickerWindow alloc] initWithFrame:CGRectMake(100, 100, 60, 60)];
        }
    });
}
