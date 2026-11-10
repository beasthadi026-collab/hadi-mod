// Language: Objective-C
// Target: iOS 13.0 - 18.x (arm64 / arm64e)
// Features: Full Working Architecture (CLLocationManager Swizzling + CLDelegateProxy + MKUserLocation Swizzling + Native Sideload Receipt Bypass + Leaflet Map)

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

// Global State
static BOOL g_spoofEnabled = NO;
static CLLocationDegrees g_spoofLatitude = 24.46094;
static CLLocationDegrees g_spoofLongitude = 54.35718;
static NSHashTable *g_activeManagers = nil;
static dispatch_source_t g_pulseTimer = nil;
static dispatch_once_t g_windowOnceToken = 0;

static NSString * const kFavKey = @"HadiModSavedFavorites";
static NSString * const kSpoofEnabledKey = @"HadiMod_SpoofEnabled";
static NSString * const kSpoofLatKey     = @"HadiMod_SpoofLatitude";
static NSString * const kSpoofLonKey     = @"HadiMod_SpoofLongitude";

// Forward declarations
static CLLocation *getFreshOverrideLocation(void);
static void triggerLocationBroadcast(void);
static void startPulseTimer(void);
static void stopPulseTimer(void);

// ==========================================
// 1. FRESH OVERRIDE LOCATION BUILDER
// ==========================================
static CLLocation *getFreshOverrideLocation(void) {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(g_spoofLatitude, g_spoofLongitude);
    return [[CLLocation alloc] initWithCoordinate:coord
                                         altitude:30.0
                               horizontalAccuracy:5.0
                                 verticalAccuracy:5.0
                                           course:0.0
                                            speed:0.0
                                        timestamp:[NSDate date]];
}

// ==========================================
// 2. NATIVE SIDELOAD RECEIPT BYPASS (AYMAN Pattern)
// Bypasses AppStore receipt check during Talabat authentication
// ==========================================
@interface AYMANSideloadBypass : NSObject
@end

@implementation AYMANSideloadBypass

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [NSBundle class];
        SEL origSel = @selector(appStoreReceiptURL);
        SEL swizSel = @selector(swizzled_appStoreReceiptURL);
        
        Method origMethod = class_getInstanceMethod(cls, origSel);
        Method swizMethod = class_getInstanceMethod([self class], swizSel);
        
        if (origMethod && swizMethod) {
            BOOL didAdd = class_addMethod(cls, swizSel, method_getImplementation(swizMethod), method_getTypeEncoding(swizMethod));
            if (didAdd) {
                Method newSwiz = class_getInstanceMethod(cls, swizSel);
                method_exchangeImplementations(origMethod, newSwiz);
            } else {
                method_exchangeImplementations(origMethod, swizMethod);
            }
        }
    });
}

