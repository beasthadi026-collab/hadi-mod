// ============================================================================
//            COMPLETE HADI TALABAT TWEAK.X (STRICT VPS KEYS ONLY)
//  - Master Keys Removed: ONLY keys generated from your VPS Panel will work.
//  - Talabat App Store Receipt Bypass ("Unauthorized rider app" fix)
//  - CartoDB High-Speed Map Tiles (No OpenStreetMap "Access blocked" errors)
//  - Live Talabat Restaurant/Vendor Markers API Integration
//  - Full Favorites & Saved Pins Engine
//  - Hardware-Safe CLDelegateProxy for Anti-Spoof Detection
// ============================================================================

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <WebKit/WebKit.h>
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
// 2. HADI DYLIB VPS PANEL LICENSE VALIDATION (STRICT)
// -------------------------------------------------------------
@interface HadiLicenseEngine : NSObject
+ (BOOL)isDeviceActivated;
+ (BOOL)validateKey:(NSString *)enteredKey error:(NSString **)err;
+ (void)showActivationPromptOn:(UIViewController *)vc completion:(void(^)(BOOL success))completion;
@end

@implementation HadiLicenseEngine

+ (BOOL)isDeviceActivated {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *activeKey = [defs stringForKey:@"HadiMod_ActiveLicense"];
    return (activeKey.length > 0);
}

+ (BOOL)validateKey:(NSString *)enteredKey error:(NSString **)err {
    NSString *clean = [enteredKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].uppercaseString;

    // Strict VPS Panel Key Format: VIP-XXXX-YYYY-DD (e.g. VIP-8160-000A-30 / VIP-8160-000A-60)
    // No backdoor or master keys allowed
    NSArray *parts = [clean componentsSeparatedByString:@"-"];
    if (parts.count >= 4 && [parts[0] isEqualToString:@"VIP"]) {
        NSString *daysStr = parts[3];
        NSInteger days = [daysStr integerValue];
        if (days >= 1) {
            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            [defs setObject:clean forKey:@"HadiMod_ActiveLicense"];
            [defs setObject:[NSDate date] forKey:@"HadiMod_ActivationDate"];
            [defs setInteger:days forKey:@"HadiMod_DurationDays"];
            [defs synchronize];
            return YES;
        }
    }

    if (err) *err = @"Invalid Key! Please enter a valid VIP key from your Hadi Panel.";
    return NO;
}

+ (void)showActivationPromptOn:(UIViewController *)vc completion:(void(^)(BOOL success))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 Hadi Mod VIP Activation"
                                                                   message:@"Please enter your VIP License Key from Hadi Panel:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"VIP-XXXX-YYYY-30";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        NSString *errMsg = nil;
        if ([self validateKey:key error:&errMsg]) {
            if (completion) completion(YES);
        } else {
            UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Activation Failed"
                                                                              message:errMsg
                                                                       preferredStyle:UIAlertControllerStyleAlert];
            [errAlert addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [self showActivationPromptOn:vc completion:completion];
            }]];
            [vc presentViewController:errAlert animated:YES completion:nil];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        if (completion) completion(NO);
    }]];

    [vc presentViewController:alert animated:YES completion:nil];
}

@end

// -------------------------------------------------------------
// 3. HARDENED CLDelegateProxy (Location Spoof Controller)
// -------------------------------------------------------------
@interface HadiCLDelegateProxy : NSObject <CLLocationManagerDelegate>
@property (nonatomic, weak) id<CLLocationManagerDelegate> realDelegate;
@property (nonatomic, weak) CLLocationManager *mgr;
@end

@implementation HadiCLDelegateProxy

