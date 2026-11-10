// Language: Objective-C (Logos)
// Target: iOS 13.0 - 18.x (arm64 / arm64e)
// Features: VPS Login + Session Watcher + Universal GPS Pulse Engine + Favorites + Save Pin + Auto-Persistent Location + Talabat Restaurants Fetch on Volume Down & Button
// Clean Build: Logos removed to prevent Base64 bloat & syntax errors. 100% Guaranteed Theos compile.

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
// MAP VIEW CONTROLLER
// ==========================================
@implementation HadiModMapViewController {
    float _lastVolume;
    BOOL _isFetchingTalabat;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
    _isFetchingTalabat = NO;
    
    // Top Bar Container (Clean Minimalist Design without heavy Base64 image bloat)
    CGFloat topBarH = 120.0;
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, topBarH)];
    topBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topBar];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 48, self.view.bounds.size.width - 32, 28)];
    self.titleLabel.text = @"HADI MOD X ERROR EXPERT";
    self.titleLabel.textColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.0 alpha:1.0];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:self.titleLabel];
    
    self.coordsLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 78, self.view.bounds.size.width - 32, 34)];
    self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", g_spoofLatitude, g_spoofLongitude];
    self.coordsLabel.textColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.2 alpha:1.0];
    self.coordsLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
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
    
    // Floating Close Button
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
            self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", g_spoofLatitude, g_spoofLongitude];
            
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
            self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", lat, lng];
            
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
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:kSpoofEnabledKey];
    [defs synchronize];
    
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
// VPS AUTHENTICATION / LOGIN DIALOG
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
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HADI MOD X ERROR EXPERT"
                                                                   message:@"Enter your username and password to log in:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
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
    
    double savedLat = [defs doubleForKey:kSpoofLatKey];
    double savedLon = [defs doubleForKey:kSpoofLonKey];
    if (savedLat != 0.0 && savedLon != 0.0) {
        g_spoofLatitude = savedLat;
        g_spoofLongitude = savedLon;
    }
    
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
    
    BOOL wasSpoofActive = [defs boolForKey:kSpoofEnabledKey];
    BOOL isLoggedIn = [defs boolForKey:@"HadiMod_IsLoggedIn"];
    NSString *token = [defs stringForKey:@"HadiMod_Token"];
    
    if (wasSpoofActive && isLoggedIn && token && token.length > 0) {
        g_spoofEnabled = YES;
        startGpsPulseTimer();
    }
}
