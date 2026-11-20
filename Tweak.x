    if (!savedKey || savedKey.length < 5) {
        showLicenseActivationDialog(rootVC, ^{
            CLSViewController *radar = [[CLSViewController alloc] init];
            radar.modalPresentationStyle = UIModalPresentationFullScreen;
            [rootVC presentViewController:radar animated:YES completion:nil];
        });
        return;
    }
    
    // Shield 2: Remote Revocation & Multi-device Lock Check
    NSString *urlStr = [NSString stringWithFormat:@"https://hadimod.tech/admin/bind_dylib?key=%@&hwid=%@",
                        [savedKey stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                        [hwid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 8.0;
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpRes = (NSHTTPURLResponse *)response;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error && httpRes.statusCode == 200) {
                CLSViewController *radar = [[CLSViewController alloc] init];
                radar.modalPresentationStyle = UIModalPresentationFullScreen;
                [rootVC presentViewController:radar animated:YES completion:nil];
            } else {
                [defs removeObjectForKey:kCLS_PrefKey_LicenseKey];
                [defs synchronize];
                showLicenseActivationDialog(rootVC, ^{
                    CLSViewController *radar = [[CLSViewController alloc] init];
                    radar.modalPresentationStyle = UIModalPresentationFullScreen;
                    [rootVC presentViewController:radar animated:YES completion:nil];
                });
            }
        });
    }] resume];
}
#pragma mark - GESTURE INJECTION (3 Fingers Double Tap)
@interface UIWindow (CLSWindowHook)
- (void)cls_didMoveToWindow;
@end
static void handleTripleFingerDoubleTap(id self, SEL _cmd, UITapGestureRecognizer *gesture) {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        UIWindow *window = (UIWindow *)gesture.view;
        UIViewController *rootVC = window.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        if (rootVC) {
            verifyLicenseAndOpenRadar(rootVC);
        }
    }
}
%hook UIWindow
- (void)didMoveToWindow {
    %orig;
    
    BOOL hasGesture = NO;
    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)g;
            if (tap.numberOfTouchesRequired == 3 && tap.numberOfTapsRequired == 2) {
                hasGesture = YES;
                break;
            }
        }
    }
    
    if (!hasGesture) {
        UITapGestureRecognizer *threeFingerDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cls_handleTripleFingerTap:)];
        threeFingerDoubleTap.numberOfTouchesRequired = 3;
        threeFingerDoubleTap.numberOfTapsRequired = 2;
        threeFingerDoubleTap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:threeFingerDoubleTap];
    }
}
%new
- (void)cls_handleTripleFingerTap:(UITapGestureRecognizer *)gesture {
    handleTripleFingerDoubleTap(self, _cmd, gesture);
}
%end
#pragma mark - CONSTRUCTOR
%ctor {
    @autoreleasepool {
        NSLog(@"[DEV ABDULLAH X HADI MOD] Tweak loaded. Target Server: https://hadimod.tech");
    }
}