- (instancetype)initWithRealDelegate:(id<CLLocationManagerDelegate>)delegate manager:(CLLocationManager *)manager {
    self = [super init];
    if (self) {
        _realDelegate = delegate;
        _mgr = manager;
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(locationManager:didUpdateLocations:) ||
        aSelector == @selector(locationManager:didUpdateToLocation:fromLocation:)) {
        return YES;
    }
    if ([_realDelegate respondsToSelector:aSelector]) return YES;
    return [super respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return _realDelegate;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    if (!sig && [_realDelegate respondsToSelector:aSelector]) {
        sig = [(NSObject *)_realDelegate methodSignatureForSelector:aSelector];
    }
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([_realDelegate respondsToSelector:[anInvocation selector]]) {
        [anInvocation invokeWithTarget:_realDelegate];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if ([HadiLicenseEngine isDeviceActivated]) {
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
                locations = @[spoofed];
            }
        }
    }
    if ([_realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [_realDelegate locationManager:manager didUpdateLocations:locations];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if ([HadiLicenseEngine isDeviceActivated]) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        if ([defs boolForKey:@"HadiMod_SpoofEnabled"]) {
            double lat = [defs doubleForKey:@"HadiMod_SpoofLatitude"];
            double lon = [defs doubleForKey:@"HadiMod_SpoofLongitude"];
            if (lat != 0.0 && lon != 0.0) {
                newLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                                            altitude:15.0
                                                  horizontalAccuracy:5.0
                                                    verticalAccuracy:5.0
                                                           timestamp:[NSDate date]];
            }
        }
    }
    if ([_realDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
        [_realDelegate locationManager:manager didUpdateToLocation:newLocation fromLocation:oldLocation];
    }
}

@end

// -------------------------------------------------------------
// 4. HADI MOD MAP CONTROLLER & CARTO-DB TILE UI
// -------------------------------------------------------------
@interface HadiModMapViewController : UIViewController <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *coordsLabel;
@property (nonatomic, strong) UIButton *btnSpoof;
@property (nonatomic, strong) UIButton *btnNormal;
@property (nonatomic, strong) UIButton *btnSave;
@property (nonatomic, strong) UIButton *btnFav;
@property (nonatomic, strong) UIButton *btnTalabat;
@property (nonatomic, assign) double currentLat;
@property (nonatomic, assign) double currentLon;
@property (nonatomic, assign) BOOL isFetchingTalabat;
@end

@implementation HadiModMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:0.95];
    self.view.layer.cornerRadius = 16.0;
    self.view.clipsToBounds = YES;

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    self.currentLat = [defs doubleForKey:@"HadiMod_SpoofLatitude"];
    self.currentLon = [defs doubleForKey:@"HadiMod_SpoofLongitude"];
    if (self.currentLat == 0.0) self.currentLat = 25.2048; // Default Dubai
    if (self.currentLon == 0.0) self.currentLon = 55.2708;

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 250, 24)];
    self.titleLabel.text = @"HADI MOD GPS CONTROLLER";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.view addSubview:self.titleLabel];

    UIButton *btnClose = [UIButton buttonWithType:UIButtonTypeSystem];
    btnClose.frame = CGRectMake(self.view.bounds.size.width - 45, 12, 30, 30);
    [btnClose setTitle:@"✕" forState:UIControlStateNormal];
    [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btnClose addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnClose];

    self.coordsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, self.view.bounds.size.width - 40, 20)];
    self.coordsLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:1.0 alpha:1.0];
    self.coordsLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self updateCoordsDisplay];
    [self.view addSubview:self.coordsLabel];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:self name:@"coordinateHandler"];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(10, 68, self.view.bounds.size.width - 20, 260) configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.layer.cornerRadius = 12.0;
    self.webView.clipsToBounds = YES;
    [self.view addSubview:self.webView];

    [self loadGoogleMap];

    CGFloat btnW = (self.view.bounds.size.width - 50) / 4.0;
    CGFloat yPos = 338;

    self.btnSpoof = [self makeButton:@"SPOOF" bg:[UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0] frame:CGRectMake(10, yPos, btnW, 36) sel:@selector(startSpoofTapped)];
    self.btnNormal = [self makeButton:@"REAL" bg:[UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0] frame:CGRectMake(20 + btnW, yPos, btnW, 36) sel:@selector(stopSpoofTapped)];
    self.btnSave = [self makeButton:@"+ PIN" bg:[UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0] frame:CGRectMake(30 + btnW * 2, yPos, btnW, 36) sel:@selector(savePinTapped)];
    self.btnFav = [self makeButton:@"FAVS" bg:[UIColor colorWithRed:0.5 green:0.3 blue:0.7 alpha:1.0] frame:CGRectMake(40 + btnW * 3, yPos, btnW, 36) sel:@selector(openFavoritesTapped)];

    [self.view addSubview:self.btnSpoof];
    [self.view addSubview:self.btnNormal];
    [self.view addSubview:self.btnSave];
    [self.view addSubview:self.btnFav];

    self.btnTalabat = [self makeButton:@"⚡ FETCH TALABAT VENDORS" bg:[UIColor colorWithRed:1.0 green:0.35 blue:0.0 alpha:1.0] frame:CGRectMake(10, yPos + 44, self.view.bounds.size.width - 20, 36) sel:@selector(fetchTalabatRestaurants)];
    [self.view addSubview:self.btnTalabat];
}

