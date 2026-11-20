// ============================================================================
//                    Tweak.x - TALABAT UNIFIED SAFE TWEAK
//   - Clean Native Apple MapKit (Full-screen radar with Tap-to-Pin)
//   - Branding: "DEV ABDULLAH X HADI MOD" (Login & Map)
//   - Trigger: 3 Fingers Double Tap (3 ungliyon se 2 baar tap kahin bhi screen par)
//   - Floating button completely removed!
//   - [▶ PLAY (MOVE)] and [⏹ STOP (REAL GPS)] instant toggle buttons
//   - Auto-move while PLAY is active (single tap moves immediately)
//   - Coordinate Save & Favorites Manager (Custom Name, Lat, Lon)
//   - 100% OFFLINE 1:1 HARDWARE KEY SYSTEM (ZERO SERVER DEPENDENCY):
//       * 1 Key bound 1:1 to Customer Device HWID (Other phones rejected)
//       * 30 Days strict validity timer from first activation
//       * Anti-Clock Rollback Detection
//       * Permanent Key Burn in iOS Keychain on Expiry (Re-entering shows EXPIRED)
//   - Sideload Receipt Bypass (Kills "Unauthorized rider app" on Login)
//   - Safe Dynamic Delegate Forwarding
// ============================================================================

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

static NSString *const kCLS_PrefKey_SpoofActive = @"CLS_SpoofActive";
static NSString *const kCLS_PrefKey_TargetLat   = @"CLS_TargetLat";
static NSString *const kCLS_PrefKey_TargetLon   = @"CLS_TargetLon";
static NSString *const kCLS_PrefKey_LicenseKey  = @"CLS_SavedKey";
static NSString *const kCLS_PrefKey_BoundDev    = @"CLS_BoundDev";
static NSString *const kCLS_PrefKey_FirstActive = @"CLS_FirstActiveTimestamp";
static NSString *const kCLS_PrefKey_Favorites   = @"CLS_SavedFavorites";
static NSString *const kCLS_FavCellIdentifier   = @"FavCell";

static NSString *const kCLS_OfflineMasterSecret = @"HADI_ABDULLAH_MODS_OFFLINE_SECRET_2026_MASTER";
static NSString *const kCLS_KeychainService     = @"com.hadimod.talabat.offline.license";
static NSString *const kCLS_KeychainAccountKey  = @"active_offline_vip_key";
static NSString *const kCLS_KeychainAccountTime = @"active_offline_first_time";
static NSString *const kCLS_KeychainAccountBurn = @"burnt_expired_keys_vault";

static const void *kCLDelegateProxyKey = &kCLDelegateProxyKey;

#pragma mark - KEYCHAIN PERSISTENCE HELPERS (Survives App Reinstalls)

