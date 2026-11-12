// ============================================================================
//            HADI TALABAT RIDER TWEAK — FULL SCREEN RADAR (Tweak.x)
//    - Full-Screen Native Apple MapKit (Zero WebKit/ATS Blocks)
//    - Touch anywhere to drop pin
//    - PLAY Button: Moves/Locks GPS to target pin
//    - STOP Button: Immediately restores real original GPS
//    - Real-Time VPS Server 1:1 Hardware Lock
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
// 2. REAL-TIME SERVER HARDWARE LOCK ENGINE
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

    // When Spoof is OFF: forward REAL GPS updates seamlessly
    if ([_realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [_realDelegate locationManager:manager didUpdateLocations:locations];
    }
}

@end

// -------------------------------------------------------------
// 4. FULL-SCREEN NATIVE APPLE MAP CONTROLLER (TOUCH, PLAY & STOP)
// -------------------------------------------------------------
static NSString *const kHadiPinID = @"HadiPinAnnotation";

@interface HadiModMapViewController : UIViewController <MKMapViewDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UIView *controlPanel;
@property (nonatomic, strong) UIButton *btnPlay;
@property (nonatomic, strong) UIButton *btnStop;
@property (nonatomic, strong) UILabel *lblStatus;
@property (nonatomic, assign) CLLocationCoordinate2D targetCoords;
@property (nonatomic, assign) BOOL isSpoofingActive;
@end

