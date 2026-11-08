#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static BOOL isSpoofingEnabled = NO;
static double targetLatitude = 24.4539;
static double targetLongitude = 54.3773;
static double selectedLatitude = 24.4539;
static double selectedLongitude = 54.3773;

static NSString *const kHadiModBaseUrl = @"https://api.hadimod3.net/auth/customer/login";
static NSString *const kHadiModProjectSlug = @"hadi-gps-3";
static NSString *const kGoogleMapsApiKey = @"AIzaSyCNSBu4Vp9Ip6elthoLwAuxRAmLcoFWRHM";

static NSString *const kHadiModBase64Logo = @"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";

static void loadSavedConfig() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"HadiMod_Lat"]) {
        targetLatitude = [defaults doubleForKey:@"HadiMod_Lat"];
        targetLongitude = [defaults doubleForKey:@"HadiMod_Lon"];
        selectedLatitude = targetLatitude;
        selectedLongitude = targetLongitude;
        isSpoofingEnabled = [defaults boolForKey:@"HadiMod_Enabled"];
    }
}

static BOOL isCustomerLoggedIn() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"HadiMod_IsLoggedIn"];
}

static NSString *getOrCreateDeviceId() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *deviceId = [defaults stringForKey:@"HadiMod_DeviceId"];
    if (!deviceId) {
        deviceId = [UIDevice currentDevice].identifierForVendor.UUIDString;
        if (!deviceId) deviceId = [[NSUUID UUID] UUIDString];
        [defaults setObject:deviceId forKey:@"HadiMod_DeviceId"];
        [defaults synchronize];
    }
    return deviceId;
}

// Hook CLLocationManager
%hook CLLocationManager

- (CLLocation *)location {
    if (isSpoofingEnabled && isCustomerLoggedIn()) {
        return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(targetLatitude, targetLongitude)
                                             altitude:15.0
                                   horizontalAccuracy:5.0
                                     verticalAccuracy:5.0
                                            timestamp:[NSDate date]];
    }
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    if (isSpoofingEnabled && isCustomerLoggedIn() && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(targetLatitude, targetLongitude)
                                                           altitude:15.0
                                                 horizontalAccuracy:5.0
                                                   verticalAccuracy:5.0
                                                          timestamp:[NSDate date]];
        [self.delegate locationManager:self didUpdateLocations:@[spoofed]];
    }
}

%end

// Interactive Google Map View Controller
@interface HadiModMapViewController : UIViewController <WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *startBtn;
@property (nonatomic, strong) UIButton *stopBtn;
- (void)loadGoogleMap;
- (void)startSpoofTapped;
- (void)stopSpoofTapped;
- (void)closeTapped;
@end