static void CLS_KeychainSave(NSString *account, NSString *value) {
    if (!account || !value) return;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:kCLS_KeychainService forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    
    SecItemDelete((__bridge CFDictionaryRef)query);
    
    [query setObject:data forKey:(__bridge id)kSecValueData];
    [query setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
}

static NSString *CLS_KeychainLoad(NSString *account) {
    if (!account) return nil;
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:kCLS_KeychainService forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

static void CLS_KeychainDelete(NSString *account) {
    if (!account) return;
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:kCLS_KeychainService forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    SecItemDelete((__bridge CFDictionaryRef)query);
}

#pragma mark - CRYPTOGRAPHIC HELPERS

static NSString *CLS_SHA256Hex(NSString *input) {
    if (!input) return @"00000000";
    const char *str = [input UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(str, (CC_LONG)strlen(str), result);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02X", result[i]];
    }
    return hex;
}

static NSString *CLS_GetDeviceHardwareIdentifier(void) {
    NSString *vendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (vendor.length == 0) vendor = @"IPHONE-HARDWARE-VENDOR-01";
    NSString *hashed = CLS_SHA256Hex(vendor);
    if (hashed.length >= 8) {
        return [[hashed substringToIndex:8] uppercaseString];
    }
    return @"A7F39C2D";
}

#pragma mark - SYSTEM RECEIPT BYPASS (Kills "Unauthorized rider app")

@interface NSBundle (CLSBypass)
- (NSURL *)cls_appStoreReceiptURL;
@end

@implementation NSBundle (CLSBypass)
- (NSURL *)cls_appStoreReceiptURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupport = [paths firstObject];
    NSString *storeKitDir = [appSupport stringByAppendingPathComponent:@"StoreKit"];
    [[NSFileManager defaultManager] createDirectoryAtPath:storeKitDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *receiptPath = [storeKitDir stringByAppendingPathComponent:@"receipt"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:receiptPath]) {
        const char dummyBytes[] = {0x30, 0x82, 0x01, 0x00, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02};
        NSData *receiptData = [NSData dataWithBytes:dummyBytes length:sizeof(dummyBytes)];
        [receiptData writeToFile:receiptPath atomically:YES];
    }
    return [NSURL fileURLWithPath:receiptPath];
}
@end

#pragma mark - CORE LOCATION SPOOF & DELEGATE PROXY

@interface CLDelegateProxy : NSObject <CLLocationManagerDelegate>
@property (nonatomic, weak) id<CLLocationManagerDelegate> realDelegate;
@property (nonatomic, weak) CLLocationManager *mgr;
- (instancetype)initWithRealDelegate:(id<CLLocationManagerDelegate>)realDelegate manager:(CLLocationManager *)mgr;
@end

@implementation CLDelegateProxy

- (instancetype)initWithRealDelegate:(id<CLLocationManagerDelegate>)realDelegate manager:(CLLocationManager *)mgr {
    self = [super init];
    if (self) {
        _realDelegate = realDelegate;
        _mgr = mgr;
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(locationManager:didUpdateLocations:)) return YES;
    return [self.realDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.realDelegate;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    BOOL spoofOn = [defs boolForKey:kCLS_PrefKey_SpoofActive];
    
    if (spoofOn) {
        double lat = [defs doubleForKey:kCLS_PrefKey_TargetLat];
        double lon = [defs doubleForKey:kCLS_PrefKey_TargetLon];
        if (lat != 0.0 && lon != 0.0) {
            CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                               altitude:12.0
                                                     horizontalAccuracy:5.0
                                                       verticalAccuracy:5.0
                                                              timestamp:[NSDate date]];
            if ([self.realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [self.realDelegate locationManager:manager didUpdateLocations:@[spoofed]];
                return;
            }
        }
    }
    
    if ([self.realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.realDelegate locationManager:manager didUpdateLocations:locations];
    }
}
@end

@interface CLLocationManager (CLSSwizzle)
- (void)cls_setDelegate:(id<CLLocationManagerDelegate>)delegate;
- (CLLocation *)cls_location;
@end

@implementation CLLocationManager (CLSSwizzle)

- (void)cls_setDelegate:(id<CLLocationManagerDelegate>)delegate {
    if (!delegate || [delegate isKindOfClass:[CLDelegateProxy class]]) {
        [self cls_setDelegate:delegate];
        return;
    }
    CLDelegateProxy *proxy = [[CLDelegateProxy alloc] initWithRealDelegate:delegate manager:self];
    objc_setAssociatedObject(self, kCLDelegateProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self cls_setDelegate:proxy];
}

- (CLLocation *)cls_location {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs boolForKey:kCLS_PrefKey_SpoofActive]) {
        double lat = [defs doubleForKey:kCLS_PrefKey_TargetLat];
        double lon = [defs doubleForKey:kCLS_PrefKey_TargetLon];
        if (lat != 0.0 && lon != 0.0) {
            return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                 altitude:12.0
                                       horizontalAccuracy:5.0
                                         verticalAccuracy:5.0
                                                timestamp:[NSDate date]];
        }
    }
    return [self cls_location];
}
@end

