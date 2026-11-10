// Language: Objective-C (Logos)
// Target: iOS 13.0 - 18.x (arm64 / arm64e)
// Features: Dual Embedded High-Res Logos (Double Size) + VPS Login + Session Watcher + Universal GPS Pulse Engine + Favorites + Save Pin + Auto-Persistent Location + Talabat Restaurants Fetch on Volume Down & Button
// Fixed: Talabat 401 Unauthorized & Session Handshake Conflict

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// Global persistent state
static BOOL g_spoofEnabled = NO;
static CLLocationDegrees g_spoofLatitude = 24.46094;
static CLLocationDegrees g_spoofLongitude = 54.35718;
static UIWindow *g_window = nil;
static BOOL g_sessionWatcherRunning = NO;
static dispatch_source_t g_sessionTimer = nil;
static dispatch_source_t g_gpsPulseTimer = nil;
static dispatch_once_t g_watcherOnceToken = 0;
static dispatch_once_t g_windowOnceToken = 0;
static NSHashTable *g_activeManagers = nil;
static NSMutableSet *g_swizzledDelegateClasses = nil;

static NSString * const kFavKey = @"HadiModSavedFavorites";
static NSString * const kProjectSlug = @"hadi-gps-3";

// Persistent Location Keys
static NSString * const kSpoofEnabledKey = @"HadiMod_SpoofEnabled";
static NSString * const kSpoofLatKey     = @"HadiMod_SpoofLatitude";
static NSString * const kSpoofLonKey     = @"HadiMod_SpoofLongitude";

// Base64 Embedded Circular Logos (High-Resolution Verified PNG Base64)
static NSString * const kLogoHadiModBase64 = @"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";

static UIImage *getImageFromBase64(NSString *b64) {
    if (!b64 || b64.length == 0) return nil;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data || data.length == 0) return nil;
    return [UIImage imageWithData:data];
}

// Fixed: Isolated custom UUID so Talabat's original device identifier is completely preserved
static NSString *getOrCreateDeviceId(void) {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *devId = [defs stringForKey:@"HadiMod_DeviceId"];
    if (!devId || devId.length == 0) {
        devId = [[NSUUID UUID] UUIDString];
        [defs setObject:devId forKey:@"HadiMod_DeviceId"];
        [defs synchronize];
    }
    return devId;
}

static CLLocation *createSpoofedLocation(void) {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(g_spoofLatitude, g_spoofLongitude);
    return [[CLLocation alloc] initWithCoordinate:coord
                                         altitude:25.0
                               horizontalAccuracy:5.0
                                 verticalAccuracy:5.0
                                           course:0.0
                                            speed:0.0
                                        timestamp:[NSDate date]];
}

static void triggerGlobalLocationUpdate(void);
static void startGpsPulseTimer(void);
static void stopGpsPulseTimer(void);

// Forward Declarations
@interface HadiModMapViewController : UIViewController <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *coordsLabel;
@property (nonatomic, strong) UIButton *btnSpoof;
@property (nonatomic, strong) UIButton *btnNormal;
@property (nonatomic, strong) UIButton *btnSave;
@property (nonatomic, strong) UIButton *btnFav;
@property (nonatomic, strong) UIButton *btnTalabat;
- (void)startSpoofTapped;
- (void)fetchTalabatRestaurants;
- (void)showToast:(NSString *)msg;
@end

static void showLoginDialog(void);
static void executeLogin(NSString *user, NSString *pass);
static void startSessionWatcher(void);
static void stopSessionWatcher(void);
static void showRevokedAlert(NSString *title, NSString *message);
static double parseExpiryFromObject(id obj);
static double extractExpiryFromJSON(NSDictionary *json);
static BOOL isJsonExplicitlyExpired(NSDictionary *json);
static BOOL isCurrentSessionExpired(void);

// ==========================================
// UNIVERSAL CORE LOCATION ENGINE
// (Intercepts CLLocation + CLLocationManager + Delegate Callbacks + Continuous 1Hz Pulse)
// ==========================================

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (g_spoofEnabled) {
        return CLLocationCoordinate2DMake(g_spoofLatitude, g_spoofLongitude);
    }
    return %orig;
}

%end

static void swizzleDelegateIfNeeded(id delegate) {
    if (!delegate) return;
    Class delClass = [delegate class];
    if (!g_swizzledDelegateClasses) {
        g_swizzledDelegateClasses = [[NSMutableSet alloc] init];
    }
    
    NSString *className = NSStringFromClass(delClass);
    if ([g_swizzledDelegateClasses containsObject:className]) return;
    [g_swizzledDelegateClasses addObject:className];
    
    SEL sel = @selector(locationManager:didUpdateLocations:);
    Method method = class_getInstanceMethod(delClass, sel);
    if (method) {
        void (*origImp)(id, SEL, id, id) = (void (*)(id, SEL, id, id))method_getImplementation(method);
        IMP newImp = imp_implementationWithBlock(^(id _self, CLLocationManager *mgr, NSArray<CLLocation *> *locations) {
            if (g_spoofEnabled) {
                CLLocation *fake = createSpoofedLocation();
                origImp(_self, sel, mgr, @[fake]);
            } else {
                origImp(_self, sel, mgr, locations);
            }
        });
        class_replaceMethod(delClass, sel, newImp, method_getTypeEncoding(method));
    }
}

%hook CLLocationManager

- (instancetype)init {
    CLLocationManager *mgr = %orig;
    if (!g_activeManagers) {
        g_activeManagers = [NSHashTable weakObjectsHashTable];
    }
    [g_activeManagers addObject:mgr];
    return mgr;
}

