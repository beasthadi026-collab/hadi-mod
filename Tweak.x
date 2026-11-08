// Language: Objective-C (Logos)
// Target: iOS 13.0 - 18.x (arm64 / arm64e)
// Features: Dual Embedded Logos + Username & Password VPS Login + Heartbeat Session Validation + Ban/Delete Enforcement + Favorites + Save Pin

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <WebKit/WebKit.h>

// Global persistent state
static BOOL g_spoofEnabled = NO;
static CLLocationDegrees g_spoofLatitude = 24.46094;
static CLLocationDegrees g_spoofLongitude = 54.35718;
static UIWindow *g_window = nil;
static BOOL g_sessionWatcherRunning = NO;
static dispatch_source_t g_sessionTimer = nil;
static dispatch_once_t g_watcherOnceToken = 0;
static dispatch_once_t g_windowOnceToken = 0;

static NSString * const kFavKey = @"HadiModSavedFavorites";
static NSString * const kProjectSlug = @"hadi-gps-3";

// Base64 Embedded Circular Logos
static NSString * const kLogoHadiModBase64 = @"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";
static NSString * const kLogoErrorExpertBase64 = @"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";

static UIImage *getImageFromBase64(NSString *b64) {
    if (!b64 || b64.length == 0) return nil;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data) return nil;
    return [UIImage imageWithData:data];
}

static NSString *getOrCreateDeviceId() {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *devId = [defs stringForKey:@"HadiMod_DeviceId"];
    if (!devId || devId.length == 0) {
        devId = [UIDevice currentDevice].identifierForVendor.UUIDString;
        if (!devId) devId = [[NSUUID UUID] UUIDString];
        [defs setObject:devId forKey:@"HadiMod_DeviceId"];
        [defs synchronize];
    }
    return devId;
}

// Forward Declarations
@interface HadiModMapViewController : UIViewController <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *coordsLabel;
@property (nonatomic, strong) UIButton *btnSpoof;
@property (nonatomic, strong) UIButton *btnNormal;
@property (nonatomic, strong) UIButton *btnSave;
@property (nonatomic, strong) UIButton *btnFav;
@end

static void showLoginDialog(void);
static void executeLogin(NSString *user, NSString *pass);
static void startSessionWatcher(void);
static void stopSessionWatcher(void);
static void showRevokedAlert(NSString *title, NSString *message);

// ==========================================
// SESSION TERMINATION & ALERT DISPATCH
// ==========================================
static void showRevokedAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        g_spoofEnabled = NO;
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:NO forKey:@"HadiMod_IsLoggedIn"];
        [defs removeObjectForKey:@"HadiMod_Token"];
        [defs removeObjectForKey:@"HadiMod_Expiry"];
        [defs synchronize];
        stopSessionWatcher();
        
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
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:nil]];
                [presenting presentViewController:alert animated:YES completion:nil];
            }];
            return;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDestructive handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

// Background Heartbeat: Check /auth/customer/me every 10 seconds
static void startSessionWatcher(void) {
    dispatch_once(&g_watcherOnceToken, ^{
        dispatch_queue_t queue = dispatch_queue_create("net.hadimod3.sessionwatcher", DISPATCH_QUEUE_SERIAL);
        g_sessionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(g_sessionTimer, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), 10 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(g_sessionTimer, ^{
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
            [req setTimeoutInterval:7.0];
            
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)resp;
                NSInteger statusCode = httpResp.statusCode;
                
                if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
                    NSString *reason = @"Session Revoked";
                    NSString *detail = @"Your account access has been terminated by administrator.";
                    if (data) {
                        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                        NSString *msg = json[@"message"];
                        if (msg && [msg localizedCaseInsensitiveContainsString:@"ban"]) {
                            reason = @"Account Banned";
                            detail = @"Your account has been banned by administrator.";
                        } else if (msg && [msg localizedCaseInsensitiveContainsString:@"expire"]) {
                            reason = @"Subscription Expired";
                            detail = @"Your subscription period has ended. Please generate a new key.";
                        } else if (msg && [msg localizedCaseInsensitiveContainsString:@"delete"]) {
                            reason = @"Account Terminated";
                            detail = @"Your account was deleted by administrator.";
                        }
                    }
                    showRevokedAlert(reason, detail);
                } else if (statusCode == 200 && data) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    NSNumber *active = json[@"active"];
                    NSNumber *isBanned = json[@"banned"];
                    NSString *status = json[@"status"];
                    if ((active && ![active boolValue]) || (isBanned && [isBanned boolValue]) || [status isEqualToString:@"banned"]) {
                        showRevokedAlert(@"Account Banned", @"Your account has been suspended or banned by administrator.");
                    }
                }
            }];
            [task resume];
        });
        dispatch_resume(g_sessionTimer);
        g_sessionWatcherRunning = YES;
    });
}