#pragma mark - FULLSCREEN RADAR MAP VIEW CONTROLLER

@interface CLSViewController : UIViewController <MKMapViewDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UIButton *btnPlay;
@property (nonatomic, strong) UIButton *btnStop;
@property (nonatomic, strong) UIButton *btnClose;
@property (nonatomic, strong) UIButton *btnSaveCoord;
@property (nonatomic, strong) UIButton *btnFavorites;
@property (nonatomic, strong) UILabel *lblTitle;
@property (nonatomic, strong) UILabel *lblStatus;

// Favorites overlay view
@property (nonatomic, strong) UIView *favOverlay;
@property (nonatomic, strong) UITableView *favTableView;
@property (nonatomic, strong) NSMutableArray *favList;
@end

@implementation CLSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    // 1. Full Screen Apple Map
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.showsUserLocation = YES;
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapTap:)];
    [self.mapView addGestureRecognizer:tap];
    
    // 2. Top Status Bar (Branding: DEV ABDULLAH X HADI MOD)
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(15, 45, self.view.bounds.size.width - 30, 68)];
    topBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    topBar.layer.cornerRadius = 14;
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topBar];
    
    self.lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 8, topBar.bounds.size.width - 70, 24)];
    self.lblTitle.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:1.0];
    self.lblTitle.font = [UIFont boldSystemFontOfSize:15];
    self.lblTitle.text = @"DEV ABDULLAH X HADI MOD";
    [topBar addSubview:self.lblTitle];
    
    self.lblStatus = [[UILabel alloc] initWithFrame:CGRectMake(15, 34, topBar.bounds.size.width - 70, 24)];
    self.lblStatus.textColor = [UIColor whiteColor];
    self.lblStatus.font = [UIFont systemFontOfSize:13];
    self.lblStatus.text = @"TAP MAP TO DROP PIN";
    [topBar addSubview:self.lblStatus];
    
    self.btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnClose.frame = CGRectMake(topBar.bounds.size.width - 50, 14, 40, 40);
    [self.btnClose setTitle:@"✕" forState:UIControlStateNormal];
    [self.btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnClose.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.btnClose addTarget:self action:@selector(dismissRadar) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:self.btnClose];
    
    // 3. Middle Floating Action Buttons: [💾 SAVE COORD] & [⭐ FAVORITES]
    CGFloat actionBtnWidth = (self.view.bounds.size.width - 40) / 2.0;
    CGFloat actionY = 120;
    
    self.btnSaveCoord = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnSaveCoord.frame = CGRectMake(15, actionY, actionBtnWidth - 5, 40);
    self.btnSaveCoord.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.80];
    [self.btnSaveCoord setTitle:@"💾 SAVE COORD" forState:UIControlStateNormal];
    [self.btnSaveCoord setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnSaveCoord.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    self.btnSaveCoord.layer.cornerRadius = 10;
    self.btnSaveCoord.layer.borderColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:0.6].CGColor;
    self.btnSaveCoord.layer.borderWidth = 1.0;
    [self.btnSaveCoord addTarget:self action:@selector(actionPromptSaveCoord) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnSaveCoord];
    
    self.btnFavorites = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnFavorites.frame = CGRectMake(25 + actionBtnWidth - 5, actionY, actionBtnWidth - 5, 40);
    self.btnFavorites.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.80];
    [self.btnFavorites setTitle:@"⭐ FAVORITES" forState:UIControlStateNormal];
    [self.btnFavorites setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnFavorites.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    self.btnFavorites.layer.cornerRadius = 10;
    self.btnFavorites.layer.borderColor = [UIColor colorWithRed:1.0 green:0.84 blue:0.0 alpha:0.6].CGColor;
    self.btnFavorites.layer.borderWidth = 1.0;
    [self.btnFavorites addTarget:self action:@selector(actionShowFavorites) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnFavorites];
    
    // 4. Bottom Controls (PLAY & STOP)
    CGFloat bottomBtnWidth = (self.view.bounds.size.width - 45) / 2.0;
    CGFloat bottomY = self.view.bounds.size.height - 100;
    
    self.btnPlay = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnPlay.frame = CGRectMake(15, bottomY, bottomBtnWidth, 54);
    self.btnPlay.backgroundColor = [UIColor colorWithRed:0.1 green:0.8 blue:0.3 alpha:0.95];
    [self.btnPlay setTitle:@"▶ PLAY (MOVE)" forState:UIControlStateNormal];
    [self.btnPlay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnPlay.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.btnPlay.layer.cornerRadius = 14;
    [self.btnPlay addTarget:self action:@selector(actionPlay) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnPlay];
    
    self.btnStop = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnStop.frame = CGRectMake(30 + bottomBtnWidth, bottomY, bottomBtnWidth, 54);
    self.btnStop.backgroundColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:0.95];
    [self.btnStop setTitle:@"⏹ STOP (REAL)" forState:UIControlStateNormal];
    [self.btnStop setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnStop.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.btnStop.layer.cornerRadius = 14;
    [self.btnStop addTarget:self action:@selector(actionStop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStop];
    
    // Restore existing pin if active
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs boolForKey:kCLS_PrefKey_SpoofActive]) {
        double lat = [defs doubleForKey:kCLS_PrefKey_TargetLat];
        double lon = [defs doubleForKey:kCLS_PrefKey_TargetLon];
        if (lat != 0.0 && lon != 0.0) {
            CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
            self.pin = [[MKPointAnnotation alloc] init];
            self.pin.coordinate = coord;
            self.pin.title = @"Target Spoof Location";
            [self.mapView addAnnotation:self.pin];
            [self.mapView setCenterCoordinate:coord animated:NO];
            self.lblStatus.text = [NSString stringWithFormat:@"ACTIVE: %.4f, %.4f", lat, lon];
            self.lblStatus.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
        }
    }
}

