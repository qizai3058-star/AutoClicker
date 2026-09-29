#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

#define kSavedScriptKey @"AutoClicker_SavedScript"
#define kAutoRunScriptKey @"AutoClicker_AutoRunScript"
#define kLoopScriptKey @"AutoClicker_LoopScript"

static void SwizzleMethod(Class c, SEL origSEL, SEL newSEL) {
    Method origMethod = class_getInstanceMethod(c, origSEL);
    Method newMethod = class_getInstanceMethod(c, newSEL);
    if (class_addMethod(c, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

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
- (void)triggerAntForestAutoClick:(WKWebView *)webView;
@end

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

%hook WKWebView
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[TweakScriptEngine sharedInstance] triggerAntForestAutoClick:self];
        });
    }
}
%end

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
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.hidden) return w;
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
    
    self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatButton.frame = CGRectMake(0, 0, 55, 55);
    self.floatButton.layer.cornerRadius = 27.5;
    self.floatButton.layer.masksToBounds = YES;
    self.floatButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    [self.floatButton setTitle:@"🤖精灵" forState:UIControlStateNormal];
    self.floatButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.floatButton addTarget:self action:@selector(floatButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [vc.view addSubview:self.floatButton];
    self.floatWindow.hidden = NO;
}

- (void)floatButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"巨魔自动化面板" message:@"请选择操作" preferredStyle:UIAlertControllerStyleAlert];
    if (self.isRecording) {
        [alert addAction:[UIAlertAction actionWithTitle:@"停止录制" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { self.isRecording = NO; [self saveScriptToDisk]; }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:@"开始录制" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self.recordedSteps removeAllObjects]; self.isRecording = YES; self.lastTouchTime = [NSDate date]; }]];
    }
    if (self.recordedSteps.count > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:@"运行脚本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { self.isPlaying = YES; }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlertController:alert];
}

- (void)recordTouchAtPoint:(CGPoint)pt {
    NSDictionary *step = @{ @"delay": @(0.5), @"x": @(pt.x), @"y": @(pt.y) };
    [self.recordedSteps addObject:step];
}

- (void)triggerAntForestAutoClick:(WKWebView *)webView {
    NSString *jsCode = @"\
        (function() {\
            var elements = document.querySelectorAll('button, div, span, a, section');\
            for (var i = 0; i < elements.length; i++) {\
                var text = elements[i].innerText || elements[i].textContent;\
                if (text) {\
                    if (text.indexOf('1T') !== -1 || text.indexOf('抽能量') !== -1 || text.indexOf('抽1T') !== -1 || text.indexOf('收取') !== -1) {\
                        elements[i].click();\
                    }\
                }\
            }\
        })();\
    ";
    [webView evaluateJavaScript:jsCode completionHandler:nil];
}

- (void)checkAndAutoStart {
    [self setupFloatWindow];
}
@end

__attribute__((constructor)) static void entry(void) {
    SwizzleMethod([UIWindow class], @selector(sendEvent:), @selector(ac_sendEvent:));
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[TweakScriptEngine sharedInstance] checkAndAutoStart];
        });
    }];
}
