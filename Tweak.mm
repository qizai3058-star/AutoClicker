#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define kSavedScriptListKey @"AutoClicker_SavedScriptList"
#define kCurrentScriptIndexKey @"AutoClicker_CurrentIndex"

// ---------------- IOHIDEvent 苹果私有底层触控接口声明 ----------------
typedef struct *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t index, uint32_t options, uint32_t type, CGPoint location, float pressure, float twist, float tiltX, float tiltY, float z, boolean_t range, boolean_t touch);

// ---------------- Helper: Swizzling ----------------
static void SwizzleMethod(Class c, SEL origSEL, SEL newSEL) {
    Method origMethod = class_getInstanceMethod(c, origSEL);
    Method newMethod = class_getInstanceMethod(c, newSEL);
    if (class_addMethod(c, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

// ---------------- Main Class ----------------
@interface TweakScriptEngine : NSObject
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isPlaying;

@property (nonatomic, strong) NSString *scriptRemark;
@property (nonatomic, assign) BOOL autoRunOnLaunch;
@property (nonatomic, assign) BOOL loopPlayback;
@property (nonatomic, assign) NSTimeInterval launchDelay;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recordedSteps;

@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *allScriptsList;
@property (nonatomic, assign) NSInteger currentIndex;

@property (nonatomic, strong) NSDate *lastTouchTime;
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, strong) UIButton *floatButton;

+ (instancetype)sharedInstance;
- (void)setupFloatWindow;
- (void)recordTouchAtPoint:(CGPoint)pt;
- (BOOL)isPointInFloatWindow:(CGPoint)pt window:(UIWindow *)window;
- (void)checkAndAutoStart;
- (void)performClickAtPoint:(CGPoint)point;
- (void)showClickEffectAtPoint:(CGPoint)point color:(UIColor *)color;
@end

// ---------------- UIWindow Swizzle Hook ----------------
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

// ---------------- Engine Implementation ----------------
@implementation TweakScriptEngine

+ (instancetype)sharedInstance {
    static TweakScriptEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TweakScriptEngine alloc] init];
        [instance loadDataFromDisk];
        instance.isRecording = NO;
        instance.isPlaying = NO;
    });
    return instance;
}

- (void)loadDataFromDisk {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *savedList = [defaults arrayForKey:kSavedScriptListKey];
    
    if (savedList && savedList.count > 0) {
        self.allScriptsList = [NSMutableArray array];
        for (NSDictionary *d in savedList) {
            [self.allScriptsList addObject:[d mutableCopy]];
        }
    } else {
        NSMutableDictionary *defaultScript = [@{
            @"remark": @"默认脚本1",
            @"autoRun": @(NO),
            @"loop": @(NO),
            @"launchDelay": @(3.0),
            @"steps": [NSMutableArray array]
        } mutableCopy];
        self.allScriptsList = [NSMutableArray arrayWithObject:defaultScript];
    }
    
    self.currentIndex = [defaults integerForKey:kCurrentScriptIndexKey];
    if (self.currentIndex < 0 || self.currentIndex >= self.allScriptsList.count) {
        self.currentIndex = 0;
    }
    
    [self loadCurrentScriptData];
}

- (void)loadCurrentScriptData {
    if (self.currentIndex < self.allScriptsList.count) {
        NSMutableDictionary *curr = self.allScriptsList[self.currentIndex];
        self.scriptRemark = curr[@"remark"] ?: @"未命名脚本";
        self.autoRunOnLaunch = [curr[@"autoRun"] boolValue];
        self.loopPlayback = [curr[@"loop"] boolValue];
        self.launchDelay = curr[@"launchDelay"] ? [curr[@"launchDelay"] doubleValue] : 3.0;
        
        NSArray *steps = curr[@"steps"];
        self.recordedSteps = steps ? [steps mutableCopy] : [NSMutableArray array];
    }
}

- (void)saveScriptToDisk {
    if (self.currentIndex < self.allScriptsList.count) {
        NSMutableDictionary *curr = self.allScriptsList[self.currentIndex];
        curr[@"remark"] = self.scriptRemark ?: @"未命名脚本";
        curr[@"autoRun"] = @(self.autoRunOnLaunch);
        curr[@"loop"] = @(self.loopPlayback);
        curr[@"launchDelay"] = @(self.launchDelay);
        curr[@"steps"] = self.recordedSteps;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.allScriptsList forKey:kSavedScriptListKey];
    [defaults setInteger:self.currentIndex forKey:kCurrentScriptIndexKey];
    [defaults synchronize];
}

