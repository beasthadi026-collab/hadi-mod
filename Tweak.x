// ============================================================================
//                    Tweak.x - TALABAT UNIFIED SAFE TWEAK
//   - Clean Native Apple MapKit (Full-screen radar with Tap-to-Pin)
//   - Branding: "HADI MOD X ERROR EXPERT" (Login & Map)
//   - [▶ PLAY (MOVE)] and [⏹ STOP (REAL GPS)] instant toggle buttons
//   - Auto-move while PLAY is active (single tap moves immediately)
//   - Coordinate Save & Favorites Manager (Custom Name, Lat, Lon)
//   - Dynamic Server Expiry & Live Delete Revocation (Every startup/foreground)
//   - Sideload Receipt Bypass (Kills "Unauthorized rider app" on Login)
//   - Strict 1:1 Hardware Lock bound to VPS: https://203.175.11.15.nip.io/admin/bind_dylib
//   - Safe Dynamic Delegate Forwarding
// ============================================================================

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>

static NSString *const kCLS_PrefKey_SpoofActive = @"CLS_SpoofActive";
static NSString *const kCLS_PrefKey_TargetLat   = @"CLS_TargetLat";
static NSString *const kCLS_PrefKey_TargetLon   = @"CLS_TargetLon";
static NSString *const kCLS_PrefKey_LicenseKey  = @"CLS_SavedKey";
static NSString *const kCLS_PrefKey_BoundDev    = @"CLS_BoundDev";
static NSString *const kCLS_PrefKey_Favorites   = @"CLS_SavedFavorites";

static const void *kCLDelegateProxyKey = &kCLDelegateProxyKey;

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
    
    // 2. Top Status Bar (Branding: HADI MOD X ERROR EXPERT)
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(15, 45, self.view.bounds.size.width - 30, 68)];
    topBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    topBar.layer.cornerRadius = 14;
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:topBar];
    
    self.lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 8, topBar.bounds.size.width - 70, 24)];
    self.lblTitle.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:1.0];
    self.lblTitle.font = [UIFont boldSystemFontOfSize:15];
    self.lblTitle.text = @"HADI MOD X ERROR EXPERT";
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
        
        NSDictionary *item = @{
            @"name": name,
            @"lat": @(lat),
            @"lon": @(lon)
        };
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
        [emptyAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
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
    static NSString *cellId = @"FavCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
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

#pragma mark - HARDWARE BIND & LICENSE ENGINE

static NSString *CLS_GetDeviceHardwareIdentifier(void) {
    NSString *vendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (vendor.length > 0) return vendor;
    return @"IPHONE-DEVICE-HWID-01";
}

static void CLS_RemoveFloatingMenuButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            NSArray *windows = [UIApplication sharedApplication].windows;
            if (windows.count > 0) window = windows.firstObject;
        }
        UIView *b = [window viewWithTag:998877];
        if (b) [b removeFromSuperview];
    });
}

static void CLS_ShowFloatingMenuButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            NSArray *windows = [UIApplication sharedApplication].windows;
            if (windows.count > 0) window = windows.firstObject;
        }
        if (!window || [window viewWithTag:998877]) return;
        
        UIButton *floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatBtn.tag = 998877;
        floatBtn.frame = CGRectMake(20, 140, 52, 52);
        floatBtn.layer.cornerRadius = 26;
        floatBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.95 alpha:0.9];
        [floatBtn setTitle:@"📍" forState:UIControlStateNormal];
        floatBtn.titleLabel.font = [UIFont systemFontOfSize:26];
        floatBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        floatBtn.layer.shadowOpacity = 0.4;
        floatBtn.layer.shadowRadius = 5;
        floatBtn.layer.shadowOffset = CGSizeMake(0, 3);
        
        [floatBtn addTarget:[CLSViewController class] action:@selector(cls_presentRadarScreen) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:floatBtn];
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

static void CLS_PromptKeyActivation(void);