- (NSURL *)swizzled_appStoreReceiptURL {
    NSURL *url = [self swizzled_appStoreReceiptURL];
    if (url && [[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        return url;
    }
    
    // Provide a valid sandbox receipt container
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupport = paths.firstObject;
    if (appSupport) {
        NSString *storeKit = [appSupport stringByAppendingPathComponent:@"StoreKit"];
        [[NSFileManager defaultManager] createDirectoryAtPath:storeKit withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *receiptPath = [storeKit stringByAppendingPathComponent:@"receipt"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:receiptPath]) {
            NSData *dummy = [@"STOREKIT_VALID_RECEIPT_TOKEN" dataUsingEncoding:NSUTF8StringEncoding];
            [dummy writeToFile:receiptPath atomically:YES];
        }
        return [NSURL fileURLWithPath:receiptPath];
    }
    return url;
}

@end

// ==========================================
// 3. TRANSPARENT CLDelegateProxy (Exact Working Pattern)
// Preserves original delegate & forwardInvocation while overriding location
// ==========================================
@interface CLDelegateProxy : NSProxy <CLLocationManagerDelegate>
@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) CLLocationManager *manager;
- (instancetype)initWithDelegate:(id)delegate manager:(CLLocationManager *)mgr;
@end

@implementation CLDelegateProxy

- (instancetype)initWithDelegate:(id)delegate manager:(CLLocationManager *)mgr {
    _delegate = delegate;
    _manager = mgr;
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(locationManager:didUpdateLocations:) ||
        aSelector == @selector(locationManager:didUpdateToLocation:fromLocation:)) {
        return YES;
    }
    return [_delegate respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    if (_delegate) {
        return [_delegate methodSignatureForSelector:sel];
    }
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if (_delegate && [_delegate respondsToSelector:[invocation selector]]) {
        [invocation invokeWithTarget:_delegate];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (g_spoofEnabled) {
        CLLocation *fake = getFreshOverrideLocation();
        if (_delegate && [_delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [_delegate locationManager:manager didUpdateLocations:@[fake]];
            return;
        }
    }
    if (_delegate && [_delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [_delegate locationManager:manager didUpdateLocations:locations];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if (g_spoofEnabled) {
        CLLocation *fake = getFreshOverrideLocation();
        if (_delegate && [_delegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
            [_delegate locationManager:manager didUpdateToLocation:fake fromLocation:oldLocation];
            return;
        }
    }
    if (_delegate && [_delegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
        [_delegate locationManager:manager didUpdateToLocation:newLocation fromLocation:oldLocation];
    }
}

@end

// ==========================================
// 4. CLLocationManager (Swizzling Category - Exact Working Binary Pattern)
// ==========================================
@interface CLLocationManager (Swizzling)
- (void)swizzled_setDelegate:(id<CLLocationManagerDelegate>)delegate;
- (CLLocation *)swizzled_location;
@end

@implementation CLLocationManager (Swizzling)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [CLLocationManager class];
        
        // 1. Swizzle setDelegate:
        SEL origSetDel = @selector(setDelegate:);
        SEL swizSetDel = @selector(swizzled_setDelegate:);
        Method m1 = class_getInstanceMethod(cls, origSetDel);
        Method m2 = class_getInstanceMethod(cls, swizSetDel);
        if (m1 && m2) {
            method_exchangeImplementations(m1, m2);
        }
        
        // 2. Swizzle location getter
        SEL origLoc = @selector(location);
        SEL swizLoc = @selector(swizzled_location);
        Method m3 = class_getInstanceMethod(cls, origLoc);
        Method m4 = class_getInstanceMethod(cls, swizLoc);
        if (m3 && m4) {
            method_exchangeImplementations(m3, m4);
        }
    });
}

- (void)swizzled_setDelegate:(id<CLLocationManagerDelegate>)delegate {
    if (!g_activeManagers) {
        g_activeManagers = [NSHashTable weakObjectsHashTable];
    }
    [g_activeManagers addObject:self];
    
    if (delegate && ![delegate isKindOfClass:[CLDelegateProxy class]]) {
        CLDelegateProxy *proxy = [[CLDelegateProxy alloc] initWithDelegate:delegate manager:self];
        objc_setAssociatedObject(self, "HadiCLDelegateProxyAssocKey", proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self swizzled_setDelegate:(id<CLLocationManagerDelegate>)proxy];
        return;
    }
    [self swizzled_setDelegate:delegate];
}

- (CLLocation *)swizzled_location {
    if (g_spoofEnabled) {
        return getFreshOverrideLocation();
    }
    return [self swizzled_location];
}

@end

// ==========================================
// 5. MKUserLocation (Swizzling Category - Exact Working Binary Pattern)
// ==========================================
@interface MKUserLocation (Swizzling)
- (CLLocation *)swizzled_location;
- (CLLocationCoordinate2D)swizzled_coordinate;
@end

@implementation MKUserLocation (Swizzling)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [MKUserLocation class];
        
        SEL origLoc = @selector(location);
        SEL swizLoc = @selector(swizzled_location);
        Method m1 = class_getInstanceMethod(cls, origLoc);
        Method m2 = class_getInstanceMethod(cls, swizLoc);
        if (m1 && m2) method_exchangeImplementations(m1, m2);
        
        SEL origCoord = @selector(coordinate);
        SEL swizCoord = @selector(swizzled_coordinate);
        Method m3 = class_getInstanceMethod(cls, origCoord);
        Method m4 = class_getInstanceMethod(cls, swizCoord);
        if (m3 && m4) method_exchangeImplementations(m3, m4);
    });
}

- (CLLocation *)swizzled_location {
    if (g_spoofEnabled) {
        return getFreshOverrideLocation();
    }
    return [self swizzled_location];
}

- (CLLocationCoordinate2D)swizzled_coordinate {
    if (g_spoofEnabled) {
        return CLLocationCoordinate2DMake(g_spoofLatitude, g_spoofLongitude);
    }
    return [self swizzled_coordinate];
}

@end

// ==========================================
// 6. BROADCAST TIMER & NOTIFICATION DISPATCH
// ==========================================
static void triggerLocationBroadcast(void) {
    if (!g_activeManagers) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        CLLocation *loc = getFreshOverrideLocation();
        for (CLLocationManager *mgr in [g_activeManagers allObjects]) {
            if (mgr.delegate && [mgr.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [mgr.delegate locationManager:mgr didUpdateLocations:@[loc]];
            }
        }
    });
}

