// ---------------- 核心升级：底层硬件级 IOHIDEvent 触控模拟 ----------------
- (void)performClickAtPoint:(CGPoint)point {
    static IOHIDEventSystemClientRef hidClient = NULL;
    if (!hidClient) {
        hidClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
    
    if (hidClient) {
        uint64_t machTime = mach_absolute_time();
        
        // 1. 模拟手指按下
        IOHIDEventRef downEvent = IOHIDEventCreateDigitizerFingerEvent(
            kCFAllocatorDefault, machTime, 0, 3, 0, point, 1.0, 0, 0, 0, 0, true, true
        );
        if (downEvent) {
            IOHIDEventSystemClientDispatchEvent(hidClient, downEvent);
            CFRelease(downEvent);
        }
        
        // 2. 模拟手指抬起
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