- (void)handleMapTap:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coord = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    
    if (self.pin) {
        [self.mapView removeAnnotation:self.pin];
    }
    self.pin = [[MKPointAnnotation alloc] init];
    self.pin.coordinate = coord;
    self.pin.title = @"Selected Pin";
    [self.mapView addAnnotation:self.pin];
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    BOOL isPlaying = [defs boolForKey:kCLS_PrefKey_SpoofActive];
    
    if (isPlaying) {
        [defs setDouble:coord.latitude forKey:kCLS_PrefKey_TargetLat];
        [defs setDouble:coord.longitude forKey:kCLS_PrefKey_TargetLon];
        [defs synchronize];
        self.lblStatus.text = [NSString stringWithFormat:@"✓ MOVED TO: %.4f, %.4f", coord.latitude, coord.longitude];
        self.lblStatus.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    } else {
        self.lblStatus.text = [NSString stringWithFormat:@"PIN SET: %.4f, %.4f", coord.latitude, coord.longitude];
        self.lblStatus.textColor = [UIColor yellowColor];
    }
}

- (void)actionPlay {
    if (!self.pin) {
        self.lblStatus.text = @"ERROR: TAP MAP FIRST!";
        self.lblStatus.textColor = [UIColor redColor];
        return;
    }
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:self.pin.coordinate.latitude forKey:kCLS_PrefKey_TargetLat];
    [defs setDouble:self.pin.coordinate.longitude forKey:kCLS_PrefKey_TargetLon];
    [defs setBool:YES forKey:kCLS_PrefKey_SpoofActive];
    [defs synchronize];
    
    self.lblStatus.text = [NSString stringWithFormat:@"✓ SPOOFING: %.4f, %.4f", self.pin.coordinate.latitude, self.pin.coordinate.longitude];
    self.lblStatus.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
}

- (void)actionStop {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:kCLS_PrefKey_SpoofActive];
    [defs synchronize];
    
    if (self.pin) {
        [self.mapView removeAnnotation:self.pin];
        self.pin = nil;
    }
    self.lblStatus.text = @"⏹ REAL GPS RESTORED";
    self.lblStatus.textColor = [UIColor whiteColor];
}

