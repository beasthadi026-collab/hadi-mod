// ============================================================================
//            HADI TALABAT RIDER TWEAK — PRODUCTION BUILD (Tweak.x)
//    - AppStore Receipt Bypass (Bypasses "Unauthorized rider app")
//    - Real-Time VPS Panel Hardware Lock (1:1 Key Bound to Device HWID on Panel)
//    - Pure Native Apple MapKit (MKMapView) — Instant rendering, 100% reliable
// ============================================================================

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

// -------------------------------------------------------------
// 1. TALABAT UNAUTHORIZED APP STORE RECEIPT BYPASS
// -------------------------------------------------------------
@interface NSBundle (TalabatAuthorizedBypass)
- (NSURL *)talabat_appStoreReceiptURL;
@end

@implementation NSBundle (TalabatAuthorizedBypass)
- (NSURL *)talabat_appStoreReceiptURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupport = paths.firstObject;
    NSString *receiptDir = [appSupport stringByAppendingPathComponent:@"StoreKit"];
    NSString *receiptPath = [receiptDir stringByAppendingPathComponent:@"receipt"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:receiptPath]) {
        [fm createDirectoryAtPath:receiptDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSData *receiptData = [@"STOREKIT_VALID_RECEIPT_TOKEN" dataUsingEncoding:NSUTF8StringEncoding];
        [receiptData writeToFile:receiptPath atomically:YES];
    }
    return [NSURL fileURLWithPath:receiptPath];
}
@end

// -------------------------------------------------------------
// 2. REAL-TIME SERVER HARDWARE LOCK ENGINE (VPS Panel Binding)
// -------------------------------------------------------------
@interface HadiLicenseEngine : NSObject
+ (BOOL)isDeviceActivated;
+ (NSString *)getDeviceHardwareFingerprint;
+ (void)validateAndBindKey:(NSString *)enteredKey completion:(void(^)(BOOL success, NSString *errorMsg))completion;
+ (void)showActivationPromptOn:(UIViewController *)vc completion:(void(^)(BOOL success))completion;
@end

@implementation HadiLicenseEngine

+ (NSString *)getDeviceHardwareFingerprint {
    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (!uuid.length) {
        uuid = @"HADI-IPHONE-HARDWARE-ID";
    }
    return [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""].uppercaseString;
}

+ (BOOL)isDeviceActivated {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *activeKey = [defs stringForKey:@"HadiMod_ActiveLicense"];
    NSString *boundDev = [defs stringForKey:@"HadiMod_BoundDevice"];
    NSString *currentDev = [self getDeviceHardwareFingerprint];

    if (!activeKey.length || !boundDev.length) return NO;
    if (![boundDev isEqualToString:currentDev]) return NO;
    return YES;
}

+ (void)validateAndBindKey:(NSString *)enteredKey completion:(void(^)(BOOL success, NSString *errorMsg))completion {
    NSString *cleanKey = [enteredKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].uppercaseString;
    if (cleanKey.length < 8) {
        if (completion) completion(NO, @"Invalid Key Length!");
        return;
    }

    NSString *deviceFp = [self getDeviceHardwareFingerprint];

    NSString *urlStr = [NSString stringWithFormat:@"https://203.175.11.15.nip.io/admin/bind_dylib?key=%@&hwid=%@", cleanKey, deviceFp];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10.0];
    [req setHTTPMethod:@"GET"];

    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if (completion) completion(NO, @"Cannot reach license server. Check internet!");
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL success = [json[@"success"] boolValue];
            if (success) {
                NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                [defs setObject:cleanKey forKey:@"HadiMod_ActiveLicense"];
                [defs setObject:deviceFp forKey:@"HadiMod_BoundDevice"];
                [defs synchronize];
                if (completion) completion(YES, nil);
            } else {
                NSString *err = json[@"error"] ?: @"Key is locked to another iPhone!";
                if (completion) completion(NO, err);
            }
        });
    }] resume];
}