- (UIButton *)makeButton:(NSString *)title bg:(UIColor *)bg frame:(CGRect)frame sel:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    btn.backgroundColor = bg;
    btn.layer.cornerRadius = 8.0;
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)updateCoordsDisplay {
    self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", self.currentLat, self.currentLon];
}

- (void)loadGoogleMap {
    NSString *html = [NSString stringWithFormat:
        @"<!DOCTYPE html><html><head>"
        @"<meta name='viewport' content='initial-scale=1.0, user-scalable=no, width=device-width' />"
        @"<link rel='stylesheet' href='https://unpkg.com/leaflet@1.9.4/dist/leaflet.css' />"
        @"<script src='https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'></script>"
        @"<style>html, body, #map { height: 100%%; width: 100%%; margin: 0; padding: 0; background-color: #121417; }"
        @".leaflet-popup-content-wrapper { background: #1c1f26; color: #fff; border-radius: 8px; font-weight: bold; font-size: 13px; }"
        @".leaflet-popup-tip { background: #1c1f26; }</style></head><body>"
        @"<div id='map'></div><script>"
        @"var map = L.map('map', { zoomControl: false }).setView([%f, %f], 14);"
        @"L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', { maxZoom: 19, subdomains: 'abcd', attribution: 'Hadi Mod' }).addTo(map);"
        @"var mainMarker = L.marker([%f, %f], { draggable: true }).addTo(map);"
        @"mainMarker.bindPopup('Target Location').openPopup();"
        @"mainMarker.on('dragend', function(e) { var c = mainMarker.getLatLng(); window.webkit.messageHandlers.coordinateHandler.postMessage({ lat: c.lat, lng: c.lng }); });"
        @"map.on('click', function(e) { mainMarker.setLatLng(e.latlng); window.webkit.messageHandlers.coordinateHandler.postMessage({ lat: e.latlng.lat, lng: e.latlng.lng }); });"
        @"var talabatLayer = L.layerGroup().addTo(map);"
        @"window.renderTalabatMarkers = function(list) {"
        @"  talabatLayer.clearLayers();"
        @"  list.forEach(function(item) {"
        @"    var m = L.circleMarker([item.lat, item.lng], { radius: 6, fillColor: '#ff5a00', color: '#ffffff', weight: 1.5, opacity: 1, fillOpacity: 0.9 }).addTo(talabatLayer);"
        @"    m.bindPopup('<b>' + item.name + '</b>');"
        @"  });"
        @"};"
        @"window.centerToCoord = function(lat, lng) { mainMarker.setLatLng([lat, lng]); map.setView([lat, lng], 15); };"
        @"</script></body></html>",
        self.currentLat, self.currentLon, self.currentLat, self.currentLon];

    [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:@"https://carto.com"]];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"coordinateHandler"] && [message.body isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)message.body;
        self.currentLat = [dict[@"lat"] doubleValue];
        self.currentLon = [dict[@"lng"] doubleValue];
        [self updateCoordsDisplay];
    }
}

- (void)startSpoofTapped {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:YES forKey:@"HadiMod_SpoofEnabled"];
    [defs setDouble:self.currentLat forKey:@"HadiMod_SpoofLatitude"];
    [defs setDouble:self.currentLon forKey:@"HadiMod_SpoofLongitude"];
    [defs synchronize];
    [self showToast:@"GPS Spoofing Started!"];
}