- (void)setDelegate:(id<CLLocationManagerDelegate>)delegate {
    if (delegate) {
        swizzleDelegateIfNeeded(delegate);
    }
    if (!g_activeManagers) {
        g_activeManagers = [NSHashTable weakObjectsHashTable];
    }
    [g_activeManagers addObject:self];
    %orig(delegate);
}

- (CLLocation *)location {
    if (g_spoofEnabled) {
        return createSpoofedLocation();
    }
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    if (!g_activeManagers) {
        g_activeManagers = [NSHashTable weakObjectsHashTable];
    }
    [g_activeManagers addObject:self];
    if (g_spoofEnabled) {
        CLLocation *fake = createSpoofedLocation();
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fake]];
        }
    }
}

- (void)requestLocation {
    if (g_spoofEnabled) {
        CLLocation *fake = createSpoofedLocation();
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fake]];
            return;
        }
    }
    %orig;
}

%end

static void triggerGlobalLocationUpdate(void) {
    if (!g_activeManagers) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        CLLocation *fake = createSpoofedLocation();
        for (CLLocationManager *mgr in [g_activeManagers allObjects]) {
            if (mgr.delegate && [mgr.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [mgr.delegate locationManager:mgr didUpdateLocations:@[fake]];
            }
        }
    });
}

static void startGpsPulseTimer(void) {
    if (g_gpsPulseTimer) return;
    dispatch_queue_t queue = dispatch_get_main_queue();
    g_gpsPulseTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(g_gpsPulseTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(g_gpsPulseTimer, ^{
        if (g_spoofEnabled) {
            if (isCurrentSessionExpired()) {
                showRevokedAlert(@"Subscription Expired", @"Your subscription period has ended. Auto logged out.");
                return;
            }
            triggerGlobalLocationUpdate();
        }
    });
    dispatch_resume(g_gpsPulseTimer);
}

static void stopGpsPulseTimer(void) {
    if (g_gpsPulseTimer) {
        dispatch_source_cancel(g_gpsPulseTimer);
        g_gpsPulseTimer = nil;
    }
}

// ==========================================
// EXPIRATION PARSER & AUTO-LOGOUT ENGINE
// ==========================================
static double parseExpiryFromObject(id obj) {
    if (!obj || obj == (id)[NSNull null]) return 0.0;
    
    if ([obj isKindOfClass:[NSNumber class]]) {
        double val = [(NSNumber *)obj doubleValue];
        if (val > 10000000000.0) val /= 1000.0;
        return val;
    }
    
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *str = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (str.length == 0 || [str caseInsensitiveCompare:@"null"] == NSOrderedSame || [str caseInsensitiveCompare:@"unlimited"] == NSOrderedSame) {
            return 0.0;
        }
        
        NSScanner *scanner = [NSScanner scannerWithString:str];
        double numVal = 0;
        if ([scanner scanDouble:&numVal] && [scanner isAtEnd]) {
            if (numVal > 10000000000.0) numVal /= 1000.0;
            return numVal;
        }
        
        NSArray<NSString *> *formats = @[
            @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            @"yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            @"yyyy-MM-dd'T'HH:mm:ss.SSS",
            @"yyyy-MM-dd'T'HH:mm:ss'Z'",
            @"yyyy-MM-dd'T'HH:mm:ssZ",
            @"yyyy-MM-dd'T'HH:mm:ss",
            @"yyyy-MM-dd HH:mm:ss",
            @"yyyy-MM-dd"
        ];
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        
        for (NSString *fmt in formats) {
            [df setDateFormat:fmt];
            NSDate *d = [df dateFromString:str];
            if (d) return [d timeIntervalSince1970];
        }
    }
    return 0.0;
}

static double extractExpiryFromJSON(NSDictionary *json) {
    if (!json || ![json isKindOfClass:[NSDictionary class]]) return 0.0;
    NSArray *keys = @[@"expiresAt", @"expiry", @"expiryDate", @"expiry_date", @"valid_until", @"expires_at"];
    for (NSString *k in keys) {
        if (json[k] && json[k] != [NSNull null]) {
            double exp = parseExpiryFromObject(json[k]);
            if (exp > 0.0) return exp;
        }
    }
    id cust = json[@"customer"] ?: json[@"user"] ?: json[@"data"];
    if (cust && [cust isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in keys) {
            if (cust[k] && cust[k] != [NSNull null]) {
                double exp = parseExpiryFromObject(cust[k]);
                if (exp > 0.0) return exp;
            }
        }
    }
    return 0.0;
}

static BOOL isJsonExplicitlyExpired(NSDictionary *json) {
    if (!json || ![json isKindOfClass:[NSDictionary class]]) return NO;
    id cust = json[@"customer"] ?: json[@"user"] ?: json[@"data"];
    NSArray *dicts = cust && [cust isKindOfClass:[NSDictionary class]] ? @[json, cust] : @[json];
    for (NSDictionary *d in dicts) {
        if ([d[@"expired"] boolValue] || [d[@"isExpired"] boolValue]) return YES;
        NSString *status = [NSString stringWithFormat:@"%@", d[@"status"] ?: @""];
        if ([status caseInsensitiveCompare:@"expired"] == NSOrderedSame) return YES;
        if ([status caseInsensitiveCompare:@"banned"] == NSOrderedSame) return YES;
        if (d[@"active"] && ![d[@"active"] boolValue]) return YES;
        if (d[@"banned"] && [d[@"banned"] boolValue]) return YES;
    }
    return NO;
}