static void startPulseTimer(void) {
    if (g_pulseTimer) return;
    dispatch_queue_t queue = dispatch_get_main_queue();
    g_pulseTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(g_pulseTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 1 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(g_pulseTimer, ^{
        if (g_spoofEnabled) {
            triggerLocationBroadcast();
        }
    });
    dispatch_resume(g_pulseTimer);
}

static void stopPulseTimer(void) {
    if (g_pulseTimer) {
        dispatch_source_cancel(g_pulseTimer);
        g_pulseTimer = nil;
    }
}

// ==========================================
// 7. MAP VIEW CONTROLLER (Leaflet + Talabat Scanner)
// ==========================================
@interface HadiModMapViewController : UIViewController <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *coordsLabel;
@property (nonatomic, strong) UIButton *btnSpoof;
@property (nonatomic, strong) UIButton *btnNormal;
@property (nonatomic, strong) UIButton *btnSave;
@property (nonatomic, strong) UIButton *btnFav;
@property (nonatomic, strong) UIButton *btnTalabat;
@end

@implementation HadiModMapViewController {
    float _lastVolume;
    BOOL _isFetchingTalabat;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
    _isFetchingTalabat = NO;
    
    CGFloat topBarH = 120.0;
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, topBarH)];
    topBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topBar];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 44, self.view.bounds.size.width - 32, 34)];
    self.titleLabel.text = @"HADI MOD GPS CONTROLLER";
    self.titleLabel.textColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.0 alpha:1.0];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:self.titleLabel];
    
    self.coordsLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 80, self.view.bounds.size.width - 32, 22)];
    self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", g_spoofLatitude, g_spoofLongitude];
    self.coordsLabel.textColor = [UIColor whiteColor];
    self.coordsLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.coordsLabel.textAlignment = NSTextAlignmentCenter;
    self.coordsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:self.coordsLabel];
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:self name:@"coordinateHandler"];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.navigationDelegate = self;
    [self.view addSubview:self.webView];
    
    CGFloat bottomH = 100.0;
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - bottomH, self.view.bounds.size.width, bottomH)];
    bottomBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:0.95];
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:bottomBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor]
    ]];
    
    CGFloat btnW = (self.view.bounds.size.width - 40) / 2.0;
    self.btnSpoof = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSpoof.frame = CGRectMake(15, 10, btnW, 36);
    self.btnSpoof.backgroundColor = g_spoofEnabled ? [UIColor colorWithRed:0.08 green:0.45 blue:0.25 alpha:1.0] : [UIColor colorWithRed:0.18 green:0.20 blue:0.25 alpha:1.0];
    self.btnSpoof.layer.cornerRadius = 8;
    [self.btnSpoof setTitle:@"START SPOOF" forState:UIControlStateNormal];
    [self.btnSpoof setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnSpoof.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.btnSpoof addTarget:self action:@selector(startSpoofTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnSpoof];
    
    self.btnNormal = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnNormal.frame = CGRectMake(25 + btnW, 10, btnW, 36);
    self.btnNormal.backgroundColor = [UIColor colorWithRed:0.75 green:0.22 blue:0.17 alpha:1.0];
    self.btnNormal.layer.cornerRadius = 8;
    [self.btnNormal setTitle:@"STOP / NORMAL" forState:UIControlStateNormal];
    [self.btnNormal setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnNormal.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.btnNormal addTarget:self action:@selector(stopSpoofTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnNormal];
    
    CGFloat btnW3 = (self.view.bounds.size.width - 50) / 3.0;
    self.btnSave = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSave.frame = CGRectMake(15, 54, btnW3, 34);
    self.btnSave.backgroundColor = [UIColor colorWithRed:0.20 green:0.22 blue:0.28 alpha:1.0];
    self.btnSave.layer.cornerRadius = 8;
    [self.btnSave setTitle:@"+ SAVE PIN" forState:UIControlStateNormal];
    [self.btnSave setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnSave.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.btnSave addTarget:self action:@selector(savePinTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnSave];
    
    self.btnFav = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnFav.frame = CGRectMake(25 + btnW3, 54, btnW3, 34);
    self.btnFav.backgroundColor = [UIColor colorWithRed:0.20 green:0.22 blue:0.28 alpha:1.0];
    self.btnFav.layer.cornerRadius = 8;
    [self.btnFav setTitle:@"FAVORITES" forState:UIControlStateNormal];
    [self.btnFav setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnFav.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.btnFav addTarget:self action:@selector(openFavoritesTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnFav];
    
    self.btnTalabat = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnTalabat.frame = CGRectMake(35 + (btnW3 * 2), 54, btnW3, 34);
    self.btnTalabat.backgroundColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.0 alpha:1.0];
    self.btnTalabat.layer.cornerRadius = 8;
    [self.btnTalabat setTitle:@"TALABAT" forState:UIControlStateNormal];
    [self.btnTalabat setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnTalabat.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.btnTalabat addTarget:self action:@selector(fetchTalabatRestaurants) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnTalabat];
    
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChangedNotification:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)volumeChangedNotification:(NSNotification *)notif {
    NSDictionary *userInfo = notif.userInfo;
    float currentVol = [userInfo[@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    if (currentVol < _lastVolume) {
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
        
        [UIView animateWithDuration:0.25 animations:^{
            toast.alpha = 1.0;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    toast.alpha = 0.0;
                } completion:^(BOOL fin) {
                    [toast removeFromSuperview];
                }];
            });
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
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        _isFetchingTalabat = NO;
        if (err || !data) {
            [self showToast:@"Failed to fetch restaurants"];
            return;
        }
        
        NSError *jsonErr = nil;
        NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || !root) {
            [self showToast:@"Invalid restaurant data"];
            return;
        }
        
        NSArray *vendors = root[@"vendors"] ?: root[@"items"] ?: root[@"data"];
        if (!vendors || vendors.count == 0) {
            [self showToast:@"No restaurants found here"];
            return;
        }
        
        NSMutableArray *markers = [NSMutableArray array];
        for (NSDictionary *v in vendors) {
            NSString *name = v[@"name"] ?: v[@"title"] ?: @"Restaurant";
            name = [name stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            name = [name stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            
            double vLat = [v[@"latitude"] doubleValue] ?: [v[@"lat"] doubleValue];
            double vLon = [v[@"longitude"] doubleValue] ?: [v[@"lng"] doubleValue];
            
            if (vLat == 0.0 && [v[@"location"] isKindOfClass:[NSDictionary class]]) {
                vLat = [v[@"location"][@"latitude"] doubleValue];
                vLon = [v[@"location"][@"longitude"] doubleValue];
            }
            
            if (vLat != 0.0 && vLon != 0.0) {
                [markers addObject:@{@"name": name, @"lat": @(vLat), @"lng": @(vLon)}];
            }
        }
        
        NSData *markersData = [NSJSONSerialization dataWithJSONObject:markers options:0 error:nil];
        NSString *markersJson = [[NSString alloc] initWithData:markersData encoding:NSUTF8StringEncoding];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *js = [NSString stringWithFormat:@"if (window.renderTalabatMarkers) { window.renderTalabatMarkers(%@); }", markersJson];
            [self.webView evaluateJavaScript:js completionHandler:nil];
            [self showToast:[NSString stringWithFormat:@"Loaded %lu Restaurants!", (unsigned long)markers.count]];
        });
    }];
    [task resume];
}

