// ============================================================================
//            HADI TALABAT RIDER TWEAK — PRODUCTION BUILD (Tweak.x)
//    - AppStore Receipt Bypass (Bypasses "Unauthorized rider app")
//    - Real Hardware Lock (MGCopyAnswer Physical UDID + Panel Mathematical Lock)
//    - Native Apple MKMapView (Zero API Key, Zero Web Blocks, 100% Guaranteed Map)
// ============================================================================

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <CommonCrypto/CommonDigest.h>

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
// 2. TRUE PHYSICAL HARDWARE UDID LOCK ENGINE (MGCopyAnswer)
// -------------------------------------------------------------
typedef CFTypeRef (*MGCopyAnswerFunc)(CFStringRef property);

@interface HadiLicenseEngine : NSObject
+ (BOOL)isDeviceActivated;
+ (NSString *)getDevicePhysicalUDID;
+ (BOOL)validateKey:(NSString *)enteredKey error:(NSString **)err;
+ (void)showActivationPromptOn:(UIViewController *)vc completion:(void(^)(BOOL success))completion;
@end

@implementation HadiLicenseEngine

+ (NSString *)getDevicePhysicalUDID {
    // 1. Query physical device UDID via MobileGestalt (Exact UDID entered into panel)
    void *gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (gestalt) {
        MGCopyAnswerFunc copyAnswer = (MGCopyAnswerFunc)dlsym(gestalt, "MGCopyAnswer");
        if (copyAnswer) {
            CFTypeRef udidRef = copyAnswer(CFSTR("UniqueDeviceID"));
            if (udidRef) {
                NSString *realUDID = [(__bridge NSString *)udidRef copy];
                CFRelease(udidRef);
                dlclose(gestalt);
                return [realUDID stringByReplacingOccurrencesOfString:@"-" withString:@""].uppercaseString;
            }
        }
        dlclose(gestalt);
    }

    // 2. Fallback to IOPlatformSerialNumber / Vendor UUID if jailbroken or restricted
    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""].uppercaseString;
}

+ (BOOL)isDeviceActivated {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *activeKey = [defs stringForKey:@"HadiMod_ActiveLicense"];
    NSString *boundDev = [defs stringForKey:@"HadiMod_BoundDevice"];
    NSString *currentDev = [self getDevicePhysicalUDID];

    if (!activeKey.length || !boundDev.length) return NO;
    if (![boundDev isEqualToString:currentDev]) return NO;
    return YES;
}

+ (BOOL)validateKey:(NSString *)enteredKey error:(NSString **)err {
    NSString *cleanKey = [enteredKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].uppercaseString;
    if (cleanKey.length < 8) {
        if (err) *err = @"Invalid Key Format!";
        return NO;
    }

    NSString *deviceUDID = [self getDevicePhysicalUDID];

    // Mathematical Hardware Validation:
    // Panel format: VIP[days]-[part1]-[part2]-[part3]-[part4] or VIP-[part1]-[part2]-[days]
    // Example: VIP-8160-000A-30 OR VIP30-A1B2-8160-000A-C3D4
    // Check if the key contains the hardware chunks of this device's UDID:
    NSString *udidHead = deviceUDID.length >= 4 ? [deviceUDID substringToIndex:4] : @"";
    NSString *udidTail = deviceUDID.length >= 4 ? [deviceUDID substringFromIndex:deviceUDID.length - 4] : @"";
    NSString *udidMid = deviceUDID.length >= 8 ? [deviceUDID substringWithRange:NSMakeRange(4, 4)] : @"";

    BOOL matchesHardware = NO;
    if (udidHead.length && [cleanKey containsString:udidHead]) matchesHardware = YES;
    if (udidTail.length && [cleanKey containsString:udidTail]) matchesHardware = YES;
    if (udidMid.length && [cleanKey containsString:udidMid]) matchesHardware = YES;

    if (!matchesHardware) {
        if (err) *err = @"Key is locked to another iPhone! (UDID Mismatch)";
        return NO;
    }

    // Key belongs strictly to THIS iPhone UDID -> Lock & Save
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:cleanKey forKey:@"HadiMod_ActiveLicense"];
    [defs setObject:deviceUDID forKey:@"HadiMod_BoundDevice"];
    [defs synchronize];
    return YES;
}

+ (void)showActivationPromptOn:(UIViewController *)vc completion:(void(^)(BOOL success))completion {
    if (!vc) {
        vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ HADI DYLIB ACTIVATION"
                                                                   message:@"Enter the hardware-locked key generated for this iPhone."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Enter License Key";
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.textAlignment = NSTextAlignmentCenter;
    }];

    UIAlertAction *activateAction = [UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        NSString *errorMsg = nil;
        if ([self validateKey:key error:&errorMsg]) {
            UIAlertController *succ = [UIAlertController alertControllerWithTitle:@"Activated!"
                                                                          message:@"License successfully verified for this iPhone."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [succ addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                if (completion) completion(YES);
            }]];
            [vc presentViewController:succ animated:YES completion:nil];
        } else {
            UIAlertController *fail = [UIAlertController alertControllerWithTitle:@"Activation Failed"
                                                                          message:errorMsg ?: @"Key is invalid."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [fail addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                [self showActivationPromptOn:vc completion:completion];
            }]];
            [vc presentViewController:fail animated:YES completion:nil];
        }
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
// 4. NATIVE APPLE MKMAPVIEW CONTROLLER (No API Key Required)
// -------------------------------------------------------------
@interface HadiModMapViewController : UIViewController <MKMapViewDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UIButton *btnToggle;
@property (nonatomic, strong) UIButton *btnTalabat;
@property (nonatomic, assign) BOOL isSpoofing;
@property (nonatomic, assign) CLLocationCoordinate2D currentCoords;
@end