static BOOL isCurrentSessionExpired(void) {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    BOOL loggedIn = [defs boolForKey:@"HadiMod_IsLoggedIn"];
    NSString *token = [defs stringForKey:@"HadiMod_Token"];
    if (!loggedIn || !token || token.length == 0) return YES;
    
    double expiry = [defs doubleForKey:@"HadiMod_Expiry"];
    if (expiry > 0.0) {
        double now = [[NSDate date] timeIntervalSince1970];
        if (now >= expiry) return YES;
    }
    return NO;
}

// ==========================================
// SESSION TERMINATION & AUTO-LOGOUT DISPATCH
// ==========================================
static void showRevokedAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        g_spoofEnabled = NO;
        stopGpsPulseTimer();
        stopSessionWatcher();
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:@"HadiMod_IsLoggedIn"];
        [defs setBool:NO forKey:kSpoofEnabledKey];
        [defs removeObjectForKey:@"HadiMod_Token"];
        [defs removeObjectForKey:@"HadiMod_Expiry"];
        [defs removeObjectForKey:@"HadiMod_Username"];
        [defs synchronize];
        
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        if ([rootVC isKindOfClass:[HadiModMapViewController class]]) {
            UIViewController *presenting = rootVC.presentingViewController;
            [rootVC dismissViewControllerAnimated:YES completion:^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    showLoginDialog();
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
                [presenting presentViewController:alert animated:YES completion:nil];
            }];
            return;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            showLoginDialog();
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

// Background Heartbeat: Check expiration locally and verify with VPS
static void startSessionWatcher(void) {
    if (g_sessionWatcherRunning) return;
    dispatch_queue_t queue = dispatch_queue_create("net.hadimod3.sessionwatcher", DISPATCH_QUEUE_SERIAL);
    g_sessionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    // Fixed: 15s initial delay taake Talabat app ka initial login/handshake complete ho jaye
    dispatch_source_set_timer(g_sessionTimer, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), 10 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(g_sessionTimer, ^{
        if (isCurrentSessionExpired()) {
            showRevokedAlert(@"Subscription Expired", @"Your subscription period has ended. Auto logged out.");
            return;
        }
        
        NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"HadiMod_Token"];
        if (!token || token.length == 0) {
            return;
        }
        
        NSURL *url = [NSURL URLWithString:@"https://api.hadimod3.net/auth/customer/me"];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        [req setHTTPMethod:@"GET"];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
        [req setValue:kProjectSlug forHTTPHeaderField:@"x-project"];
        [req setValue:getOrCreateDeviceId() forHTTPHeaderField:@"x-device-id"];
        [req setTimeoutInterval:5.0];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)resp;
            NSInteger statusCode = httpResp.statusCode;
            
            if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
                NSString *reason = @"Subscription Expired";
                NSString *detail = @"Your account credentials or subscription have expired. Auto logged out.";
                if (data) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    NSString *msg = json[@"message"];
                    if (msg && [msg localizedCaseInsensitiveContainsString:@"ban"]) {
                        reason = @"Account Banned";
                        detail = @"Your account has been banned by administrator.";
                    } else if (msg && ([msg localizedCaseInsensitiveContainsString:@"expire"] || [msg localizedCaseInsensitiveContainsString:@"ended"])) {
                        reason = @"Subscription Expired";
                        detail = @"Your subscription period has ended. Please renew.";
                    } else if (msg && [msg localizedCaseInsensitiveContainsString:@"delete"]) {
                        reason = @"Account Terminated";
                        detail = @"Your account was deleted by administrator.";
                    }
                }
                showRevokedAlert(reason, detail);
            } else if (statusCode == 200 && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (isJsonExplicitlyExpired(json)) {
                    showRevokedAlert(@"Subscription Expired", @"Your subscription has expired or been deactivated. Auto logged out.");
                    return;
                }
                double serverExpiry = extractExpiryFromJSON(json);
                if (serverExpiry > 0.0) {
                    double now = [[NSDate date] timeIntervalSince1970];
                    if (now >= serverExpiry) {
                        showRevokedAlert(@"Subscription Expired", @"Your subscription period has ended. Auto logged out.");
                        return;
                    }
                    [[NSUserDefaults standardUserDefaults] setDouble:serverExpiry forKey:@"HadiMod_Expiry"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }
        }];
        [task resume];
    });
    dispatch_resume(g_sessionTimer);
    g_sessionWatcherRunning = YES;
}

static void stopSessionWatcher(void) {
    if (g_sessionTimer) {
        dispatch_source_cancel(g_sessionTimer);
        g_sessionTimer = nil;
        g_sessionWatcherRunning = NO;
    }
}