- (void)loadGoogleMap {
    NSString *html = [NSString stringWithFormat:
    @"<!DOCTYPE html>"
    @"<html>"
    @"<head>"
    @"<meta name='viewport' content='initial-scale=1.0, user-scalable=no, width=device-width' />"
    @"<link rel='stylesheet' href='https://unpkg.com/leaflet@1.9.4/dist/leaflet.css' />"
    @"<script src='https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'></script>"
    @"<style>"
    @"  html, body, #map { height: 100%%; width: 100%%; margin: 0; padding: 0; background-color: #121417; }"
    @"  .leaflet-popup-content-wrapper { background: #1c1f26; color: #fff; border-radius: 8px; font-weight: bold; font-size: 13px; }"
    @"  .leaflet-popup-tip { background: #1c1f26; }"
    @"</style>"
    @"</head>"
    @"<body>"
    @"<div id='map'></div>"
    @"<script>"
    @"  var map = L.map('map', { zoomControl: false }).setView([%f, %f], 14);"
    @"  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {"
    @"    maxZoom: 19,"
    @"    attribution: 'Hadi Mod'"
    @"  }).addTo(map);"
    @"  var mainMarker = L.marker([%f, %f], { draggable: true }).addTo(map);"
    @"  mainMarker.bindPopup('Target Location').openPopup();"
    @"  mainMarker.on('dragend', function(e) {"
    @"    var coord = mainMarker.getLatLng();"
    @"    window.webkit.messageHandlers.coordinateHandler.postMessage({ lat: coord.lat, lng: coord.lng });"
    @"  });"
    @"  map.on('click', function(e) {"
    @"    mainMarker.setLatLng(e.latlng);"
    @"    window.webkit.messageHandlers.coordinateHandler.postMessage({ lat: e.latlng.lat, lng: e.latlng.lng });"
    @"  });"
    @"  var talabatLayer = L.layerGroup().addTo(map);"
    @"  window.renderTalabatMarkers = function(list) {"
    @"    talabatLayer.clearLayers();"
    @"    list.forEach(function(item) {"
    @"      var m = L.circleMarker([item.lat, item.lng], {"
    @"        radius: 6,"
    @"        fillColor: '#ff5a00',"
    @"        color: '#ffffff',"
    @"        weight: 1.5,"
    @"        opacity: 1,"
    @"        fillOpacity: 0.9"
    @"      }).addTo(talabatLayer);"
    @"      m.bindPopup('<b>' + item.name + '</b>');"
    @"    });"
    @"  };"
    @"  window.centerToCoord = function(lat, lng) {"
    @"    mainMarker.setLatLng([lat, lng]);"
    @"    map.setView([lat, lng], 15);"
    @"  };"
    @"</script>"
    @"</body>"
    @"</html>", g_spoofLatitude, g_spoofLongitude, g_spoofLatitude, g_spoofLongitude];
    
    [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:@"https://osm.org"]];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"coordinateHandler"]) {
        NSDictionary *coords = (NSDictionary *)message.body;
        if ([coords isKindOfClass:[NSDictionary class]]) {
            double lat = [coords[@"lat"] doubleValue];
            double lng = [coords[@"lng"] doubleValue];
            
            g_spoofLatitude = lat;
            g_spoofLongitude = lng;
            self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", lat, lng];
            
            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            [defs setDouble:g_spoofLatitude forKey:kSpoofLatKey];
            [defs setDouble:g_spoofLongitude forKey:kSpoofLonKey];
            [defs synchronize];
            
            if (g_spoofEnabled) {
                triggerLocationBroadcast();
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
        double lat = [alert.textFields[1].text doubleValue];
        double lng = [alert.textFields[2].text doubleValue];
        if (name.length == 0) name = [NSString stringWithFormat:@"Pin %.4f, %.4f", lat, lng];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSMutableArray *favs = [[defs arrayForKey:kFavKey] mutableCopy];
        if (!favs) favs = [NSMutableArray array];
        
        [favs addObject:@{@"name": name, @"lat": @(lat), @"lng": @(lng)}];
        [defs setObject:favs forKey:kFavKey];
        [defs synchronize];
        
        [self showToast:[NSString stringWithFormat:@"Saved: %@", name]];
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
            
            NSString *js = [NSString stringWithFormat:@"if (window.centerToCoord) { window.centerToCoord(%f, %f); }", lat, lng];
            [self.webView evaluateJavaScript:js completionHandler:nil];
            
            if (g_spoofEnabled) {
                triggerLocationBroadcast();
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
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:YES forKey:kSpoofEnabledKey];
    [defs setDouble:g_spoofLatitude forKey:kSpoofLatKey];
    [defs setDouble:g_spoofLongitude forKey:kSpoofLonKey];
    [defs synchronize];
    
    triggerLocationBroadcast();
    startPulseTimer();
    [self showToast:@"GPS Spoofing Started!"];
}

- (void)stopSpoofTapped {
    g_spoofEnabled = NO;
    self.btnSpoof.backgroundColor = [UIColor colorWithRed:0.18 green:0.20 blue:0.25 alpha:1.0];
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:kSpoofEnabledKey];
    [defs synchronize];
    
    stopPulseTimer();
    [self showToast:@"GPS Returned to Real Normal"];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// ==========================================
// 8. UIWINDOW HOOK (3-Finger Tap - Exact Working Binary Pattern)
// ==========================================
@interface UIWindow (AYMANGesture)
- (void)swizzled_makeKeyAndVisible;
@end

@implementation UIWindow (AYMANGesture)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [UIWindow class];
        SEL orig = @selector(makeKeyAndVisible);
        SEL swiz = @selector(swizzled_makeKeyAndVisible);
        Method m1 = class_getInstanceMethod(cls, orig);
        Method m2 = class_getInstanceMethod(cls, swiz);
        if (m1 && m2) method_exchangeImplementations(m1, m2);
    });
}