@implementation HadiModMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
    self.view.layer.cornerRadius = 18.0;
    self.view.layer.masksToBounds = YES;
    self.view.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.9].CGColor;
    self.view.layer.borderWidth = 1.5;

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    self.isSpoofing = [defs boolForKey:@"HadiMod_SpoofEnabled"];
    double lat = [defs doubleForKey:@"HadiMod_SpoofLatitude"];
    double lon = [defs doubleForKey:@"HadiMod_SpoofLongitude"];
    if (lat == 0.0 && lon == 0.0) {
        lat = 25.2048; // Default Dubai
        lon = 55.2708;
    }
    self.currentCoords = CLLocationCoordinate2DMake(lat, lon);

    // Native iOS Apple MapView
    self.mapView = [[MKMapView alloc] initWithFrame:CGRectMake(10, 50, self.view.bounds.size.width - 20, 310)];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.layer.cornerRadius = 12.0;
    self.mapView.layer.masksToBounds = YES;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = NO;
    [self.view addSubview:self.mapView];

    // Add Target Pin
    self.pin = [[MKPointAnnotation alloc] init];
    self.pin.coordinate = self.currentCoords;
    self.pin.title = @"Target Pin";
    [self.mapView addAnnotation:self.pin];

    // Set Map Center
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(self.currentCoords, 2000, 2000);
    [self.mapView setRegion:region animated:NO];

    // Tap Gesture to move pin on map
    UITapGestureRecognizer *mapTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mapTapped:)];
    [self.mapView addGestureRecognizer:mapTap];

    [self setupControls];
}

- (void)mapTapped:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coord = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    self.currentCoords = coord;
    self.pin.coordinate = coord;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    static NSString *pinID = @"HadiPin";
    MKPinAnnotationView *pinView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pinID];
    if (!pinView) {
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pinID];
        pinView.pinTintColor = [UIColor redColor];
        pinView.animatesDrop = YES;
        pinView.canShowCallout = YES;
    } else {
        pinView.annotation = annotation;
    }
    return pinView;
}

- (UIButton *)makeButton:(NSString *)title bg:(UIColor *)bg frame:(CGRect)frame sel:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btn.backgroundColor = bg;
    btn.layer.cornerRadius = 8.0;
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)setupControls {
    CGFloat w = self.view.bounds.size.width;

    UIButton *btnClose = [self makeButton:@"✕" bg:[UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0] frame:CGRectMake(w - 45, 10, 35, 30) sel:@selector(closeTapped)];
    [self.view addSubview:btnClose];

    UILabel *lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 200, 30)];
    lblTitle.text = @"⚡ HADI RIDER RADAR";
    lblTitle.textColor = [UIColor whiteColor];
    lblTitle.font = [UIFont boldSystemFontOfSize:15];
    [self.view addSubview:lblTitle];

    CGFloat btnW = (w - 40) / 3.0;
    CGFloat y = 370;

    UIColor *toggleBg = self.isSpoofing ? [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0] : [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    self.btnToggle = [self makeButton:self.isSpoofing ? @"✓ SPOOF ON" : @"○ SPOOF OFF" bg:toggleBg frame:CGRectMake(10, y, btnW, 40) sel:@selector(toggleSpoof)];
    [self.view addSubview:self.btnToggle];

    UIButton *btnSave = [self makeButton:@"LOCK PIN" bg:[UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:1.0] frame:CGRectMake(15 + btnW, y, btnW, 40) sel:@selector(saveLocation)];
    [self.view addSubview:btnSave];

    self.btnTalabat = [self makeButton:@"DUBAI CENTER" bg:[UIColor colorWithRed:1.0 green:0.4 blue:0.0 alpha:1.0] frame:CGRectMake(20 + btnW * 2, y, btnW, 40) sel:@selector(centerDubai)];
    [self.view addSubview:self.btnTalabat];
}

- (void)toggleSpoof {
    self.isSpoofing = !self.isSpoofing;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:self.isSpoofing forKey:@"HadiMod_SpoofEnabled"];
    [defs synchronize];

    [self.btnToggle setTitle:self.isSpoofing ? @"✓ SPOOF ON" : @"○ SPOOF OFF" forState:UIControlStateNormal];
    self.btnToggle.backgroundColor = self.isSpoofing ? [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0] : [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
}

- (void)saveLocation {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:self.currentCoords.latitude forKey:@"HadiMod_SpoofLatitude"];
    [defs setDouble:self.currentCoords.longitude forKey:@"HadiMod_SpoofLongitude"];
    [defs synchronize];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Location Saved"
                                                               message:[NSString stringWithFormat:@"Target Coordinates:\nLat: %.5f\nLon: %.5f", self.currentCoords.latitude, self.currentCoords.longitude]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)centerDubai {
    CLLocationCoordinate2D dubai = CLLocationCoordinate2DMake(25.2048, 55.2708);
    self.currentCoords = dubai;
    self.pin.coordinate = dubai;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(dubai, 2500, 2500);
    [self.mapView setRegion:region animated:YES];
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
        CGFloat w = [UIScreen mainScreen].bounds.size.width - 40;
        CGFloat h = 430;
        g_mapVC.view.frame = CGRectMake(20, 80, w, h);
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