#pragma mark - SAVE COORDINATES & FAVORITES

- (void)actionPromptSaveCoord {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SAVE COORDINATE"
                                                                   message:@"Enter place name and coordinates:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) {
        t.placeholder = @"Place Name (e.g. Shop / Branch)";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) {
        t.placeholder = @"Latitude (e.g. 24.8607)";
        if (self.pin) {
            t.text = [NSString stringWithFormat:@"%.6f", self.pin.coordinate.latitude];
        }
        t.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) {
        t.placeholder = @"Longitude (e.g. 67.0011)";
        if (self.pin) {
            t.text = [NSString stringWithFormat:@"%.6f", self.pin.coordinate.longitude];
        }
        t.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"SAVE" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields[0].text;
        NSString *latStr = alert.textFields[1].text;
        NSString *lonStr = alert.textFields[2].text;
        
        if (name.length == 0) name = @"Saved Location";
        double lat = [latStr doubleValue];
        double lon = [lonStr doubleValue];
        
        if (lat == 0.0 || lon == 0.0) {
            self.lblStatus.text = @"INVALID COORDINATES!";
            self.lblStatus.textColor = [UIColor redColor];
            return;
        }
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSArray *existing = [defs arrayForKey:kCLS_PrefKey_Favorites];
        NSMutableArray *arr = existing ? [existing mutableCopy] : [NSMutableArray array];
        
        NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:
                              name, @"name",
                              [NSNumber numberWithDouble:lat], @"lat",
                              [NSNumber numberWithDouble:lon], @"lon", nil];
        [arr addObject:item];
        [defs setObject:arr forKey:kCLS_PrefKey_Favorites];
        [defs synchronize];
        
        self.lblStatus.text = [NSString stringWithFormat:@"✓ SAVED: %@", name];
        self.lblStatus.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    }];
    
    [alert addAction:saveAction];
    [alert addAction:[UIAlertAction actionWithTitle:@"CANCEL" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)actionShowFavorites {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *saved = [defs arrayForKey:kCLS_PrefKey_Favorites];
    self.favList = saved ? [saved mutableCopy] : [NSMutableArray array];
    
    if (self.favList.count == 0) {
        UIAlertController *emptyAlert = [UIAlertController alertControllerWithTitle:@"NO FAVORITES"
                                                                            message:@"No coordinates saved yet! Use 'SAVE COORD' to add one."
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [emptyAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
        [self presentViewController:emptyAlert animated:YES completion:nil];
        return;
    }
    
    if (self.favOverlay) {
        [self.favOverlay removeFromSuperview];
    }
    
    self.favOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.favOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.90];
    
    // Header for Favorites
    UIView *favHeader = [[UIView alloc] initWithFrame:CGRectMake(15, 45, self.view.bounds.size.width - 30, 50)];
    favHeader.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.3];
    favHeader.layer.cornerRadius = 10;
    [self.favOverlay addSubview:favHeader];
    
    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, favHeader.bounds.size.width - 60, 50)];
    headerTitle.text = @"⭐ FAVORITE LOCATIONS";
    headerTitle.textColor = [UIColor yellowColor];
    headerTitle.font = [UIFont boldSystemFontOfSize:16];
    [favHeader addSubview:headerTitle];
    
    UIButton *closeFav = [UIButton buttonWithType:UIButtonTypeCustom];
    closeFav.frame = CGRectMake(favHeader.bounds.size.width - 45, 5, 40, 40);
    [closeFav setTitle:@"✕" forState:UIControlStateNormal];
    closeFav.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [closeFav addTarget:self action:@selector(closeFavoritesOverlay) forControlEvents:UIControlEventTouchUpInside];
    [favHeader addSubview:closeFav];
    
    // TableView
    self.favTableView = [[UITableView alloc] initWithFrame:CGRectMake(15, 105, self.view.bounds.size.width - 30, self.view.bounds.size.height - 120) style:UITableViewStylePlain];
    self.favTableView.backgroundColor = [UIColor clearColor];
    self.favTableView.delegate = self;
    self.favTableView.dataSource = self;
    self.favTableView.separatorColor = [UIColor darkGrayColor];
    [self.favOverlay addSubview:self.favTableView];
    
    [self.view addSubview:self.favOverlay];
}