// ==========================================
// MAP VIEW CONTROLLER (Double-Sized Circular Logos + WebKit Map + Favorites + Talabat Integration)
// ==========================================
@implementation HadiModMapViewController {
    float _lastVolume;
    BOOL _isFetchingTalabat;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
    _isFetchingTalabat = NO;
    
    // Top Bar Container (Height 138 to clear iPhone camera notch/Dynamic Island)
    CGFloat topBarH = 138.0;
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, topBarH)];
    topBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topBar];
    
    // Left Circular Logo: Hadi Mod (Size 72x72)
    CGFloat logoSize = 72.0;
    UIImage *imgHadi = getImageFromBase64(kLogoHadiModBase64);
    if (imgHadi) {
        UIImageView *ivHadi = [[UIImageView alloc] initWithFrame:CGRectMake(12, 52, logoSize, logoSize)];
        ivHadi.image = imgHadi;
        ivHadi.contentMode = UIViewContentModeScaleAspectFill;
        ivHadi.layer.cornerRadius = logoSize / 2.0;
        ivHadi.layer.masksToBounds = YES;
        ivHadi.layer.borderWidth = 2.0;
        ivHadi.layer.borderColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0].CGColor;
        [topBar addSubview:ivHadi];
    }
    
    // Right Circular Logo: Error Expert (Size 72x72)
    UIImage *imgError = getImageFromBase64(kLogoErrorExpertBase64);
    if (imgError) {
        UIImageView *ivError = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 12 - logoSize, 52, logoSize, logoSize)];
        ivError.image = imgError;
        ivError.contentMode = UIViewContentModeScaleAspectFill;
        ivError.layer.cornerRadius = logoSize / 2.0;
        ivError.layer.masksToBounds = YES;
        ivError.layer.borderWidth = 2.0;
        ivError.layer.borderColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:1.0].CGColor;
        ivError.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [topBar addSubview:ivError];
    }
    
    // Header Title & Coordinates
    CGFloat centerW = self.view.bounds.size.width - 176;
    CGFloat centerX = 88;
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(centerX, 58, centerW, 26)];
    self.titleLabel.text = @"HADI MOD X ERROR EXPERT";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.75;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:self.titleLabel];
    
    self.coordsLabel = [[UILabel alloc] initWithFrame:CGRectMake(centerX, 86, centerW, 36)];
    self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f\nLon: %.5f", g_spoofLatitude, g_spoofLongitude];
    self.coordsLabel.numberOfLines = 2;
    self.coordsLabel.textColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.2 alpha:1.0];
    self.coordsLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.coordsLabel.textAlignment = NSTextAlignmentCenter;
    self.coordsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:self.coordsLabel];
    
    // WebKit Google Maps Configuration
    WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:self name:@"onMapCoord"];
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.userContentController = ucc;
    
    CGFloat bottomH = 165.0;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, topBarH, self.view.bounds.size.width, self.view.bounds.size.height - topBarH - bottomH) configuration:cfg];
    self.webView.navigationDelegate = self;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.webView];
    
    // Bottom Bar (3 Rows of Action Controls)
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - bottomH, self.view.bounds.size.width, bottomH)];
    bottomBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0];
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:bottomBar];
    
    CGFloat btnW = (self.view.bounds.size.width - 36) / 2.0;
    
    // Row 1: [+ SAVE PIN] and [* FAVORITES]
    self.btnSave = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSave.frame = CGRectMake(12, 8, btnW, 40);
    self.btnSave.backgroundColor = [UIColor colorWithRed:0.22 green:0.25 blue:0.32 alpha:1.0];
    self.btnSave.layer.cornerRadius = 8;
    [self.btnSave setTitle:@"+ SAVE PIN" forState:UIControlStateNormal];
    [self.btnSave setTitleColor:[UIColor colorWithRed:0.8 green:0.9 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.btnSave.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.btnSave addTarget:self action:@selector(savePinTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnSave];
    
    self.btnFav = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnFav.frame = CGRectMake(self.view.bounds.size.width - 12 - btnW, 8, btnW, 40);
    self.btnFav.backgroundColor = [UIColor colorWithRed:0.22 green:0.25 blue:0.32 alpha:1.0];
    self.btnFav.layer.cornerRadius = 8;
    [self.btnFav setTitle:@"* FAVORITES" forState:UIControlStateNormal];
    [self.btnFav setTitleColor:[UIColor colorWithRed:1.0 green:0.85 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    self.btnFav.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.btnFav addTarget:self action:@selector(openFavoritesTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnFav];
    
    // Row 2: [START SPOOF] and [STOP NORMAL]
    self.btnSpoof = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSpoof.frame = CGRectMake(12, 54, btnW, 44);
    self.btnSpoof.backgroundColor = g_spoofEnabled ? [UIColor colorWithRed:0.08 green:0.45 blue:0.25 alpha:1.0] : [UIColor colorWithRed:0.15 green:0.68 blue:0.38 alpha:1.0];
    self.btnSpoof.layer.cornerRadius = 10;
    [self.btnSpoof setTitle:g_spoofEnabled ? @"SPOOF ACTIVE" : @"START SPOOF" forState:UIControlStateNormal];
    [self.btnSpoof setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnSpoof.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btnSpoof addTarget:self action:@selector(startSpoofTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnSpoof];
    
    self.btnNormal = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnNormal.frame = CGRectMake(self.view.bounds.size.width - 12 - btnW, 54, btnW, 44);
    self.btnNormal.backgroundColor = g_spoofEnabled ? [UIColor colorWithRed:0.85 green:0.22 blue:0.22 alpha:1.0] : [UIColor colorWithRed:0.5 green:0.15 blue:0.15 alpha:1.0];
    self.btnNormal.layer.cornerRadius = 10;
    [self.btnNormal setTitle:g_spoofEnabled ? @"STOP NORMAL" : @"NORMAL ACTIVE" forState:UIControlStateNormal];
    [self.btnNormal setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnNormal.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btnNormal addTarget:self action:@selector(stopNormalTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnNormal];
    
    // Row 3: [TALABAT RESTAURANTS (Vol Down)]
    self.btnTalabat = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnTalabat.frame = CGRectMake(12, 106, self.view.bounds.size.width - 24, 46);
    self.btnTalabat.backgroundColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.0 alpha:1.0];
    self.btnTalabat.layer.cornerRadius = 10;
    [self.btnTalabat setTitle:@"TALABAT RESTAURANTS (Vol Down)" forState:UIControlStateNormal];
    [self.btnTalabat setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnTalabat.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btnTalabat addTarget:self action:@selector(fetchTalabatRestaurants) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnTalabat];
    
    // Bottom-Right Floating Close 'X' Button
    UIButton *btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    btnClose.frame = CGRectMake(self.view.bounds.size.width - 56, self.view.bounds.size.height - bottomH - 58, 46, 46);
    btnClose.backgroundColor = [UIColor colorWithRed:0.85 green:0.18 blue:0.18 alpha:0.95];
    btnClose.layer.cornerRadius = 23;
    btnClose.layer.masksToBounds = YES;
    btnClose.layer.borderWidth = 2.0;
    btnClose.layer.borderColor = [UIColor whiteColor].CGColor;
    [btnClose setTitle:@"X" forState:UIControlStateNormal];
    [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClose.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    btnClose.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [btnClose addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnClose];
    
    [self loadGoogleMap];
    
    // Hardware Volume Down Listener setup (without forcing audioSession active to prevent Talabat ringer conflict)
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    _lastVolume = [audioSession outputVolume];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChangedNotification:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)volumeChangedNotification:(NSNotification *)notif {
    NSDictionary *userInfo = notif.userInfo;
    float currentVol = [userInfo[@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    NSString *reason = userInfo[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"];
    
    // Detect Volume Down Press
    if (currentVol < _lastVolume || (currentVol <= _lastVolume && [reason isEqualToString:@"ExplicitVolumeChange"])) {
        [self fetchTalabatRestaurants];
    }
    _lastVolume = currentVol;
}

- (void)showToast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *toast = [[UILabel alloc] init];
        toast.text = msg;
        toast.textColor = [UIColor whiteColor];
        toast.backgroundColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.0 alpha:0.95];
        toast.font = [UIFont boldSystemFontOfSize:12];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.layer.cornerRadius = 16;
        toast.layer.masksToBounds = YES;
        toast.alpha = 0.0;
        
        CGSize sz = [msg sizeWithAttributes:@{NSFontAttributeName: toast.font}];
        CGFloat w = sz.width + 36;
        if (w > self.view.bounds.size.width - 40) w = self.view.bounds.size.width - 40;
        toast.frame = CGRectMake((self.view.bounds.size.width - w) / 2.0, 130, w, 32);
        [self.view addSubview:toast];
        
        [UIView animateWithDuration:0.3 animations:^{
            toast.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.4 delay:2.0 options:0 animations:^{
                toast.alpha = 0.0;
            } completion:^(BOOL fin) {
                [toast removeFromSuperview];
            }];
        }];
    });
}

- (void)fetchTalabatRestaurants {
    if (_isFetchingTalabat) {
        [self showToast:@"Still fetching restaurants..."];
        return;
    }
    _isFetchingTalabat = YES;
    [self showToast:@"Fetching Talabat restaurants..."];
    
    double lat = g_spoofLatitude;
    double lon = g_spoofLongitude;
    
    NSString *urlStr = [NSString stringWithFormat:@"https://vendors.talabat.com/vendor-list/v1/composite-list/%.6f/%.6f?page=1&size=500", lat, lon];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:@"GET"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setTimeoutInterval:15.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        _isFetchingTalabat = NO;
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"Failed to fetch restaurants"];
            });
            return;
        }
        
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        NSArray *vendors = json[@"vendors"];
        if (!vendors || ![vendors isKindOfClass:[NSArray class]] || vendors.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"No restaurants found nearby!"];
            });
            return;
        }
        
        NSMutableArray *list = [NSMutableArray array];
        for (NSDictionary *v in vendors) {
            if (![v isKindOfClass:[NSDictionary class]]) continue;
            
            NSString *name = v[@"bna"];
            if (!name || name.length == 0) name = v[@"na"];
            if (!name || name.length == 0) name = @"Restaurant";
            
            NSString *logo = v[@"lg"];
            if (!logo || logo.length == 0) logo = v[@"logo"];
            if (!logo || logo.length == 0) {
                NSDictionary *imgs = v[@"images"];
                if ([imgs isKindOfClass:[NSDictionary class]]) {
                    logo = imgs[@"lg"];
                }
            }
            if (logo && logo.length > 0 && ![logo hasPrefix:@"http"]) {
                logo = [@"https://images.deliveryhero.io/image/talabat/restaurants/" stringByAppendingString:logo];
            }
            
            double vLat = [v[@"latitude"] doubleValue];
            if (vLat == 0.0) vLat = [v[@"lat"] doubleValue];
            double vLon = [v[@"longitude"] doubleValue];
            if (vLon == 0.0) vLon = [v[@"lon"] doubleValue];
            
            if (vLat != 0.0 && vLon != 0.0) {
                [list addObject:@{
                    @"name": name,
                    @"logo": logo ?: @"",
                    @"lat": @(vLat),
                    @"lon": @(vLon)
                }];
            }
        }
        
        NSData *listJsonData = [NSJSONSerialization dataWithJSONObject:list options:0 error:nil];
        NSString *listJsonStr = [[NSString alloc] initWithData:listJsonData encoding:NSUTF8StringEncoding];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *js = [NSString stringWithFormat:@"renderTalabatRestaurants(%@);", listJsonStr];
            [self.webView evaluateJavaScript:js completionHandler:nil];
            [self showToast:[NSString stringWithFormat:@"Loaded %lu Talabat Restaurants!", (unsigned long)list.count]];
        });
    }];
    [task resume];
}