- (UIWindow *)getActiveWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow && w != self.floatWindow) return w;
                }
                for (UIWindow *w in windowScene.windows) {
                    if (w != self.floatWindow && !w.hidden) return w;
                }
            }
        }
    }
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *w in windows) {
        if (w != self.floatWindow && !w.hidden) return w;
    }
    #pragma clang diagnostic pop
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
            [self.floatButton setTitle:@"🔴录制中" forState:UIControlStateNormal];
            self.floatButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.85];
        } else if (self.isPlaying) {
            [self.floatButton setTitle:@"▶️运行中" forState:UIControlStateNormal];
            self.floatButton.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.85];
        } else {
            [self.floatButton setTitle:@"🤖精灵" forState:UIControlStateNormal];
            self.floatButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        }
    });
}

- (void)floatButtonTapped {
    NSString *title = [NSString stringWithFormat:@"按键精灵 - [%@]", self.scriptRemark];
    NSString *msg = [NSString stringWithFormat:@"已存步骤: %lu 步 | 延时: %.1f秒\n自启状态: %@\n循环播放: %@",
                     (unsigned long)self.recordedSteps.count,
                     self.launchDelay,
                     self.autoRunOnLaunch ? @"已开启" : @"已关闭",
                     self.loopPlayback ? @"已开启" : @"已关闭"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];

    if (self.isRecording) {
        [alert addAction:[UIAlertAction actionWithTitle:@"⏹ 停止录制并保存脚本" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self stopRecording];
        }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:@"🔴 开始录制新脚本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self startRecording];
        }]];
    }

    if (self.isPlaying) {
        [alert addAction:[UIAlertAction actionWithTitle:@"⏹ 停止当前运行" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self stopPlayback];
        }]];
    } else {
        if (self.recordedSteps.count > 0) {
            [alert addAction:[UIAlertAction actionWithTitle:@"▶️ 立即运行录制脚本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self startPlaybackWithDelay:0];
            }]];
        }
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"📜 切换 / 管理历史脚本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showScriptManagerMenu];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"✏️ 修改当前备注与触发延时" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showEditCurrentConfigAlert];
    }]];

    NSString *autoTitle = self.autoRunOnLaunch ? @"⚡️ 启动自启: 【已开启】(点击关闭)" : @"⚡️ 启动自启: 【已关闭】(点击开启)";
    [alert addAction:[UIAlertAction actionWithTitle:autoTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.autoRunOnLaunch = !self.autoRunOnLaunch;
        [self saveScriptToDisk];
        [self floatButtonTapped];
    }]];

    NSString *loopTitle = self.loopPlayback ? @"🔄 循环播放: 【已开启】(点击关闭)" : @"🔄 循环播放: 【已关闭】(点击开启)";
    [alert addAction:[UIAlertAction actionWithTitle:loopTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.loopPlayback = !self.loopPlayback;
        [self saveScriptToDisk];
        [self floatButtonTapped];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"📤 导出脚本 (复制到剪贴板)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self exportConfigToClipboard];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"📥 导入脚本 (从剪贴板读取)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self importConfigFromClipboard];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    [self presentAlertController:alert];
}

- (void)showScriptManagerMenu {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"历史脚本管理" message:@"选择要切换的脚本或新建：" preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSInteger i = 0; i < self.allScriptsList.count; i++) {
        NSDictionary *dict = self.allScriptsList[i];
        NSString *remark = dict[@"remark"] ?: @"未命名";
        NSArray *steps = dict[@"steps"] ?: @[];
        NSString *title = [NSString stringWithFormat:@"%@ %@ (%lu步)", (i == self.currentIndex ? @"✅" : @"📄"), remark, (unsigned long)steps.count];
        
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.currentIndex = i;
            [self loadCurrentScriptData];
            [self saveScriptToDisk];
            [self showAlertWithTitle:@"切换成功" message:[NSString stringWithFormat:@"已切换至: %@", self.scriptRemark]];
        }]];
    }
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"➕ 新增空白脚本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSMutableDictionary *newScript = [@{
            @"remark": [NSString stringWithFormat:@"脚本%ld", (long)(self.allScriptsList.count + 1)],
            @"autoRun": @(NO),
            @"loop": @(NO),
            @"launchDelay": @(3.0),
            @"steps": [NSMutableArray array]
        } mutableCopy];
        [self.allScriptsList addObject:newScript];
        self.currentIndex = self.allScriptsList.count - 1;
        [self loadCurrentScriptData];
        [self saveScriptToDisk];
        [self showAlertWithTitle:@"创建成功" message:@"已创建新脚本，请点击录制或修改备注！"];
    }]];
    
    if (self.allScriptsList.count > 1) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"🗑 删除当前脚本" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self.allScriptsList removeObjectAtIndex:self.currentIndex];
            self.currentIndex = 0;
            [self loadCurrentScriptData];
            [self saveScriptToDisk];
            [self showAlertWithTitle:@"已删除" message:@"已切换回首个脚本"];
        }]];
    }
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlertController:sheet];
}