- (void)swizzled_makeKeyAndVisible {
    [self swizzled_makeKeyAndVisible];
    dispatch_once(&g_windowOnceToken, ^{
        UITapGestureRecognizer *threeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hadiGestureTriggered:)];
        threeTap.numberOfTouchesRequired = 2; // 2 fingers for easy trigger
        threeTap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:threeTap];
    });
}

- (void)hadiGestureTriggered:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (root.presentedViewController) {
            root = root.presentedViewController;
        }
        if ([root isKindOfClass:[HadiModMapViewController class]]) return;
        
        HadiModMapViewController *mapVC = [[HadiModMapViewController alloc] init];
        mapVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [root presentViewController:mapVC animated:YES completion:nil];
    }
}

@end

// ==========================================
// 9. CONSTRUCTOR (%ctor)
// ==========================================
%ctor {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    double savedLat = [defs doubleForKey:kSpoofLatKey];
    double savedLon = [defs doubleForKey:kSpoofLonKey];
    if (savedLat != 0.0 && savedLon != 0.0) {
        g_spoofLatitude = savedLat;
        g_spoofLongitude = savedLon;
    }
    
    BOOL wasSpoofActive = [defs boolForKey:kSpoofEnabledKey];
    if (wasSpoofActive) {
        g_spoofEnabled = YES;
        startPulseTimer();
    }
}