+ (void)showActivationPromptOn:(UIViewController *)vc completion:(void(^)(BOOL success))completion {
    if (!vc) {
        vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ HADI DYLIB ACTIVATION"
                                                                   message:@"Enter your VIP license key generated from the panel."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"VIP-XXXX-YYYY-30";
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.textAlignment = NSTextAlignmentCenter;
    }];

    UIAlertAction *activateAction = [UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        [self validateAndBindKey:key completion:^(BOOL success, NSString *errorMsg) {
            if (success) {
                UIAlertController *succ = [UIAlertController alertControllerWithTitle:@"Activated!"
                                                                              message:@"Key successfully bound to this iPhone on the server."
                                                                       preferredStyle:UIAlertControllerStyleAlert];
                [succ addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    if (completion) completion(YES);
                }]];
                [vc presentViewController:succ animated:YES completion:nil];
            } else {
                UIAlertController *fail = [UIAlertController alertControllerWithTitle:@"Activation Failed"
                                                                              message:errorMsg ?: @"Key is invalid or locked to another device."
                                                                       preferredStyle:UIAlertControllerStyleAlert];
                [fail addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    [self showActivationPromptOn:vc completion:completion];
                }]];
                [vc presentViewController:fail animated:YES completion:nil];
            }
        }];
    }];

    [alert addAction:activateAction];
    [vc presentViewController:alert animated:YES completion:nil];
}

@end

// -------------------------------------------------------------
// 3. SECURE FORWARDING CLDELEGATEPROXY
// -------------------------------------------------------------
@interface HadiCLDelegateProxy : NSObject <CLLocationManagerDelegate>
@property (nonatomic, weak) id<CLLocationManagerDelegate> realDelegate;
@property (nonatomic, weak) CLLocationManager *manager;
- (instancetype)initWithRealDelegate:(id<CLLocationManagerDelegate>)real manager:(CLLocationManager *)mgr;
@end

@implementation HadiCLDelegateProxy

- (instancetype)initWithRealDelegate:(id<CLLocationManagerDelegate>)real manager:(CLLocationManager *)mgr {
    self = [super init];
    if (self) {
        _realDelegate = real;
        _manager = mgr;
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector]) return YES;
    return [_realDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return _realDelegate;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (![HadiLicenseEngine isDeviceActivated]) {
        if ([_realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [_realDelegate locationManager:manager didUpdateLocations:locations];
        }
        return;
    }

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs boolForKey:@"HadiMod_SpoofEnabled"]) {
        double lat = [defs doubleForKey:@"HadiMod_SpoofLatitude"];
        double lon = [defs doubleForKey:@"HadiMod_SpoofLongitude"];
        if (lat != 0.0 && lon != 0.0) {
            CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                               altitude:15.0
                                                     horizontalAccuracy:5.0
                                                       verticalAccuracy:5.0
                                                              timestamp:[NSDate date]];
            if ([_realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [_realDelegate locationManager:manager didUpdateLocations:@[spoofed]];
            }
            return;
        }
    }

    if ([_realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [_realDelegate locationManager:manager didUpdateLocations:locations];
    }
}

@end

// -------------------------------------------------------------
// 4. PURE NATIVE APPLE MAPKIT CONTROLLER (NO WEBVIEW - ZERO BLOCKS)
// -------------------------------------------------------------
static NSString *const kHadiPinID = @"HadiPinAnnotation";

@interface HadiModMapViewController : UIViewController <MKMapViewDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UIButton *btnToggle;
@property (nonatomic, strong) UIButton *btnDubai;
@property (nonatomic, strong) UILabel *lblCoords;
@property (nonatomic, assign) BOOL isSpoofing;
@property (nonatomic, assign) CLLocationCoordinate2D currentCoords;
@end