@implementation HadiModMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Full screen bounds
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    self.view.frame = screenBounds;
    self.view.backgroundColor = [UIColor blackColor];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    self.isSpoofingActive = [defs boolForKey:@"HadiMod_SpoofEnabled"];
    double lat = [defs doubleForKey:@"HadiMod_SpoofLatitude"];
    double lon = [defs doubleForKey:@"HadiMod_SpoofLongitude"];
    if (lat == 0.0 && lon == 0.0) {
        lat = 25.2048; // Dubai
        lon = 55.2708;
    }
    self.targetCoords = CLLocationCoordinate2DMake(lat, lon);

    // 1. Full-Screen Native Apple MapView
    self.mapView = [[MKMapView alloc] initWithFrame:screenBounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeStandard;
    self.mapView.showsUserLocation = YES; // Shows actual user blue dot
    self.mapView.showsCompass = YES;
    self.mapView.showsScale = YES;
    [self.view addSubview:self.mapView];

    // Drop Target Pin
    self.pin = [[MKPointAnnotation alloc] init];
    self.pin.coordinate = self.targetCoords;
    self.pin.title = @"Target Spoof Location";
    [self.mapView addAnnotation:self.pin];

    // Initial Zoom
    MKCoordinateRegion reg = MKCoordinateRegionMakeWithDistance(self.targetCoords, 2000, 2000);
    [self.mapView setRegion:reg animated:NO];

    // Touch Anywhere Gesture to Move Pin
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapTouch:)];
    [self.mapView addGestureRecognizer:tap];

    // 2. Top Header Bar
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(16, 44, screenBounds.size.width - 32, 50)];
    topBar.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:0.92];
    topBar.layer.cornerRadius = 25;
    topBar.layer.masksToBounds = YES;
    topBar.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:0.6].CGColor;
    topBar.layer.borderWidth = 1.0;
    [self.view addSubview:topBar];

    UILabel *lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, 200, 30)];
    lblTitle.text = @"⚡ HADI RADAR CONTROL";
    lblTitle.textColor = [UIColor whiteColor];
    lblTitle.font = [UIFont boldSystemFontOfSize:15];
    [topBar addSubview:lblTitle];

    UIButton *btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    btnClose.frame = CGRectMake(topBar.bounds.size.width - 42, 9, 32, 32);
    [btnClose setTitle:@"✕" forState:UIControlStateNormal];
    [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClose.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.95];
    btnClose.layer.cornerRadius = 16;
    [btnClose addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:btnClose];

    // 3. Bottom Control Console (PLAY | STOP | STATUS)
    CGFloat panelH = 130.0;
    CGFloat panelW = screenBounds.size.width - 32;
    CGFloat panelY = screenBounds.size.height - panelH - 34;

    self.controlPanel = [[UIView alloc] initWithFrame:CGRectMake(16, panelY, panelW, panelH)];
    self.controlPanel.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:0.95];
    self.controlPanel.layer.cornerRadius = 20;
    self.controlPanel.layer.masksToBounds = YES;
    self.controlPanel.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.8].CGColor;
    self.controlPanel.layer.borderWidth = 1.5;
    [self.view addSubview:self.controlPanel];

    // Status Label
    self.lblStatus = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, panelW - 20, 22)];
    self.lblStatus.textAlignment = NSTextAlignmentCenter;
    self.lblStatus.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont boldSystemFontOfSize:12];
    [self.controlPanel addSubview:self.lblStatus];
    [self updateStatusLabel];

    // Buttons
    CGFloat btnW = (panelW - 36) / 2.0;
    CGFloat btnH = 50.0;
    CGFloat btnTop = 44.0;

    // PLAY Button (Move Location to Pin)
    self.btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPlay.frame = CGRectMake(12, btnTop, btnW, btnH);
    [self.btnPlay setTitle:@"▶ PLAY (MOVE)" forState:UIControlStateNormal];
    [self.btnPlay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnPlay.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.btnPlay.backgroundColor = [UIColor colorWithRed:0.10 green:0.75 blue:0.35 alpha:1.0];
    self.btnPlay.layer.cornerRadius = 14;
    [self.btnPlay addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.controlPanel addSubview:self.btnPlay];

    // STOP Button (Revert to Real Original GPS)
    self.btnStop = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnStop.frame = CGRectMake(12 + btnW + 12, btnTop, btnW, btnH);
    [self.btnStop setTitle:@"⏹ STOP (REAL GPS)" forState:UIControlStateNormal];
    [self.btnStop setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnStop.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.btnStop.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
    self.btnStop.layer.cornerRadius = 14;
    [self.btnStop addTarget:self action:@selector(stopTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.controlPanel addSubview:self.btnStop];

    // Quick Hotspot Button (Center Dubai)
    UIButton *btnDubai = [UIButton buttonWithType:UIButtonTypeCustom];
    btnDubai.frame = CGRectMake(panelW - 100, 10, 90, 24);
    [btnDubai setTitle:@"📍 Dubai Center" forState:UIControlStateNormal];
    [btnDubai setTitleColor:[UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    btnDubai.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [btnDubai addTarget:self action:@selector(centerDubai) forControlEvents:UIControlEventTouchUpInside];
    [self.controlPanel addSubview:btnDubai];
}

- (void)handleMapTouch:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coord = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    self.targetCoords = coord;
    self.pin.coordinate = coord;
    [self updateStatusLabel];
}

- (void)updateStatusLabel {
    if (self.isSpoofingActive) {
        self.lblStatus.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
        self.lblStatus.text = [NSString stringWithFormat:@"● ACTIVE SPOOF: %.5f, %.5f", self.targetCoords.latitude, self.targetCoords.longitude];
    } else {
        self.lblStatus.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
        self.lblStatus.text = [NSString stringWithFormat:@"○ PIN SET: %.5f, %.5f (READY)", self.targetCoords.latitude, self.targetCoords.longitude];
    }
}

- (void)playTapped {
    self.isSpoofingActive = YES;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:YES forKey:@"HadiMod_SpoofEnabled"];
    [defs setDouble:self.targetCoords.latitude forKey:@"HadiMod_SpoofLatitude"];
    [defs setDouble:self.targetCoords.longitude forKey:@"HadiMod_SpoofLongitude"];
    [defs synchronize];

    [self updateStatusLabel];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Location Moved!"
                                                               message:[NSString stringWithFormat:@"Talabat Rider is now spoofed to:\nLat: %.5f\nLon: %.5f", self.targetCoords.latitude, self.targetCoords.longitude]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)stopTapped {
    self.isSpoofingActive = NO;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:@"HadiMod_SpoofEnabled"];
    [defs synchronize];

    [self updateStatusLabel];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"GPS Restored"
                                                               message:@"Spoof stopped. Your phone's real live GPS is now active."
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)centerDubai {
    CLLocationCoordinate2D dubai = CLLocationCoordinate2DMake(25.2048, 55.2708);
    self.targetCoords = dubai;
    self.pin.coordinate = dubai;
    [self updateStatusLabel];
    MKCoordinateRegion reg = MKCoordinateRegionMakeWithDistance(dubai, 2500, 2500);
    [self.mapView setRegion:reg animated:YES];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil; // Shows Apple blue dot for actual GPS
    }

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
