    [alert addAction:[UIAlertAction actionWithTitle:@"📋 COPY HWID" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = myHwid;
        
        UIAlertController *copiedAlert = [UIAlertController alertControllerWithTitle:@"COPIED!"
                                                                             message:[NSString stringWithFormat:@"HWID '%@' copied to clipboard! Send it to admin to get your key.", myHwid]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
        [copiedAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
            CLS_PromptKeyActivation();
        }]];
        [root presentViewController:copiedAlert animated:YES completion:nil];
    }]];
    
    // Activate Key Button
    [alert addAction:[UIAlertAction actionWithTitle:@"⚡ ACTIVATE KEY" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *inputKey = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        int days = 30;
        NSString *err = nil;
        if (CLS_VerifyOfflineKey(inputKey, &days, &err)) {
            // Activation Success!
            double now = [[NSDate date] timeIntervalSince1970];
            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            [defs setObject:inputKey forKey:kCLS_PrefKey_LicenseKey];
            [defs setObject:myHwid forKey:kCLS_PrefKey_BoundDev];
            [defs setDouble:now forKey:kCLS_PrefKey_FirstActive];
            [defs synchronize];
            
            CLS_KeychainSave(kCLS_KeychainAccountKey, inputKey);
            CLS_KeychainSave(kCLS_KeychainAccountTime, [NSString stringWithFormat:@"%.0f", now]);
            
            UIAlertController *succ = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                          message:[NSString stringWithFormat:@"✓ VIP Activated Successfully!\nValidity: %d Days.\nDouble-tap with 3 fingers anywhere to open GPS Radar.", days]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [succ addAction:[UIAlertAction actionWithTitle:@"START" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                CLS_InstallDoubleTapGesture();
            }]];
            [root presentViewController:succ animated:YES completion:nil];
        } else {
            // Activation Failed (Mismatched device, invalid key, or expired key)
            UIAlertController *fail = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                          message:err ?: @"Invalid Key!"
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [fail addAction:[UIAlertAction actionWithTitle:@"TRY AGAIN" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                CLS_PromptKeyActivation();
            }]];
            [root presentViewController:fail animated:YES completion:nil];
        }
    }]];
    
    [root presentViewController:alert animated:YES completion:nil];
}
#pragma mark - CONSTRUCTOR INITIALIZER
__attribute__((constructor)) static void CLS_Init(void) {
    // 1. Swizzle AppStore Receipt to bypass "Unauthorized rider app" on login
    Method origReceipt = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
    Method swizReceipt = class_getInstanceMethod([NSBundle class], @selector(cls_appStoreReceiptURL));
    if (origReceipt && swizReceipt) {
        method_exchangeImplementations(origReceipt, swizReceipt);
    }
    
    // 2. Swizzle CoreLocation Manager
    Method origSetDel = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:));
    Method swizSetDel = class_getInstanceMethod([CLLocationManager class], @selector(cls_setDelegate:));
    if (origSetDel && swizSetDel) {
        method_exchangeImplementations(origSetDel, swizSetDel);
    }
    
    Method origLoc = class_getInstanceMethod([CLLocationManager class], @selector(location));
    Method swizLoc = class_getInstanceMethod([CLLocationManager class], @selector(cls_location));
    if (origLoc && swizLoc) {
        method_exchangeImplementations(origLoc, swizLoc);
    }
    
    // 3. Register Application Did Become Active
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        CLS_VerifyAndBindLicense();
    }];
}