- (void)closeFavoritesOverlay {
    if (self.favOverlay) {
        [self.favOverlay removeFromSuperview];
        self.favOverlay = nil;
    }
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.favList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 65;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCLS_FavCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCLS_FavCellIdentifier];
        cell.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    }
    
    NSDictionary *item = self.favList[indexPath.row];
    cell.textLabel.text = item[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Lat: %@ | Lon: %@", item[@"lat"], item[@"lon"]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.favList[indexPath.row];
    double lat = [item[@"lat"] doubleValue];
    double lon = [item[@"lon"] doubleValue];
    NSString *name = item[@"name"];
    
    UIAlertController *actAlert = [UIAlertController alertControllerWithTitle:name
                                                                      message:[NSString stringWithFormat:@"Lat: %.5f\nLon: %.5f", lat, lon]
                                                               preferredStyle:UIAlertControllerStyleAlert];
    
    [actAlert addAction:[UIAlertAction actionWithTitle:@"▶ ACTIVE (MOVE HERE)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self closeFavoritesOverlay];
        
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
        if (self.pin) {
            [self.mapView removeAnnotation:self.pin];
        }
        self.pin = [[MKPointAnnotation alloc] init];
        self.pin.coordinate = coord;
        self.pin.title = name;
        [self.mapView addAnnotation:self.pin];
        [self.mapView setCenterCoordinate:coord animated:YES];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setDouble:lat forKey:kCLS_PrefKey_TargetLat];
        [defs setDouble:lon forKey:kCLS_PrefKey_TargetLon];
        [defs setBool:YES forKey:kCLS_PrefKey_SpoofActive];
        [defs synchronize];
        
        self.lblStatus.text = [NSString stringWithFormat:@"✓ ACTIVE: %@", name];
        self.lblStatus.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    }]];
    
    [actAlert addAction:[UIAlertAction actionWithTitle:@"DELETE" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.favList removeObjectAtIndex:indexPath.row];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setObject:self.favList forKey:kCLS_PrefKey_Favorites];
        [defs synchronize];
        [self.favTableView reloadData];
    }]];
    
    [actAlert addAction:[UIAlertAction actionWithTitle:@"CANCEL" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:actAlert animated:YES completion:nil];
}

- (void)dismissRadar {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

#pragma mark - 100% OFFLINE 1:1 HARDWARE BIND & VALIDATION ENGINE

// 3 Fingers Double Tap Gesture Installer
static void CLS_InstallDoubleTapGesture(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            NSArray *windows = [UIApplication sharedApplication].windows;
            if (windows.count > 0) window = windows.firstObject;
        }
        if (!window) return;
        
        UIView *oldBtn = [window viewWithTag:998877];
        if (oldBtn) [oldBtn removeFromSuperview];
        
        for (UIGestureRecognizer *g in window.gestureRecognizers) {
            if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
                UITapGestureRecognizer *tg = (UITapGestureRecognizer *)g;
                if (tg.numberOfTouchesRequired == 3 && tg.numberOfTapsRequired == 2) {
                    return; // Already attached
                }
            }
        }
        
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:[CLSViewController class] action:@selector(cls_presentRadarScreen)];
        doubleTap.numberOfTouchesRequired = 3; // 3 Fingers
        doubleTap.numberOfTapsRequired = 2;    // 2 Taps (Double Tap)
        doubleTap.cancelsTouchesInView = NO;
        [window addGestureRecognizer:doubleTap];
    });
}