static void stopSessionWatcher(void) {
    if (g_sessionTimer) {
        dispatch_source_cancel(g_sessionTimer);
        g_sessionTimer = nil;
        g_watcherOnceToken = 0;
        g_sessionWatcherRunning = NO;
    }
}

// ==========================================
// CORE LOCATION HOOK
// ==========================================
%hook CLLocationManager

- (CLLocation *)location {
    if (g_spoofEnabled) {
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(g_spoofLatitude, g_spoofLongitude);
        return [[CLLocation alloc] initWithCoordinate:coord
                                             altitude:25.0
                                   horizontalAccuracy:5.0
                                     verticalAccuracy:5.0
                                            timestamp:[NSDate date]];
    }
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    if (g_spoofEnabled) {
        CLLocation *fake = [self location];
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fake]];
        }
    }
}

%end

// ==========================================
// MAP VIEW CONTROLLER (WKWebView Google Maps + Dual Logos + Favorites)
// ==========================================
@implementation HadiModMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
    
    // Top Bar Container
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 90)];
    topBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topBar];
    
    // Left Circular Logo: Hadi Mod
    UIImage *imgHadi = getImageFromBase64(kLogoHadiModBase64);
    if (imgHadi) {
        UIImageView *ivHadi = [[UIImageView alloc] initWithFrame:CGRectMake(14, 38, 44, 44)];
        ivHadi.image = imgHadi;
        ivHadi.layer.cornerRadius = 22;
        ivHadi.layer.masksToBounds = YES;
        ivHadi.layer.borderWidth = 1.5;
        ivHadi.layer.borderColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0].CGColor;
        [topBar addSubview:ivHadi];
    }
    
    // Right Circular Logo: Error Expert
    UIImage *imgError = getImageFromBase64(kLogoErrorExpertBase64);
    if (imgError) {
        UIImageView *ivError = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 96, 38, 44, 44)];
        ivError.image = imgError;
        ivError.layer.cornerRadius = 22;
        ivError.layer.masksToBounds = YES;
        ivError.layer.borderWidth = 1.5;
        ivError.layer.borderColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:1.0].CGColor;
        ivError.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [topBar addSubview:ivError];
    }
    
    // Close "X" Button
    UIButton *btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    btnClose.frame = CGRectMake(self.view.bounds.size.width - 46, 42, 36, 36);
    [btnClose setTitle:@"X" forState:UIControlStateNormal];
    [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClose.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    btnClose.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [btnClose addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:btnClose];
    
    // Header Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(66, 38, self.view.bounds.size.width - 168, 22)];
    self.titleLabel.text = @"HADI MOD X ERROR EXPERT";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:self.titleLabel];
    
    // Selected Coordinates Label
    self.coordsLabel = [[UILabel alloc] initWithFrame:CGRectMake(66, 62, self.view.bounds.size.width - 168, 18)];
    self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f, Lon: %.5f", g_spoofLatitude, g_spoofLongitude];
    self.coordsLabel.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
    self.coordsLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.coordsLabel.textAlignment = NSTextAlignmentCenter;
    self.coordsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar addSubview:self.coordsLabel];
    
    // WebKit Google Maps Configuration
    WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:self name:@"onMapCoord"];
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.userContentController = ucc;
    
    CGFloat bottomH = 120.0;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 90, self.view.bounds.size.width, self.view.bounds.size.height - 90 - bottomH) configuration:cfg];
    self.webView.navigationDelegate = self;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.webView];
    
    // Bottom Bar (2 Rows of Action Controls)
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - bottomH, self.view.bounds.size.width, bottomH)];
    bottomBar.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0];
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:bottomBar];
    
    CGFloat btnW = (self.view.bounds.size.width - 36) / 2.0;
    
    // Row 1: [+ SAVE PIN] and [* FAVORITES]
    self.btnSave = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSave.frame = CGRectMake(12, 10, btnW, 44);
    self.btnSave.backgroundColor = [UIColor colorWithRed:0.22 green:0.25 blue:0.32 alpha:1.0];
    self.btnSave.layer.cornerRadius = 8;
    [self.btnSave setTitle:@"+ SAVE PIN" forState:UIControlStateNormal];
    [self.btnSave setTitleColor:[UIColor colorWithRed:0.8 green:0.9 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.btnSave.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.btnSave addTarget:self action:@selector(savePinTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnSave];
    
    self.btnFav = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnFav.frame = CGRectMake(self.view.bounds.size.width - 12 - btnW, 10, btnW, 44);
    self.btnFav.backgroundColor = [UIColor colorWithRed:0.22 green:0.25 blue:0.32 alpha:1.0];
    self.btnFav.layer.cornerRadius = 8;
    [self.btnFav setTitle:@"* FAVORITES" forState:UIControlStateNormal];
    [self.btnFav setTitleColor:[UIColor colorWithRed:1.0 green:0.85 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    self.btnFav.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.btnFav addTarget:self action:@selector(openFavoritesTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnFav];
    
    // Row 2: [START SPOOF] and [STOP NORMAL]
    self.btnSpoof = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSpoof.frame = CGRectMake(12, 62, btnW, 48);
    self.btnSpoof.backgroundColor = [UIColor colorWithRed:0.15 green:0.68 blue:0.38 alpha:1.0];
    self.btnSpoof.layer.cornerRadius = 10;
    [self.btnSpoof setTitle:@"START SPOOF" forState:UIControlStateNormal];
    [self.btnSpoof setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnSpoof.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btnSpoof addTarget:self action:@selector(startSpoofTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnSpoof];
    
    self.btnNormal = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnNormal.frame = CGRectMake(self.view.bounds.size.width - 12 - btnW, 62, btnW, 48);
    self.btnNormal.backgroundColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.22 alpha:1.0];
    self.btnNormal.layer.cornerRadius = 10;
    [self.btnNormal setTitle:@"STOP NORMAL" forState:UIControlStateNormal];
    [self.btnNormal setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnNormal.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btnNormal addTarget:self action:@selector(stopNormalTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.btnNormal];
    
    [self loadGoogleMap];
}

- (void)loadGoogleMap {
    NSString *html = [NSString stringWithFormat:@""
    "<!DOCTYPE html><html><head>"
    "<meta name='viewport' content='initial-scale=1.0, user-scalable=no' />"
    "<style>html,body,#map{height:100%%;margin:0;padding:0;}</style>"
    "<script src='https://maps.googleapis.com/maps/api/js?key=AIzaSyCNSBu4Vp9Ip6elthoLwAuxRAmLcoFWRHM'></script>"
    "<script>"
    "var map, marker;"
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
            self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f, Lon: %.5f", g_spoofLatitude, g_spoofLongitude];
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
            self.coordsLabel.text = [NSString stringWithFormat:@"Lat: %.5f, Lon: %.5f", lat, lng];
            NSString *js = [NSString stringWithFormat:@"setMapPos(%f, %f);", lat, lng];
            [self.webView evaluateJavaScript:js completionHandler:nil];
            
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
}

- (void)stopNormalTapped {
    g_spoofEnabled = NO;
    self.btnSpoof.backgroundColor = [UIColor colorWithRed:0.15 green:0.68 blue:0.38 alpha:1.0];
    [self.btnSpoof setTitle:@"START SPOOF" forState:UIControlStateNormal];
    self.btnNormal.backgroundColor = [UIColor colorWithRed:0.5 green:0.15 blue:0.15 alpha:1.0];
    [self.btnNormal setTitle:@"NORMAL ACTIVE" forState:UIControlStateNormal];
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
                    
                    double expiry = 0.0;
                    if (json[@"expiresAt"]) {
                        expiry = [json[@"expiresAt"] doubleValue];
                    } else if (json[@"customer"] && json[@"customer"][@"expiresAt"]) {
                        expiry = [json[@"customer"][@"expiresAt"] doubleValue];
                    }
                    if (expiry > 0) [defs setDouble:expiry forKey:@"HadiMod_Expiry"];
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
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"\n\n\n\nHADI MOD X ERROR EXPERT"
                                                                   message:@"Enter your username and password to log in:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    // Add Dual Circular Logos to Alert Dialog
    UIImage *imgHadi = getImageFromBase64(kLogoHadiModBase64);
    if (imgHadi) {
        UIImageView *ivHadi = [[UIImageView alloc] initWithFrame:CGRectMake(45, 14, 46, 46)];
        ivHadi.image = imgHadi;
        ivHadi.layer.cornerRadius = 23;
        ivHadi.layer.masksToBounds = YES;
        ivHadi.layer.borderWidth = 1.5;
        ivHadi.layer.borderColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0].CGColor;
        [alert.view addSubview:ivHadi];
    }
    
    UIImage *imgError = getImageFromBase64(kLogoErrorExpertBase64);
    if (imgError) {
        UIImageView *ivError = [[UIImageView alloc] initWithFrame:CGRectMake(175, 14, 46, 46)];
        ivError.image = imgError;
        ivError.layer.cornerRadius = 23;
        ivError.layer.masksToBounds = YES;
        ivError.layer.borderWidth = 1.5;
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
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        BOOL loggedIn = [defs boolForKey:@"HadiMod_IsLoggedIn"];
        NSString *token = [defs stringForKey:@"HadiMod_Token"];
        
        double expiry = [defs doubleForKey:@"HadiMod_Expiry"];
        if (expiry > 0 && [[NSDate date] timeIntervalSince1970] > expiry) {
            showRevokedAlert(@"Subscription Expired", @"Your subscription period has ended. Please renew your account.");
            return;
        }
        
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