- (void)loadGoogleMap {
    NSString *html = [NSString stringWithFormat:@""
    "<!DOCTYPE html><html><head>"
    "<meta name='viewport' content='initial-scale=1.0, user-scalable=no' />"
    "<style>html,body,#map{height:100%%;margin:0;padding:0;}</style>"
    "<script src='https://maps.googleapis.com/maps/api/js?key=AIzaSyCNSBu4Vp9Ip6elthoLwAuxRAmLcoFWRHM'></script>"
    "<script>"
    "var map, marker;"
    "var talabatMarkers = [];"
    "function init() {"
    "  var pos = {lat: %f, lng: %f};"
    "  map = new google.maps.Map(document.getElementById('map'), {zoom: 14, center: pos, disableDefaultUI: false});"
    "  marker = new google.maps.Marker({position: pos, map: map, draggable: true});"
    "  google.maps.event.addListener(marker, 'dragend', function(e) {"
    "    notify(e.latLng.lat(), e.latLng.lng());"
    "  });"
    "  google.maps.event.addListener(map, 'click', function(e) {"
    "    marker.setPosition(e.latLng);"
    "    notify(e.latLng.lat(), e.latLng.lng());"
    "  });"
    "}"
    "function renderTalabatRestaurants(list) {"
    "  if (window.talabatMarkers) {"
    "    for (var i = 0; i < window.talabatMarkers.length; i++) {"
    "      window.talabatMarkers[i].setMap(null);"
    "    }"
    "  }"
    "  window.talabatMarkers = [];"
    "  if (!list || !list.length) return;"
    "  for (var i = 0; i < list.length; i++) {"
    "    var r = list[i];"
    "    var iconOpts = r.logo ? {"
    "      url: r.logo,"
    "      scaledSize: new google.maps.Size(32, 32)"
    "    } : {"
    "      path: google.maps.SymbolPath.CIRCLE,"
    "      scale: 8,"
    "      fillColor: '#FF5A00',"
    "      fillOpacity: 1,"
    "      strokeColor: '#FFFFFF',"
    "      strokeWeight: 2"
    "    };"
    "    var m = new google.maps.Marker({"
    "      position: {lat: r.lat, lng: r.lon},"
    "      map: map,"
    "      title: r.name,"
    "      icon: iconOpts"
    "    });"
    "    var info = new google.maps.InfoWindow({"
    "      content: '<div style=\"color:#000;font-weight:bold;font-size:12px;padding:4px;\">' + r.name + '</div>'"
    "    });"
    "    (function(mk, inf, rLat, rLng) {"
    "      mk.addListener('click', function() {"
    "        var p = {lat: rLat, lng: rLng};"
    "        if (marker) { marker.setPosition(p); }"
    "        map.panTo(p);"
    "        notify(rLat, rLng);"
    "        inf.open(map, mk);"
    "      });"
    "    })(m, info, r.lat, r.lon);"
    "    window.talabatMarkers.push(m);"
    "  }"
    "}"
    "function notify(lat, lng) {"
    "  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onMapCoord) {"
    "    window.webkit.messageHandlers.onMapCoord.postMessage({lat: lat, lng: lng});"
    "  }"
    "}"
    "function setMapPos(lat, lng) {"
    "  var pos = {lat: lat, lng: lng};"
    "  if (map && marker) {"
    "    marker.setPosition(pos);"
    "    map.panTo(pos);"
    "  }"
    "}"
    "</script></head><body onload='init()'><div id='map'></div></body></html>",
    g_spoofLatitude, g_spoofLongitude];
    
    [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:@"https://maps.google.com"]];
}

