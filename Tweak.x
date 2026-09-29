#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>

#define kSavedScriptKey @"AutoClicker_SavedScript"
#define kAutoRunScriptKey @"AutoClicker_AutoRunScript"
#define kLoopScriptKey @"AutoClicker_LoopScript"

// 声明 IOKit 底层私有 API（实现硬件级触控，绕过支付宝拦截）
typedef uint32_t IOHIDDigitizerTransducerType;
typedef uint32_t IOHIDEventOptionBits;

extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(
    CFAllocatorRef allocator,
    uint64_t timeStamp,
    IOHIDDigitizerTransducerType type,
    uint32_t index,
    uint32_t identity,
    uint32_t eventMask,
    uint32_t buttonMask,
    float x,
    float y,
    float z,
    float tipPressure,
    float barrelPressure,
    Boolean range,
    Boolean touch,
    IOHIDEventOptionBits options
);

typedef struct __IOHIDEventSystemClient * IOHIDEventSystemClientRef;
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);

@interface TweakScriptEngine : NSObject
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL autoRunOnLaunch;
@property (nonatomic, assign) BOOL loopPlayback;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recordedSteps;
@property (nonatomic, strong) NSDate *lastTouchTime;
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, strong) UIButton *floatButton;

+ (instancetype)sharedInstance;
- (void)setupFloatWindow;
- (void)recordTouchAtPoint:(CGPoint)pt;
- (BOOL)isPointInFloatWindow:(CGPoint)pt window:(UIWindow *)window;
- (void)checkAndAutoStart;
- (void)startPlayback;
@end

// Hook UIWindow 用于录制真实触摸点
@interface UIWindow (ScriptTouchHook)
@end

@implementation UIWindow (ScriptTouchHook)
- (void)ac_sendEvent:(UIEvent *)event {
    if (event.type == UIEventTypeTouches) {
        TweakScriptEngine *engine = [TweakScriptEngine sharedInstance];
        if (engine.isRecording) {
            NSSet<UITouch *> *touches = [event touchesForWindow:self];
            for (UITouch *touch in touches) {
                if (touch.phase == UITouchPhaseEnded) {
                    CGPoint pt = [touch locationInView:self];
                    if (![engine isPointInFloatWindow:pt window:self]) {
                        [engine recordTouchAtPoint:pt];
                    }
                }
            }
        }
    }
    [self ac_sendEvent:event];
}
@end

@implementation TweakScriptEngine

+ (instancetype)sharedInstance {
    static TweakScriptEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TweakScriptEngine alloc] init];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *saved = [defaults arrayForKey:kSavedScriptKey];
        instance.recordedSteps = saved ? [saved mutableCopy] : [NSMutableArray array];
        instance.autoRunOnLaunch = [defaults boolForKey:kAutoRunScriptKey];
        instance.loopPlayback = [defaults boolForKey:kLoopScriptKey];
        instance.isRecording = NO;
        instance.isPlaying = NO;
    });
    return instance;
}

- (UIWindow *)getActiveWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow && w != self.floatWindow) return w;
                }
            }
        }
    }
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w != self.floatWindow && !w.hidden) return w;
    }
    return nil;
}

- (void)presentAlertController:(UIAlertController *)alert {
    UIWindow *appWindow = [self getActiveWindow];
    UIViewController *topVC = appWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    if (topVC && ![topVC isKindOfClass:[UIAlertController class]]) {
        [topVC presentViewController:alert animated:YES completion:nil];
    }
}

- (void)saveScriptToDisk {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.recordedSteps forKey:kSavedScriptKey];
    [defaults setBool:self.autoRunOnLaunch forKey:kAutoRunScriptKey];
    [defaults setBool:self.loopPlayback forKey:kLoopScriptKey];
    [defaults synchronize];
}

- (BOOL)isPointInFloatWindow:(CGPoint)pt window:(UIWindow *)window {
    if (!self.floatWindow || self.floatWindow.hidden) return NO;
    CGRect floatFrame = [window convertRect:self.floatWindow.frame fromWindow:self.floatWindow];
    return CGRectContainsPoint(floatFrame, pt);
}

- (void)setupFloatWindow {
    if (self.floatWindow) return;
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    self.floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(sw - 65, 200, 55, 55)];
    self.floatWindow.windowLevel = UIWindowLevelAlert + 1000;
    self.floatWindow.backgroundColor = [UIColor clearColor];

    UIViewController *vc = [[UIViewController alloc] init];
    self.floatWindow.rootViewController = vc;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                self.floatWindow.windowScene = (UIWindowScene *)scene;
                break;
            }
        }
    }

    self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatButton.frame = CGRectMake(0, 0, 55, 55);
    self.floatButton.layer.cornerRadius = 27.5;
    self.floatButton.layer.masksToBounds = YES;
    self.floatButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    [self.floatButton setTitle:@"🤖精灵" forState:UIControlStateNormal];
    self.floatButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.floatButton addTarget:self action:@selector(floatButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatButton addGestureRecognizer:pan];

    [vc.view addSubview:self.floatButton];
    self.floatWindow.hidden = NO;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.floatWindow];
    CGRect f = self.floatWindow.frame;
    f.origin.x += translation.x;
    f.origin.y += translation.y;
    self.floatWindow.frame = f;
    [pan setTranslation:CGPointZero inView:self.floatWindow];
}