static void CLS_VerifyAndBindLicense(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSString *savedKey = [defs stringForKey:kCLS_PrefKey_LicenseKey];
        NSString *hwid = CLS_GetDeviceHardwareIdentifier();
        
        if (savedKey.length > 5) {
            // Live Server Check: verify if key is still valid or deleted/expired on VPS
            NSString *urlStr = [NSString stringWithFormat:@"https://203.175.11.15.nip.io/admin/bind_dylib?key=%@&hwid=%@", savedKey, hwid];
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
            req.timeoutInterval = 8.0;
            
            [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSHTTPURLResponse *httpRes = (NSHTTPURLResponse *)res;
                    if (err) {
                        // Network offline - allow temporarily with existing button
                        CLS_ShowFloatingMenuButton();
                        return;
                    }
                    if (httpRes.statusCode == 200) {
                        // Key is valid & active on server
                        CLS_ShowFloatingMenuButton();
                    } else {
                        // Key expired or deleted from server! Revoke immediately:
                        [defs removeObjectForKey:kCLS_PrefKey_LicenseKey];
                        [defs setBool:NO forKey:kCLS_PrefKey_SpoofActive];
                        [defs synchronize];
                        
                        CLS_RemoveFloatingMenuButton();
                        
                        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
                        if (root) {
                            NSString *errMsg = (httpRes.statusCode == 404) ? @"Key was deleted from server!" : @"Key has expired (30 Days over)!";
                            UIAlertController *rev = [UIAlertController alertControllerWithTitle:@"HADI MOD X ERROR EXPERT"
                                                                                         message:errMsg
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                            [rev addAction:[UIAlertAction actionWithTitle:@"ACTIVATE NEW KEY" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                                CLS_PromptKeyActivation();
                            }]];
                            [root presentViewController:rev animated:YES completion:nil];
                        }
                    }
                });
            }] resume];
            return;
        }
        
        CLS_PromptKeyActivation();
    });
}

static void CLS_PromptKeyActivation(void) {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!root) return;
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *hwid = CLS_GetDeviceHardwareIdentifier();
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HADI MOD X ERROR EXPERT"
                                                                   message:@""
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"VIP-XXXX-XXXX-XX";
    }];
    
    UIAlertAction *submit = [UIAlertAction actionWithTitle:@"ACTIVATE" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *inputKey = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (inputKey.length == 0) return;
        
        NSString *urlStr = [NSString stringWithFormat:@"https://203.175.11.15.nip.io/admin/bind_dylib?key=%@&hwid=%@", inputKey, hwid];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.timeoutInterval = 10.0;
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSHTTPURLResponse *httpRes = (NSHTTPURLResponse *)res;
                if (!err && httpRes.statusCode == 200) {
                    [defs setObject:inputKey forKey:kCLS_PrefKey_LicenseKey];
                    [defs setObject:hwid forKey:kCLS_PrefKey_BoundDev];
                    [defs synchronize];
                    
                    UIAlertController *succ = [UIAlertController alertControllerWithTitle:@"HADI MOD X ERROR EXPERT"
                                                                                  message:@"Key bound to this iPhone! Floating radar enabled."
                                                                           preferredStyle:UIAlertControllerStyleAlert];
                    [succ addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                        CLS_ShowFloatingMenuButton();
                    }]];
                    [root presentViewController:succ animated:YES completion:nil];
                } else {
                    NSString *errMsg = @"Activation failed. Key is expired, deleted, or locked to another iPhone!";
                    UIAlertController *fail = [UIAlertController alertControllerWithTitle:@"HADI MOD X ERROR EXPERT"
                                                                                  message:errMsg
                                                                           preferredStyle:UIAlertControllerStyleAlert];
                    [fail addAction:[UIAlertAction actionWithTitle:@"RETRY" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                        CLS_PromptKeyActivation();
                    }]];
                    [root presentViewController:fail animated:YES completion:nil];
                }
            });
        }] resume];
    }];
    
    [alert addAction:submit];
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