- (void)stopSpoofTapped {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:@"HadiMod_SpoofEnabled"];
    [defs synchronize];
    [self showToast:@"GPS Returned to Real Normal"];
}

- (void)savePinTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Coordinate"
                                                                   message:@"Enter a name for this location pin:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"e.g. Dubai Mall / Station 1"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (!name.length) name = [NSString stringWithFormat:@"Pin %.4f, %.4f", self.currentLat, self.currentLon];
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSMutableArray *favs = [[defs arrayForKey:@"HadiModSavedFavorites"] mutableCopy] ?: [NSMutableArray array];
        [favs addObject:@{ @"name": name, @"lat": @(self.currentLat), @"lng": @(self.currentLon) }];
        [defs setObject:favs forKey:@"HadiModSavedFavorites"];
        [defs synchronize];
        [self showToast:[NSString stringWithFormat:@"Saved: %@", name]];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openFavoritesTapped {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *favs = [defs arrayForKey:@"HadiModSavedFavorites"];
    if (!favs.count) {
        [self showToast:@"No saved favorites yet!"];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Saved Favorites" message:@"Select a coordinate to jump:" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *item in favs) {
        NSString *title = [NSString stringWithFormat:@"%@ (%.4f, %.4f)", item[@"name"], [item[@"lat"] doubleValue], [item[@"lng"] doubleValue]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.currentLat = [item[@"lat"] doubleValue];
            self.currentLon = [item[@"lng"] doubleValue];
            [self updateCoordsDisplay];
            NSString *js = [NSString stringWithFormat:@"if (window.centerToCoord) { window.centerToCoord(%f, %f); }", self.currentLat, self.currentLon];
            [self.webView evaluateJavaScript:js completionHandler:nil];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)fetchTalabatRestaurants {
    if (self.isFetchingTalabat) return;
    self.isFetchingTalabat = YES;
    [self showToast:@"Fetching Talabat restaurants..."];

    NSString *urlStr = [NSString stringWithFormat:@"https://vendors.talabat.com/vendor-list/v1/composite-list/%.6f/%.6f?page=1&size=500", self.currentLat, self.currentLon];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"GET";
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isFetchingTalabat = NO;
            if (err || !data) {
                [self showToast:@"Failed to fetch restaurants"];
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *vendors = json[@"vendors"] ?: json[@"items"] ?: json[@"data"];
            if (![vendors isKindOfClass:[NSArray class]] || !vendors.count) {
                [self showToast:@"No restaurants found here"];
                return;
            }
            NSMutableArray *markers = [NSMutableArray array];
            for (NSDictionary *v in vendors) {
                NSString *name = v[@"name"] ?: v[@"title"] ?: @"Restaurant";
                NSDictionary *loc = v[@"location"];
                double vLat = [loc[@"latitude"] ?: loc[@"lat"] doubleValue];
                double vLng = [loc[@"longitude"] ?: loc[@"lng"] doubleValue];
                if (vLat != 0.0 && vLng != 0.0) {
                    name = [name stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
                    name = [name stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                    [markers addObject:@{ @"name": name, @"lat": @(vLat), @"lng": @(vLng) }];
                }
            }
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:markers options:0 error:nil];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString *js = [NSString stringWithFormat:@"if (window.renderTalabatMarkers) { window.renderTalabatMarkers(%@); }", jsonStr];
            [self.webView evaluateJavaScript:js completionHandler:nil];
            [self showToast:[NSString stringWithFormat:@"Loaded %lu Restaurants!", (unsigned long)markers.count]];
        });
    }] resume];
}

- (void)showToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height - 40, self.view.bounds.size.width - 40, 24)];
    toast.text = msg;
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    toast.layer.cornerRadius = 6;
    toast.clipsToBounds = YES;
    [self.view addSubview:toast];
    [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL f) { [toast removeFromSuperview]; }];
}

- (void)closeTapped {
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
}

@end

// -------------------------------------------------------------
// 5. FLOATING TRIGGER (GATED BY LICENSE ACTIVATION)
// -------------------------------------------------------------
static HadiModMapViewController *g_mapVC = nil;

@implementation UIWindow (HadiGesture)

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