@implementation HadiModMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Explicit sizing guaranteed to render
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat pad = 12.0;
    CGFloat cardW = screenW - (pad * 2);
    CGFloat cardH = 460.0;
    
    self.view.frame = CGRectMake(pad, 70, cardW, cardH);
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.14 alpha:0.98];
    self.view.layer.cornerRadius = 20.0;
    self.view.layer.masksToBounds = YES;
    self.view.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.8].CGColor;
    self.view.layer.borderWidth = 1.5;

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    self.isSpoofing = [defs boolForKey:@"HadiMod_SpoofEnabled"];
    double lat = [defs doubleForKey:@"HadiMod_SpoofLatitude"];
    double lon = [defs doubleForKey:@"HadiMod_SpoofLongitude"];
    if (lat == 0.0 && lon == 0.0) {
        lat = 25.2048; // Dubai
        lon = 55.2708;
    }
    self.currentCoords = CLLocationCoordinate2DMake(lat, lon);

    // 1. Top Header
    UILabel *lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, 220, 28)];
    lblTitle.text = @"⚡ HADI RIDER RADAR";
    lblTitle.textColor = [UIColor whiteColor];
    lblTitle.font = [UIFont boldSystemFontOfSize:16];
    [self.view addSubview:lblTitle];

    UIButton *btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    btnClose.frame = CGRectMake(cardW - 44, 10, 32, 32);
    [btnClose setTitle:@"✕" forState:UIControlStateNormal];
    [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClose.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.9];
    btnClose.layer.cornerRadius = 16;
    [btnClose addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnClose];

    // 2. Pure Native iOS MapKit (Never blocked by App-Transport-Security or JavaScript)
    CGFloat mapY = 48.0;
    CGFloat mapH = 290.0;
    self.mapView = [[MKMapView alloc] initWithFrame:CGRectMake(12, mapY, cardW - 24, mapH)];
    self.mapView.layer.cornerRadius = 14.0;
    self.mapView.layer.masksToBounds = YES;
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeStandard;
    self.mapView.showsCompass = YES;
    self.mapView.showsScale = YES;
    [self.view addSubview:self.mapView];

    // Add Red Pin Marker
    self.pin = [[MKPointAnnotation alloc] init];
    self.pin.coordinate = self.currentCoords;
    self.pin.title = @"Target Pin (Tap anywhere)";
    [self.mapView addAnnotation:self.pin];

    // Zoom into initial coordinates
    MKCoordinateRegion reg = MKCoordinateRegionMakeWithDistance(self.currentCoords, 2500, 2500);
    [self.mapView setRegion:reg animated:NO];

    // Tap Gesture to Move Pin Anywhere on Map
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapTap:)];
    [self.mapView addGestureRecognizer:tap];

    // 3. Status Coordinate Label
    self.lblCoords = [[UILabel alloc] initWithFrame:CGRectMake(16, mapY + mapH + 8, cardW - 32, 20)];
    self.lblCoords.textColor = [UIColor colorWithRed:0.7 green:0.85 blue:1.0 alpha:1.0];
    self.lblCoords.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.lblCoords.text = [NSString stringWithFormat:@"Target: %.5f, %.5f", lat, lon];
    self.lblCoords.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.lblCoords];

    // 4. Control Buttons (Toggle Spoof | Lock Pin | Dubai Center)
    CGFloat btnY = mapY + mapH + 34;
    CGFloat btnW = (cardW - 36) / 3.0;
    CGFloat btnH = 42.0;

    UIColor *toggleBg = self.isSpoofing ? [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0] : [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    self.btnToggle = [self makeButton:self.isSpoofing ? @"✓ SPOOF ON" : @"○ SPOOF OFF" bg:toggleBg frame:CGRectMake(12, btnY, btnW, btnH) sel:@selector(toggleSpoof)];
    [self.view addSubview:self.btnToggle];

    UIButton *btnLock = [self makeButton:@"LOCK PIN" bg:[UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:1.0] frame:CGRectMake(12 + btnW + 6, btnY, btnW, btnH) sel:@selector(lockCurrentPin)];
    [self.view addSubview:btnLock];

    self.btnDubai = [self makeButton:@"DUBAI CENTER" bg:[UIColor colorWithRed:1.0 green:0.4 blue:0.0 alpha:1.0] frame:CGRectMake(12 + (btnW + 6) * 2, btnY, btnW, btnH) sel:@selector(centerDubai)];
    [self.view addSubview:self.btnDubai];
}

- (UIButton *)makeButton:(NSString *)title bg:(UIColor *)bg frame:(CGRect)frame sel:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btn.backgroundColor = bg;
    btn.layer.cornerRadius = 10.0;
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)handleMapTap:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coord = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    self.currentCoords = coord;
    self.pin.coordinate = coord;
    self.lblCoords.text = [NSString stringWithFormat:@"Target: %.5f, %.5f", coord.latitude, coord.longitude];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    MKPinAnnotationView *pinView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:kHadiPinID];
    if (!pinView) {
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kHadiPinID];
        pinView.pinTintColor = [UIColor redColor];
        pinView.animatesDrop = YES;
        pinView.canShowCallout = YES;
    } else {
        pinView.annotation = annotation;
    }
    return pinView;
}

- (void)toggleSpoof {
    self.isSpoofing = !self.isSpoofing;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:self.isSpoofing forKey:@"HadiMod_SpoofEnabled"];
    [defs synchronize];

    [self.btnToggle setTitle:self.isSpoofing ? @"✓ SPOOF ON" : @"○ SPOOF OFF" forState:UIControlStateNormal];
    self.btnToggle.backgroundColor = self.isSpoofing ? [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0] : [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
}