- (void)showEditCurrentConfigAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑脚本参数" message:@"设置当前脚本的备注名称与启动延时时间：" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"脚本备注说明 (如: 蚂蚁森林收取)";
        tf.text = self.scriptRemark;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"启动延时秒数 (如: 3.0)";
        tf.text = [NSString stringWithFormat:@"%.1f", self.launchDelay];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *remark = alert.textFields[0].text;
        double delay = [alert.textFields[1].text doubleValue];
        
        self.scriptRemark = (remark.length > 0) ? remark : @"未命名脚本";
        self.launchDelay = (delay >= 0) ? delay : 0;
        [self saveScriptToDisk];
        [self showAlertWithTitle:@"保存成功" message:@"备注与延时配置已更新！"];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlertController:alert];
}

- (void)exportConfigToClipboard {
    if (self.recordedSteps.count == 0) {
        [self showAlertWithTitle:@"导出失败" message:@"当前脚本还没有录制任何步骤！"];
        return;
    }

    NSDictionary *configDict = @{
        @"version": @"1.0",
        @"remark": self.scriptRemark,
        @"autoRun": @(self.autoRunOnLaunch),
        @"loop": @(self.loopPlayback),
        @"launchDelay": @(self.launchDelay),
        @"steps": self.recordedSteps
    };

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:configDict options:NSJSONWritingPrettyPrinted error:&error];
    if (error || !jsonData) return;

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [UIPasteboard generalPasteboard].string = jsonString;

    [self showAlertWithTitle:@"导出成功 🎉" message:@"当前脚本已成功复制到剪贴板！"];
}

- (void)importConfigFromClipboard {
    NSString *jsonString = [UIPasteboard generalPasteboard].string;
    if (!jsonString || jsonString.length == 0) {
        [self showAlertWithTitle:@"导入失败" message:@"剪贴板为空！"];
        return;
    }

    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return;

    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error || ![jsonObject isKindOfClass:[NSDictionary class]]) {
        [self showAlertWithTitle:@"导入失败" message:@"剪贴板内容格式不正确！"];
        return;
    }

    NSDictionary *configDict = (NSDictionary *)jsonObject;
    NSArray *steps = configDict[@"steps"];
    if (![steps isKindOfClass:[NSArray class]] || steps.count == 0) {
        [self showAlertWithTitle:@"导入失败" message:@"剪贴板中未找到有效的步骤数据！"];
        return;
    }

    NSMutableDictionary *newScript = [@{
        @"remark": configDict[@"remark"] ?: @"导入的脚本",
        @"autoRun": configDict[@"autoRun"] ?: @(NO),
        @"loop": configDict[@"loop"] ?: @(NO),
        @"launchDelay": configDict[@"launchDelay"] ?: @(3.0),
        @"steps": [steps mutableCopy]
    } mutableCopy];

    [self.allScriptsList addObject:newScript];
    self.currentIndex = self.allScriptsList.count - 1;
    [self loadCurrentScriptData];
    [self saveScriptToDisk];
    [self updateFloatButtonTitle];
    
    [self showAlertWithTitle:@"导入成功 🎉" message:[NSString stringWithFormat:@"成功导入并切换至【%@】(%lu步)！", self.scriptRemark, (unsigned long)steps.count]];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentAlertController:alert];
}

- (void)startRecording {
    [self.recordedSteps removeAllObjects];
    self.isRecording = YES;
    self.lastTouchTime = [NSDate date];
    [self updateFloatButtonTitle];
}

- (void)recordTouchAtPoint:(CGPoint)pt {
    NSDate *now = [NSDate date];
    NSTimeInterval delay = [now timeIntervalSinceDate:self.lastTouchTime];
    self.lastTouchTime = now;

    if (self.recordedSteps.count == 0 && delay > 2.0) {
        delay = 1.0;
    }

    NSDictionary *step = @{
        @"delay": @(delay),
        @"x": @(pt.x),
        @"y": @(pt.y)
    };
    [self.recordedSteps addObject:step];
    [self showClickEffectAtPoint:pt color:[UIColor redColor]];
}

- (void)stopRecording {
    self.isRecording = NO;
    [self saveScriptToDisk];
    [self updateFloatButtonTitle];
    [self showAlertWithTitle:@"录制完成" message:[NSString stringWithFormat:@"成功录制 %lu 个步骤，已保存至【%@】", (unsigned long)self.recordedSteps.count, self.scriptRemark]];
}

