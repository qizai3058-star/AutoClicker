#import <UIKit/UIKit.h>
#include <IOKit/hid/IOHIDEvent.h>
#include <IOKit/hid/IOHIDEventSystemClient.h>

// 声明私有 IOHIDEvent 方法
extern "C" {
    IOHIDEventRef IOHIDEventCreateDigitizerEvent(
        CFAllocatorRef allocator, 
        AbsoluteTime timeStamp, 
        IOHIDEventOptionBits options, 
        IOHIDDigitizerEventMask eventMask, 
        IOHIDDigitizerTransducerType transducerType, 
        uint32_t entryID, 
        uint32_t quality, 
        uint32_t density, 
        CGFloat x, 
        CGFloat y, 
        CGFloat z, 
        CGFloat pressure, 
        CGFloat twist, 
        Boolean range, 
        Boolean touch, 
        IOHIDEventOptionBits eventOptions
    );

    IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
    void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
}

// 悬浮窗与点击逻辑实现
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

    // 获取悬浮窗当前在屏幕上的坐标（即模拟点击的位置）
    CGPoint point = [self.clickButton.superview convertPoint:self.clickButton.center toView:nil];

    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (client) {
        AbsoluteTime ts = mach_absolute_time();
        
        // 模拟按下
        IOHIDEventRef down = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, ts, 3, 0, 1, 1, 0, 0, point.x, point.y, 0, 1.0, 0, 1, 1, 0);
        if (down) {
            IOHIDEventSystemClientDispatchEvent(client, down);
            CFRelease(down);
        }

        // 模拟抬起
        AbsoluteTime upts = mach_absolute_time();
        IOHIDEventRef up = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, upts, 3, 0, 1, 1, 0, 0, point.x, point.y, 0, 0, 0, 0, 0, 0);
        if (up) {
            IOHIDEventSystemClientDispatchEvent(client, up);
            CFRelease(up);
        }

        CFRelease(client);
    }

    // 循环点击间隔（秒）
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