- (void)lockCurrentPin {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:self.currentCoords.latitude forKey:@"HadiMod_SpoofLatitude"];
    [defs setDouble:self.currentCoords.longitude forKey:@"HadiMod_SpoofLongitude"];
    [defs synchronize];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Location Locked"
                                                               message:[NSString stringWithFormat:@"Target Coordinates:\nLat: %.5f\nLon: %.5f", self.currentCoords.latitude, self.currentCoords.longitude]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)centerDubai {
    CLLocationCoordinate2D dubai = CLLocationCoordinate2DMake(25.2048, 55.2708);
    self.currentCoords = dubai;
    self.pin.coordinate = dubai;
    self.lblCoords.text = [NSString stringWithFormat:@"Target: %.5f, %.5f", dubai.latitude, dubai.longitude];
    MKCoordinateRegion reg = MKCoordinateRegionMakeWithDistance(dubai, 2500, 2500);
    [self.mapView setRegion:reg animated:YES];
}

- (void)closeTapped {
    [self.view removeFromSuperview];
}

@end

// -------------------------------------------------------------
// 5. WINDOW GESTURE INJECTION (2 Fingers Triple Tap)
// -------------------------------------------------------------
static HadiModMapViewController *g_mapVC = nil;

@interface UIWindow (HadiGestureHook)
@end

@implementation UIWindow (HadiGestureHook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method origMake = class_getInstanceMethod([UIWindow class], @selector(makeKeyAndVisible));
        Method swizMake = class_getInstanceMethod([UIWindow class], @selector(hadi_makeKeyAndVisible));
        if (origMake && swizMake) {
            method_exchangeImplementations(origMake, swizMake);
        }
    });
}

- (void)hadi_makeKeyAndVisible {
    [self hadi_makeKeyAndVisible];
    static dispatch_once_t windowOnceToken;
    dispatch_once(&windowOnceToken, ^{
        UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hadiGestureTriggered:)];
        tripleTap.numberOfTapsRequired = 3;
        tripleTap.numberOfTouchesRequired = 2; // 2 fingers 3 taps
        [self addGestureRecognizer:tripleTap];
    });
}

- (void)hadiGestureTriggered:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        if (![HadiLicenseEngine isDeviceActivated]) {
            UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
            [HadiLicenseEngine showActivationPromptOn:root completion:^(BOOL success) {
                if (success) {
                    [self showMapController];
                }
            }];
            return;
        }
        [self showMapController];
    }
}

- (void)showMapController {
    if (!g_mapVC || !g_mapVC.view.superview) {
        g_mapVC = [[HadiModMapViewController alloc] init];
        [[UIApplication sharedApplication].keyWindow addSubview:g_mapVC.view];
    } else {
        [g_mapVC closeTapped];
    }
}

@end

// -------------------------------------------------------------
// 6. CORE INITIALIZATION & SWIZZLES
// -------------------------------------------------------------
static const void *HadiProxyKey = &HadiProxyKey;

@implementation CLLocationManager (HadiTalabatHook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method origReceipt = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
        Method swizReceipt = class_getInstanceMethod([NSBundle class], @selector(talabat_appStoreReceiptURL));
        if (origReceipt && swizReceipt) method_exchangeImplementations(origReceipt, swizReceipt);

        Method origSetDel = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:));
        Method swizSetDel = class_getInstanceMethod([CLLocationManager class], @selector(hadi_setDelegate:));
        if (origSetDel && swizSetDel) method_exchangeImplementations(origSetDel, swizSetDel);

        Method origLoc = class_getInstanceMethod([CLLocationManager class], @selector(location));
        Method swizLoc = class_getInstanceMethod([CLLocationManager class], @selector(hadi_location));
        if (origLoc && swizLoc) method_exchangeImplementations(origLoc, swizLoc);
    });
}

- (void)hadi_setDelegate:(id<CLLocationManagerDelegate>)delegate {
    if (!delegate || [delegate isKindOfClass:[HadiCLDelegateProxy class]]) {
        [self hadi_setDelegate:delegate];
        return;
    }
    HadiCLDelegateProxy *proxy = [[HadiCLDelegateProxy alloc] initWithRealDelegate:delegate manager:self];
    objc_setAssociatedObject(self, HadiProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self hadi_setDelegate:proxy];
}

- (CLLocation *)hadi_location {
    if ([HadiLicenseEngine isDeviceActivated]) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        if ([defs boolForKey:@"HadiMod_SpoofEnabled"]) {
            double lat = [defs doubleForKey:@"HadiMod_SpoofLatitude"];
            double lon = [defs doubleForKey:@"HadiMod_SpoofLongitude"];
            if (lat != 0.0 && lon != 0.0) {
                return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                     altitude:15.0
                                           horizontalAccuracy:5.0
                                             verticalAccuracy:5.0
                                                    timestamp:[NSDate date]];
            }
        }
    }
    return [self hadi_location];
}

@end