@implementation HadiModMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    // 1. Top Header Bar
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 100)];
    header.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95];
    [self.view addSubview:header];

    // Logo
    NSData *imgData = [[NSData alloc] initWithBase64EncodedString:kHadiModBase64Logo options:0];
    if (imgData) {
        UIImageView *logoView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 45, 45, 45)];
        logoView.image = [UIImage imageWithData:imgData];
        logoView.layer.cornerRadius = 22.5;
        logoView.layer.masksToBounds = YES;
        logoView.layer.borderWidth = 1.5;
        logoView.layer.borderColor = [UIColor redColor].CGColor;
        [header addSubview:logoView];
    }

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 48, 200, 22)];
    titleLabel.text = @"HADI MOD GPS";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [header addSubview:titleLabel];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 70, 230, 18)];
    self.statusLabel.text = [NSString stringWithFormat:@"Pin: %.5f, %.5f", selectedLatitude, selectedLongitude];
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    [header addSubview:self.statusLabel];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.view.bounds.size.width - 50, 50, 36, 36);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // 2. Interactive Google Map via WKWebView
    WKUserContentController *userContent = [[WKUserContentController alloc] init];
    [userContent addScriptMessageHandler:self name:@"mapClick"];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContent;

    CGFloat mapY = 100;
    CGFloat mapHeight = self.view.bounds.size.height - mapY - 95;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, mapY, self.view.bounds.size.width, mapHeight) configuration:config];
    [self.view addSubview:self.webView];

    [self loadGoogleMap];

    // 3. Bottom Control Bar with START & STOP Buttons
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 95, self.view.bounds.size.width, 95)];
    bottomBar.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.1 alpha:0.98];
    [self.view addSubview:bottomBar];

    CGFloat btnWidth = (self.view.bounds.size.width - 48) / 2;

    self.startBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startBtn.frame = CGRectMake(16, 15, btnWidth, 48);
    self.startBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.75 blue:0.35 alpha:1.0];
    [self.startBtn setTitle:@"START SPOOF" forState:UIControlStateNormal];
    [self.startBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.startBtn.layer.cornerRadius = 10;
    [self.startBtn addTarget:self action:@selector(startSpoofTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.startBtn];

    self.stopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.stopBtn.frame = CGRectMake(16 + btnWidth + 16, 15, btnWidth, 48);
    self.stopBtn.backgroundColor = [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:1.0];
    [self.stopBtn setTitle:@"STOP NORMAL" forState:UIControlStateNormal];
    [self.stopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.stopBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.stopBtn.layer.cornerRadius = 10;
    [self.stopBtn addTarget:self action:@selector(stopSpoofTapped) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.stopBtn];
}

- (void)loadGoogleMap {
    NSString *html = [NSString stringWithFormat:
        @"<!DOCTYPE html>"
        @"<html><head>"
        @"<meta name='viewport' content='initial-scale=1.0, user-scalable=no, width=device-width' />"
        @"<style>html, body, #map { height: 100%%; margin: 0; padding: 0; }</style>"
        @"<script src='https://maps.googleapis.com/maps/api/js?key=%@'></script>"
        @"<script>"
        @"var map, marker;"
        @"function init() {"
        @"  var pos = { lat: %f, lng: %f };"
        @"  map = new google.maps.Map(document.getElementById('map'), { zoom: 14, center: pos, disableDefaultUI: false });"
        @"  marker = new google.maps.Marker({ position: pos, map: map, draggable: true });"
        @"  map.addListener('click', function(e) {"
        @"    marker.setPosition(e.latLng);"
        @"    window.webkit.messageHandlers.mapClick.postMessage({ lat: e.latLng.lat(), lng: e.latLng.lng() });"
        @"  });"
        @"  marker.addListener('dragend', function(e) {"
        @"    window.webkit.messageHandlers.mapClick.postMessage({ lat: e.latLng.lat(), lng: e.latLng.lng() });"
        @"  });"
        @"}"
        @"</script></head><body onload='init()'><div id='map'></div></body></html>",
        kGoogleMapsApiKey, targetLatitude, targetLongitude];

    [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:@"https://maps.googleapis.com"]];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"mapClick"]) {
        NSDictionary *dict = (NSDictionary *)message.body;
        if (dict && dict[@"lat"] && dict[@"lng"]) {
            selectedLatitude = [dict[@"lat"] doubleValue];
            selectedLongitude = [dict[@"lng"] doubleValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = [NSString stringWithFormat:@"Selected: %.5f, %.5f", selectedLatitude, selectedLongitude];
            });
        }
    }
}

- (void)startSpoofTapped {
    targetLatitude = selectedLatitude;
    targetLongitude = selectedLongitude;
    isSpoofingEnabled = YES;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:targetLatitude forKey:@"HadiMod_Lat"];
    [defaults setDouble:targetLongitude forKey:@"HadiMod_Lon"];
    [defaults setBool:YES forKey:@"HadiMod_Enabled"];
    [defaults synchronize];

    UIAlertController *toast = [UIAlertController alertControllerWithTitle:@"Spoofing Started"
                                                                   message:[NSString stringWithFormat:@"Talabat Rider location moved to:\nLat: %.5f\nLon: %.5f", targetLatitude, targetLongitude]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [toast addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:toast animated:YES completion:nil];
}