- (void)userContentController:(WKUserContentController *)ucc didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"onMapCoord"] && [message.body isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)message.body;
        NSNumber *lat = dict[@"lat"];
        NSNumber *lng = dict[@"lng"];
        if (lat && lng) {
            g_spoofLatitude = [lat doubleValue];
            g_spoofLongitude = [lng doubleValue];
            self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f\nLon: %.5f", g_spoofLatitude, g_spoofLongitude];
            
            // Persist modified coordinates immediately
            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            [defs setDouble:g_spoofLatitude forKey:kSpoofLatKey];
            [defs setDouble:g_spoofLongitude forKey:kSpoofLonKey];
            [defs synchronize];
            
            if (g_spoofEnabled) {
                triggerGlobalLocationUpdate();
            }
        }
    }
}

- (void)savePinTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Coordinate"
                                                                   message:@"Enter a name for this location pin:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"e.g. Dubai Mall / Station 1";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [NSString stringWithFormat:@"%.5f", g_spoofLatitude];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [NSString stringWithFormat:@"%.5f", g_spoofLongitude];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields[0].text;
        if (!name || name.length == 0) name = @"Pinned Location";
        double lat = [alert.textFields[1].text doubleValue];
        double lng = [alert.textFields[2].text doubleValue];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSMutableArray *favs = [[defs arrayForKey:kFavKey] mutableCopy];
        if (!favs) favs = [NSMutableArray array];
        
        NSDictionary *pin = @{@"name": name, @"lat": @(lat), @"lng": @(lng)};
        [favs addObject:pin];
        [defs setObject:favs forKey:kFavKey];
        [defs synchronize];
        
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Saved" message:[NSString stringWithFormat:@"%@ has been added to favorites!", name] preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:done animated:YES completion:nil];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openFavoritesTapped {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *favs = [defs arrayForKey:kFavKey];
    if (!favs || favs.count == 0) {
        UIAlertController *empty = [UIAlertController alertControllerWithTitle:@"No Favorites" message:@"You have not saved any location coordinates yet. Tap '+ SAVE PIN' to save your first spot!" preferredStyle:UIAlertControllerStyleAlert];
        [empty addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:empty animated:YES completion:nil];
        return;
    }
    
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Saved Favorites" message:@"Select a coordinate to jump to on map:" preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSDictionary *pin in favs) {
        NSString *title = [NSString stringWithFormat:@"%@ (%.4f, %.4f)", pin[@"name"], [pin[@"lat"] doubleValue], [pin[@"lng"] doubleValue]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            double lat = [pin[@"lat"] doubleValue];
            double lng = [pin[@"lng"] doubleValue];
            g_spoofLatitude = lat;
            g_spoofLongitude = lng;
            self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f\nLon: %.5f", lat, lng];
            
            // Persist selected coordinate
            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            [defs setDouble:g_spoofLatitude forKey:kSpoofLatKey];
            [defs setDouble:g_spoofLongitude forKey:kSpoofLonKey];
            [defs synchronize];
            
            NSString *js = [NSString stringWithFormat:@"setMapPos(%f, %f);", lat, lng];
            [self.webView evaluateJavaScript:js completionHandler:nil];
            if (g_spoofEnabled) {
                triggerGlobalLocationUpdate();
            }
            
            UIAlertController *prompt = [UIAlertController alertControllerWithTitle:pin[@"name"] message:@"Map centered on coordinate. Start spoofing here?" preferredStyle:UIAlertControllerStyleAlert];
            [prompt addAction:[UIAlertAction actionWithTitle:@"START SPOOF HERE" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [self startSpoofTapped];
            }]];
            [prompt addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:prompt animated:YES completion:nil];
        }]];
    }
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)startSpoofTapped {
    g_spoofEnabled = YES;
    self.btnSpoof.backgroundColor = [UIColor colorWithRed:0.08 green:0.45 blue:0.25 alpha:1.0];
    [self.btnSpoof setTitle:@"SPOOF ACTIVE" forState:UIControlStateNormal];
    self.btnNormal.backgroundColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.22 alpha:1.0];
    [self.btnNormal setTitle:@"STOP NORMAL" forState:UIControlStateNormal];
    
    // Auto-Save Spoof State and Coords to Disk
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:YES forKey:kSpoofEnabledKey];
    [defs setDouble:g_spoofLatitude forKey:kSpoofLatKey];
    [defs setDouble:g_spoofLongitude forKey:kSpoofLonKey];
    [defs synchronize];
    
    startGpsPulseTimer();
    triggerGlobalLocationUpdate();
}