@implementation CLSViewController (Launcher)
+ (void)cls_presentRadarScreen {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    CLSViewController *vc = [[CLSViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [root presentViewController:vc animated:YES completion:nil];
}
@end

// Check if a key has already expired and been burned in Keychain
static BOOL CLS_IsKeyBurnt(NSString *key) {
    if (!key || key.length == 0) return NO;
    NSString *burnt = CLS_KeychainLoad(kCLS_KeychainAccountBurn);
    if (!burnt) return NO;
    NSString *needle = [NSString stringWithFormat:@"|%@|", key];
    return [burnt containsString:needle];
}

// Permanently burn an expired key into iOS Keychain so it cannot be reused
static void CLS_BurnKey(NSString *key) {
    if (!key || key.length == 0) return;
    NSString *burnt = CLS_KeychainLoad(kCLS_KeychainAccountBurn) ?: @"";
    NSString *entry = [NSString stringWithFormat:@"|%@|", key];
    if (![burnt containsString:entry]) {
        burnt = [burnt stringByAppendingString:entry];
        CLS_KeychainSave(kCLS_KeychainAccountBurn, burnt);
    }
}

// Offline Cryptographic Key Validator (1:1 Hardware & Expiry)
static BOOL CLS_VerifyOfflineKey(NSString *key, int *outDays, NSString **outError) {
    if (!key || key.length == 0) {
        if (outError) *outError = @"Please enter your VIP License Key!";
        return NO;
    }
    
    NSString *cleanKey = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *parts = [cleanKey componentsSeparatedByString:@"-"];
    
    // Expected format: VIP-<HWID>-<DAYS>-<SIG> (4 parts)
    if (parts.count != 4 || ![parts[0] isEqualToString:@"VIP"]) {
        if (outError) *outError = @"Invalid Key Format!\nKey must look like: VIP-XXXXXXXX-30D-XXXXXXXX";
        return NO;
    }
    
    NSString *keyHwid = parts[1];
    NSString *daysTag = parts[2];
    NSString *keySig  = parts[3];
    
    // 1. Strict 1:1 Hardware Binding Check
    NSString *myHwid = CLS_GetDeviceHardwareIdentifier();
    if (![keyHwid isEqualToString:myHwid]) {
        if (outError) {
            *outError = [NSString stringWithFormat:@"Hardware Mismatch!\nThis key was locked to HWID: %@\nYour device HWID is: %@\n(1 Key works on 1 device only!)", keyHwid, myHwid];
        }
        return NO;
    }
    
    // 2. Check Burnt Keys in Keychain (Key reuse prevention)
    if (CLS_IsKeyBurnt(cleanKey)) {
        if (outError) *outError = @"License Expired!\nThis key has already expired on this device. The same key cannot be reused. Please get a new key.";
        return NO;
    }
    
    // 3. Cryptographic Signature Verification
    NSString *payload = [NSString stringWithFormat:@"%@:%@:%@", keyHwid, daysTag, kCLS_OfflineMasterSecret];
    NSString *fullHash = CLS_SHA256Hex(payload);
    NSString *expectedSig = [[fullHash substringToIndex:8] uppercaseString];
    
    if (![keySig isEqualToString:expectedSig]) {
        if (outError) *outError = @"Invalid License Signature!\nKey is corrupted or invalid.";
        return NO;
    }
    
    // 4. Extract validity days
    NSString *numStr = [daysTag stringByReplacingOccurrencesOfString:@"D" withString:@""];
    int days = [numStr intValue];
    if (days <= 0) days = 30;
    if (outDays) *outDays = days;
    
    if (outError) *outError = nil;
    return YES;
}

static void CLS_PromptKeyActivation(void);

// Main License Verification Loop (Offline 30-Day Expiry Engine)
static void CLS_VerifyAndBindLicense(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        
        // Load active key from Keychain or NSUserDefaults
        NSString *savedKey = CLS_KeychainLoad(kCLS_KeychainAccountKey);
        if (!savedKey) savedKey = [defs stringForKey:kCLS_PrefKey_LicenseKey];
        
        if (savedKey.length > 5) {
            // Validate key signature and device binding
            int days = 30;
            NSString *err = nil;
            if (!CLS_VerifyOfflineKey(savedKey, &days, &err)) {
                // Key invalid or hardware changed
                [defs removeObjectForKey:kCLS_PrefKey_LicenseKey];
                [defs removeObjectForKey:kCLS_PrefKey_FirstActive];
                [defs setBool:NO forKey:kCLS_PrefKey_SpoofActive];
                [defs synchronize];
                CLS_KeychainDelete(kCLS_KeychainAccountKey);
                CLS_KeychainDelete(kCLS_KeychainAccountTime);
                CLS_PromptKeyActivation();
                return;
            }
            
            // Check Expiry Timeline
            double now = [[NSDate date] timeIntervalSince1970];
            double firstActive = [defs doubleForKey:kCLS_PrefKey_FirstActive];
            NSString *kcTimeStr = CLS_KeychainLoad(kCLS_KeychainAccountTime);
            if (kcTimeStr) {
                double kcTime = [kcTimeStr doubleValue];
                if (kcTime > 0 && (firstActive <= 0 || kcTime < firstActive)) {
                    firstActive = kcTime;
                }
            }
            
            if (firstActive <= 0.0) {
                firstActive = now;
                [defs setDouble:firstActive forKey:kCLS_PrefKey_FirstActive];
                [defs synchronize];
                CLS_KeychainSave(kCLS_KeychainAccountTime, [NSString stringWithFormat:@"%.0f", firstActive]);
            }
            
            double allowedDuration = (double)days * 86400.0;
            
            // Anti-Clock Tampering Check (User turned clock backwards)
            if (now < (firstActive - 86400.0)) {
                UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
                if (root) {
                    UIAlertController *tampAlert = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                                       message:@"Clock tampering detected!\nPlease set correct date and time on your device to continue."
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                    [tampAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [root presentViewController:tampAlert animated:YES completion:nil];
                }
                return;
            }
            
            // 30 Days Expiry Check
            if ((now - firstActive) >= allowedDuration) {
                // BURN THIS KEY IN KEYCHAIN PERMANENTLY:
                CLS_BurnKey(savedKey);
                
                // Wipe active license:
                [defs removeObjectForKey:kCLS_PrefKey_LicenseKey];
                [defs removeObjectForKey:kCLS_PrefKey_FirstActive];
                [defs setBool:NO forKey:kCLS_PrefKey_SpoofActive];
                [defs synchronize];
                CLS_KeychainDelete(kCLS_KeychainAccountKey);
                CLS_KeychainDelete(kCLS_KeychainAccountTime);
                
                UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
                if (root) {
                    UIAlertController *expAlert = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                                      message:@"Your 30-Day VIP Key has EXPIRED!\nPlease contact admin for a new key."
                                                                               preferredStyle:UIAlertControllerStyleAlert];
                    [expAlert addAction:[UIAlertAction actionWithTitle:@"ACTIVATE NEW KEY" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                        CLS_PromptKeyActivation();
                    }]];
                    [root presentViewController:expAlert animated:YES completion:nil];
                }
                return;
            }
            
            // Key is active and valid! Install GPS radar gesture:
            CLS_InstallDoubleTapGesture();
            return;
        }
        
        // No active key found -> Prompt Activation
        CLS_PromptKeyActivation();
    });
}

// User-Facing Activation UI with 1-Tap HWID Copy
static void CLS_PromptKeyActivation(void) {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!root) return;
    
    NSString *myHwid = CLS_GetDeviceHardwareIdentifier();
    NSString *msg = [NSString stringWithFormat:@"Device HWID: %@\n\n1. Copy HWID and send to admin\n2. Enter VIP Key below:", myHwid];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [NSString stringWithFormat:@"VIP-%@-30D-XXXXXXXX", myHwid];
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    // Copy HWID Button
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