- (void)startPlaybackWithDelay:(NSTimeInterval)customDelay {
    if (self.recordedSteps.count == 0) return;
    self.isPlaying = YES;
    [self updateFloatButtonTitle];
    
    NSTimeInterval delayToUse = (customDelay > 0) ? customDelay : self.launchDelay;
    if (delayToUse < 0.1) delayToUse = 0.1;
    
    [self showToastMessage:[NSString stringWithFormat:@"⏱️ [%@] 将在 %.1f 秒后自动运行...", self.scriptRemark, delayToUse] duration:delayToUse > 2.0 ? 2.0 : delayToUse];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayToUse * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isPlaying) return;
        [self executeStepAtIndex:0];
    });
}

- (void)stopPlayback {
    self.isPlaying = NO;
    [self updateFloatButtonTitle];
}

- (void)executeStepAtIndex:(NSUInteger)index {
    if (!self.isPlaying) return;

    if (index >= self.recordedSteps.count) {
        if (self.loopPlayback) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.isPlaying) [self executeStepAtIndex:0];
            });
        } else {
            [self stopPlayback];
            [self showToastMessage:[NSString stringWithFormat:@"✅ [%@] 脚本执行完毕", self.scriptRemark] duration:1.5];
        }
        return;
    }

    NSDictionary *step = self.recordedSteps[index];
    double delay = [step[@"delay"] doubleValue];
    CGFloat x = [step[@"x"] floatValue];
    CGFloat y = [step[@"y"] floatValue];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isPlaying) return;
        [self performClickAtPoint:CGPointMake(x, y)];
        [self executeStepAtIndex:index + 1];
    });
}

- (void)showToastMessage:(NSString *__nullable)message duration:(NSTimeInterval)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [self getActiveWindow];
        if (!keyWindow) return;

        UILabel *toast = [[UILabel alloc] init];
        toast.text = message;
        toast.textColor = [UIColor whiteColor];
        toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        toast.layer.cornerRadius = 10;
        toast.clipsToBounds = YES;
        toast.numberOfLines = 0;

        CGSize textSize = [toast sizeThatFits:CGSizeMake(keyWindow.bounds.size.width - 60, 100)];
        CGFloat toastWidth = textSize.width + 30;
        CGFloat toastHeight = textSize.height + 16;
        toast.frame = CGRectMake((keyWindow.bounds.size.width - toastWidth) / 2.0, 60, toastWidth, toastHeight);

        [keyWindow addSubview:toast];

        [UIView animateWithDuration:0.3 delay:duration options:UIViewAnimationOptionCurveEaseOut animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

// ---------------- 核心升级：底层硬件级 IOHIDEvent 触控模拟 ----------------
- (void)performClickAtPoint:(CGPoint)point {
    static IOHIDEventSystemClientRef hidClient = NULL;
    if (!hidClient) {
        hidClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
    
    if (hidClient) {
        uint64_t machTime = mach_absolute_time();
        
        IOHIDEventRef downEvent = IOHIDEventCreateDigitizerFingerEvent(
            kCFAllocatorDefault, machTime, 0, 3, 0, point, 1.0, 0, 0, 0, 0, true, true
        );
        if (downEvent) {
            IOHIDEventSystemClientDispatchEvent(hidClient, downEvent);
            CFRelease(downEvent);
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            uint64_t upTime = mach_absolute_time();
            IOHIDEventRef upEvent = IOHIDEventCreateDigitizerFingerEvent(
                kCFAllocatorDefault, upTime, 0, 0, 0, point, 0.0, 0, 0, 0, 0, false, false
            );
            if (upEvent) {
                IOHIDEventSystemClientDispatchEvent(hidClient, upEvent);
                CFRelease(upEvent);
            }
        });
    }

    [self showClickEffectAtPoint:point color:[UIColor systemGreenColor]];
}

- (void)showClickEffectAtPoint:(CGPoint)point color:(UIColor *)color {
    UIWindow *window = [self getActiveWindow];
    if (!window) return;

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
    dot.center = point;
    dot.backgroundColor = [color colorWithAlphaComponent:0.8];
    dot.layer.cornerRadius = 13;
    dot.userInteractionEnabled = NO;
    [window addSubview:dot];

    [UIView animateWithDuration:0.4 animations:^{
        dot.transform = CGAffineTransformMakeScale(2.2, 2.2);
        dot.alpha = 0;
    } completion:^(BOOL finished) {
        [dot removeFromSuperview];
    }];
}

- (void)checkAndAutoStart {
    [self setupFloatWindow];
    if (self.autoRunOnLaunch && self.recordedSteps.count > 0 && !self.isPlaying) {
        [self startPlaybackWithDelay:self.launchDelay];
    }
}

@end

// ---------------- 程序入口 ----------------
__attribute__((constructor)) static void entryPoint(void) {
    SwizzleMethod([UIWindow class], @selector(sendEvent:), @selector(ac_sendEvent:));

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[TweakScriptEngine sharedInstance] checkAndAutoStart];
        });
    }];
}