- (void)stopNormalTapped {
    g_spoofEnabled = NO;
    stopGpsPulseTimer();
    self.btnSpoof.backgroundColor = [UIColor colorWithRed:0.15 green:0.68 blue:0.38 alpha:1.0];
    [self.btnSpoof setTitle:@"START SPOOF" forState:UIControlStateNormal];
    self.btnNormal.backgroundColor = [UIColor colorWithRed:0.5 green:0.15 blue:0.15 alpha:1.0];
    [self.btnNormal setTitle:@"NORMAL ACTIVE" forState:UIControlStateNormal];
    
    // Auto-Save Normal State to Disk
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:kSpoofEnabledKey];
    [defs synchronize];
    
    // Trigger update with real hardware location
    if (g_activeManagers) {
        for (CLLocationManager *mgr in [g_activeManagers allObjects]) {
            [mgr startUpdatingLocation];
        }
    }
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// ==========================================
// VPS AUTHENTICATION / LOGIN DIALOG (With Double-Size Logos)
// ==========================================
static void executeLogin(NSString *user, NSString *pass) {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    
    NSURL *url = [NSURL URLWithString:@"https://api.hadimod3.net/auth/customer/login"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *body = @{
        @"project": kProjectSlug,
        @"username": user,
        @"password": pass,
        @"deviceId": getOrCreateDeviceId()
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
            if (!err && http.statusCode == 200 && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *token = json[@"token"];
                if (token && token.length > 0) {
                    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                    [defs setBool:YES forKey:@"HadiMod_IsLoggedIn"];
                    [defs setObject:token forKey:@"HadiMod_Token"];
                    [defs setObject:user forKey:@"HadiMod_Username"];
                    
                    double expiry = extractExpiryFromJSON(json);
                    if (isJsonExplicitlyExpired(json) || (expiry > 0.0 && [[NSDate date] timeIntervalSince1970] >= expiry)) {
                        UIAlertController *expAlert = [UIAlertController alertControllerWithTitle:@"Account Expired"
                                                                                          message:@"Your account subscription has already expired. Please renew."
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                        [expAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        [root presentViewController:expAlert animated:YES completion:nil];
                        return;
                    }
                    if (expiry > 0.0) {
                        [defs setDouble:expiry forKey:@"HadiMod_Expiry"];
                    } else {
                        [defs removeObjectForKey:@"HadiMod_Expiry"];
                    }
                    [defs synchronize];
                    
                    startSessionWatcher();
                    
                    HadiModMapViewController *mapVC = [[HadiModMapViewController alloc] init];
                    mapVC.modalPresentationStyle = UIModalPresentationFullScreen;
                    [root presentViewController:mapVC animated:YES completion:nil];
                    return;
                }
            }
            
            NSString *errMsg = @"Invalid Username or Password";
            if (data) {
                NSDictionary *ej = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (ej[@"message"]) errMsg = ej[@"message"];
            }
            UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Login Failed"
                                                                              message:errMsg
                                                                       preferredStyle:UIAlertControllerStyleAlert];
            [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [root presentViewController:errAlert animated:YES completion:nil];
        });
    }];
    [task resume];
}