- (void)stopSpoofTapped {
    isSpoofingEnabled = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:@"HadiMod_Enabled"];
    [defaults synchronize];

    UIAlertController *toast = [UIAlertController alertControllerWithTitle:@"Spoofing Stopped"
                                                                   message:@"Location reset to Real Original GPS."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [toast addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:toast animated:YES completion:nil];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// Forward declarations for Auth Helpers
static void showVpsLoginDialog(UIViewController *presenter);
static void executeVpsLogin(NSString *username, NSString *password, UIViewController *presenter);

static void showVpsLoginDialog(UIViewController *presenter) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HADI MOD LOGIN"
                                                                   message:@"api.hadimod3.net Cloud Authentication"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIViewController *contentVC = [[UIViewController alloc] init];
    contentVC.preferredContentSize = CGSizeMake(270, 85);
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:kHadiModBase64Logo options:0];
    if (imageData) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake((270 - 75) / 2, 5, 75, 75)];
        imageView.image = [UIImage imageWithData:imageData];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.layer.cornerRadius = 37.5;
        imageView.layer.masksToBounds = YES;
        imageView.layer.borderWidth = 2.5;
        imageView.layer.borderColor = [UIColor redColor].CGColor;
        [contentVC.view addSubview:imageView];
    }
    @try { [alert setValue:contentVC forKey:@"contentViewController"]; } @catch (NSException *e) {}

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Username";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Password";
        textField.secureTextEntry = YES;
    }];

    UIAlertAction *loginAction = [UIAlertAction actionWithTitle:@"Login & Open Map" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *user = alert.textFields[0].text;
        NSString *pass = alert.textFields[1].text;
        executeVpsLogin(user, pass, presenter);
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:loginAction];
    [alert addAction:cancelAction];

    [presenter presentViewController:alert animated:YES completion:nil];
}

static void executeVpsLogin(NSString *username, NSString *password, UIViewController *presenter) {
    if (username.length == 0 || password.length == 0) return;

    NSDictionary *jsonBody = @{
        @"project": kHadiModProjectSlug,
        @"username": username,
        @"password": password,
        @"deviceId": getOrCreateDeviceId()
    };

    NSData *postData = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kHadiModBaseUrl]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:20.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        BOOL success = (httpResp.statusCode == 200);
        NSString *errorMsg = @"Invalid Username or Password";

        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json && json[@"message"]) errorMsg = json[@"message"];
            else if (json && json[@"error"]) errorMsg = json[@"error"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:YES forKey:@"HadiMod_IsLoggedIn"];
                [defaults setObject:username forKey:@"HadiMod_Username"];
                [defaults synchronize];

                HadiModMapViewController *mapVC = [[HadiModMapViewController alloc] init];
                mapVC.modalPresentationStyle = UIModalPresentationFullScreen;
                [presenter presentViewController:mapVC animated:YES completion:nil];
            } else {
                UIAlertController *failAlert = [UIAlertController alertControllerWithTitle:@"Login Failed"
                                                                                   message:error ? error.localizedDescription : errorMsg
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                [failAlert addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    showVpsLoginDialog(presenter);
                }]];
                [presenter presentViewController:failAlert animated:YES completion:nil];
            }
        });
    }];
    [task resume];
}

// Hook UIWindow to trigger Login or Google Map
%hook UIWindow

- (void)didAddSubview:(UIView *)subview {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loadSavedConfig();
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleHadiModGate:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.numberOfTouchesRequired = 2;
        [self addGestureRecognizer:doubleTap];
    });
}

%new
- (void)handleHadiModGate:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;

    UIViewController *rootVC = self.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    if (!rootVC) return;

    if (isCustomerLoggedIn()) {
        HadiModMapViewController *mapVC = [[HadiModMapViewController alloc] init];
        mapVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [rootVC presentViewController:mapVC animated:YES completion:nil];
    } else {
        showVpsLoginDialog(rootVC);
    }
}

%end