- (void)updateFloatButtonTitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isRecording) {
            [self.floatButton setTitle:@"🔴录制" forState:UIControlStateNormal];
            self.floatButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.85];
        } else if (self.isPlaying) {
            [self.floatButton setTitle:@"▶️运行" forState:UIControlStateNormal];
            self.floatButton.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.85];
        } else {
            [self.floatButton setTitle:@"🤖精灵" forState:UIControlStateNormal];
            self.floatButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        }
    });
}

- (void)floatButtonTapped {
    NSString *title = @"支付宝硬件级点击控制器";
    NSString *msg = [NSString stringWithFormat:@"已录制: %lu 步\n自启状态: %@\n循环播放: %@",
                     (unsigned long)self.recordedSteps.count,
                     self.autoRunOnLaunch ? @"已开启" : @"已关闭",
                     self.loopPlayback ? @"已开启" : @"已关闭"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];

    if (self.isRecording) {
        [alert addAction:[UIAlertAction actionWithTitle:@"⏹ 停止录制并保存" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            self.isRecording = NO; [self saveScriptToDisk]; [self updateFloatButtonTitle];
        }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:@"🔴 开始录制新动作" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self.recordedSteps removeAllObjects]; self.isRecording = YES; self.lastTouchTime = [NSDate date]; [self updateFloatButtonTitle];
        }]];
    }

    if (self.isPlaying) {
        [alert addAction:[UIAlertAction actionWithTitle:@"⏹ 停止运行" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            self.isPlaying = NO; [self updateFloatButtonTitle];
        }]];
    } else if (self.recordedSteps.count > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:@"▶️ 立即运行一次" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self startPlayback];
        }]];
    }

    NSString *autoTitle = self.autoRunOnLaunch ? @"⚡️ 启动自启: 【已开启】" : @"⚡️ 启动自启: 【已关闭】";
    [alert addAction:[UIAlertAction actionWithTitle:autoTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        self.autoRunOnLaunch = !self.autoRunOnLaunch; [self saveScriptToDisk]; [self floatButtonTapped];
    }]];

    NSString *loopTitle = self.loopPlayback ? @"🔄 循环播放: 【已开启】" : @"🔄 循环播放: 【已关闭】";
    [alert addAction:[UIAlertAction actionWithTitle:loopTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        self.loopPlayback = !self.loopPlayback; [self saveScriptToDisk]; [self floatButtonTapped];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlertController:alert];
}

- (void)startPlayback {
    if (self.recordedSteps.count == 0) return;
    self.isPlaying = YES;
    [self updateFloatButtonTitle];
    [self executeStepAtIndex:0];
}

- (void)executeStepAtIndex:(NSUInteger)index {
    if (!self.isPlaying) return;
    if (index >= self.recordedSteps.count) {
        if (self.loopPlayback) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.isPlaying) [self executeStepAtIndex:0];
            });
        } else {
            self.isPlaying = NO;
            [self updateFloatButtonTitle];
        }
        return;
    }

    NSDictionary *step = self.recordedSteps[index];
    double delay = [step[@"delay"] doubleValue];
    CGFloat x = [step[@"x"] floatValue];
    CGFloat y = [step[@"y"] floatValue];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isPlaying) return;
        [self performHardwareClickAtPoint:CGPointMake(x, y)];
        [self executeStepAtIndex:index + 1];
    });
}

// 核心硬件级点击（穿透支付宝防作弊与 H5 限制）
- (void)performHardwareClickAtPoint:(CGPoint)point {
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    float nx = point.x / sw;
    float ny = point.y / sh;

    uint64_t ts = mach_absolute_time();
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);

    // Touch Down
    IOHIDEventRef down = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, ts, 3, 0, 1, 1 << 0, 0, nx, ny, 0, 1.0, 0, 1, 1, 0);
    if (down && client) {
        IOHIDEventSystemClientDispatchEvent(client, down);
        CFRelease(down);
    }

    // Touch Up
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        uint64_t upTs = mach_absolute_time();
        IOHIDEventRef up = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, upTs, 3, 0, 1, 0, 0, nx, ny, 0, 0, 0, 0, 0, 0);
        if (up && client) {
            IOHIDEventSystemClientDispatchEvent(client, up);
            CFRelease(up);
            CFRelease(client);
        }
    });
}

- (void)recordTouchAtPoint:(CGPoint)pt {
    NSDate *now = [NSDate date];
    NSTimeInterval delay = [now timeIntervalSinceDate:self.lastTouchTime];
    self.lastTouchTime = now;
    if (self.recordedSteps.count == 0 && delay > 2.0) delay = 1.0;

    [self.recordedSteps addObject:@{@"delay": @(delay), @"x": @(pt.x), @"y": @(pt.y)}];
}

- (void)checkAndAutoStart {
    [self setupFloatWindow];
    if (self.autoRunOnLaunch && self.recordedSteps.count > 0 && !self.isPlaying) {
        [self startPlayback];
    }
}
@end

// Logos 钩子：绑定支付宝启动与激活生命周期
%hook UIApplication
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[TweakScriptEngine sharedInstance] checkAndAutoStart];
    });
}
%end