static void showLoginDialog(void) {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"\n\n\n\n\n\nHADI MOD X ERROR EXPERT"
                                                                   message:@"Enter your username and password to log in:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    CGFloat dlgLogoSize = 74.0;
    // Add Dual Circular Logos to Alert Dialog (Double Size 74x74)
    UIImage *imgHadi = getImageFromBase64(kLogoHadiModBase64);
    if (imgHadi) {
        UIImageView *ivHadi = [[UIImageView alloc] initWithFrame:CGRectMake(40, 16, dlgLogoSize, dlgLogoSize)];
        ivHadi.image = imgHadi;
        ivHadi.contentMode = UIViewContentModeScaleAspectFill;
        ivHadi.layer.cornerRadius = dlgLogoSize / 2.0;
        ivHadi.layer.masksToBounds = YES;
        ivHadi.layer.borderWidth = 2.0;
        ivHadi.layer.borderColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0].CGColor;
        [alert.view addSubview:ivHadi];
    }
    
    UIImage *imgError = getImageFromBase64(kLogoErrorExpertBase64);
    if (imgError) {
        UIImageView *ivError = [[UIImageView alloc] initWithFrame:CGRectMake(155, 16, dlgLogoSize, dlgLogoSize)];
        ivError.image = imgError;
        ivError.contentMode = UIViewContentModeScaleAspectFill;
        ivError.layer.cornerRadius = dlgLogoSize / 2.0;
        ivError.layer.masksToBounds = YES;
        ivError.layer.borderWidth = 2.0;
        ivError.layer.borderColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:1.0].CGColor;
        [alert.view addSubview:ivError];
    }
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Username";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Password";
        tf.secureTextEntry = YES;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *user = alert.textFields[0].text;
        NSString *pass = alert.textFields[1].text;
        if (!user || user.length == 0 || !pass || pass.length == 0) return;
        
        executeLogin(user, pass);
    }]];
    
    [root presentViewController:alert animated:YES completion:nil];
}

// ==========================================
// WINDOW GESTURE HOOK (2-Finger Double Tap)
// ==========================================
%hook UIWindow

- (void)didAddSubview:(UIView *)subview {
    %orig;
    dispatch_once(&g_windowOnceToken, ^{
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hadiModGestureTriggered:)];
        tap.numberOfTouchesRequired = 2;
        tap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:tap];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        BOOL loggedIn = [defs boolForKey:@"HadiMod_IsLoggedIn"];
        NSString *token = [defs stringForKey:@"HadiMod_Token"];
        if (loggedIn && token && token.length > 0) {
            startSessionWatcher();
        }
    });
}

%new
- (void)hadiModGestureTriggered:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        if (isCurrentSessionExpired()) {
            showRevokedAlert(@"Subscription Expired", @"Your subscription period has ended. Auto logged out.");
            return;
        }
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        BOOL loggedIn = [defs boolForKey:@"HadiMod_IsLoggedIn"];
        NSString *token = [defs stringForKey:@"HadiMod_Token"];
        
        if (loggedIn && token && token.length > 0) {
            UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (root.presentedViewController) {
                root = root.presentedViewController;
            }
            if ([root isKindOfClass:[HadiModMapViewController class]]) return;
            
            HadiModMapViewController *mapVC = [[HadiModMapViewController alloc] init];
            mapVC.modalPresentationStyle = UIModalPresentationFullScreen;
            [root presentViewController:mapVC animated:YES completion:nil];
        } else {
            showLoginDialog();
        }
    }
}

%end

// ==========================================
// AUTO-INITIALIZATION & RESTORE HOOK (%ctor)
// Runs immediately when dylib loads into Glovo/Talabat process
// ==========================================
%ctor {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    // Check if coordinates were previously saved
    double savedLat = [defs doubleForKey:kSpoofLatKey];
    double savedLon = [defs doubleForKey:kSpoofLonKey];
    if (savedLat != 0.0 && savedLon != 0.0) {
        g_spoofLatitude = savedLat;
        g_spoofLongitude = savedLon;
    }
    
    // Auto-Logout if subscription or credentials have expired
    if (isCurrentSessionExpired()) {
        g_spoofEnabled = NO;
        [defs setBool:NO forKey:@"HadiMod_IsLoggedIn"];
        [defs setBool:NO forKey:kSpoofEnabledKey];
        [defs removeObjectForKey:@"HadiMod_Token"];
        [defs removeObjectForKey:@"HadiMod_Expiry"];
        [defs removeObjectForKey:@"HadiMod_Username"];
        [defs synchronize];
        return;
    }
    
    // Restore spoofing only if session is active and not expired
    BOOL wasSpoofActive = [defs boolForKey:kSpoofEnabledKey];
    BOOL isLoggedIn = [defs boolForKey:@"HadiMod_IsLoggedIn"];
    NSString *token = [defs stringForKey:@"HadiMod_Token"];
    
    if (wasSpoofActive && isLoggedIn && token && token.length > 0) {
        g_spoofEnabled = YES;
        startGpsPulseTimer();
    }
}
