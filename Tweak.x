// ============================================================================
// Tweak.x - TALABAT UNIFIED SAFE TWEAK
//   - Clean Native Apple MapKit (Full-screen radar with Tap-to-Pin)
//   - Branding: "DEV ABDULLAH X HADI MOD" (Login & Map)
//   - Trigger: 3 Fingers Double Tap (3 ungliyon se 2 baar tap)
//   - Auto-Prompt VIP Key popup on App Open if not activated
//   - [▶ PLAY (MOVE)] and [⏹ STOP (REAL GPS)] instant toggle buttons
//   - Auto-move while PLAY is active (single tap moves immediately)
//   - Coordinate Save & Favorites Manager (Custom Name, Lat, Lon)
//   - DOUBLE EXPIRY SHIELD:
//       1. Local Device Clock Check (Instant lock if device date > 30 days)
//       2. Remote Server Expiry & Revocation Check (/admin/bind_dylib)
//   - Sideload Receipt Bypass (Kills "Unauthorized rider app" on Login)
//   - Strict 1:1 Hardware Lock bound to VPS: https://hadimod.tech/admin/bind_dylib
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
static NSString *const kCLS_PrefKey_FirstActive = @"CLS_FirstActiveTimestamp";
static NSString *const kCLS_PrefKey_Favorites   = @"CLS_SavedFavorites";
static NSString *const kCLS_FavCellIdentifier   = @"FavCell";

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
    self.lblStatus.text = @"Tap map to pin location";
    [topBar addSubview:self.lblStatus];
    
    self.btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnClose.frame = CGRectMake(topBar.bounds.size.width - 50, 14, 40, 40);
    [self.btnClose setTitle:@"✕" forState:UIControlStateNormal];
    [self.btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnClose.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.btnClose.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];
    self.btnClose.layer.cornerRadius = 20;
    [self.btnClose addTarget:self action:@selector(dismissRadar) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:self.btnClose];
    
    // 3. Side Actions: Favorites & Save
    self.btnFavorites = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnFavorites.frame = CGRectMake(self.view.bounds.size.width - 65, 125, 50, 50);
    self.btnFavorites.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.btnFavorites.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.btnFavorites.layer.cornerRadius = 25;
    [self.btnFavorites setTitle:@"★" forState:UIControlStateNormal];
    [self.btnFavorites setTitleColor:[UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0] forState:UIControlStateNormal];
    self.btnFavorites.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.btnFavorites addTarget:self action:@selector(toggleFavoritesOverlay) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnFavorites];
    
    self.btnSaveCoord = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSaveCoord.frame = CGRectMake(self.view.bounds.size.width - 65, 185, 50, 50);
    self.btnSaveCoord.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.btnSaveCoord.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.btnSaveCoord.layer.cornerRadius = 25;
    [self.btnSaveCoord setTitle:@"💾" forState:UIControlStateNormal];
    [self.btnSaveCoord setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnSaveCoord.titleLabel.font = [UIFont systemFontOfSize:20];
    [self.btnSaveCoord addTarget:self action:@selector(promptSaveCoordinate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnSaveCoord];
    
    // 4. Bottom Controls: PLAY (MOVE) and STOP (REAL GPS)
    CGFloat bottomWidth = (self.view.bounds.size.width - 45) / 2.0;
    CGFloat bottomY = self.view.bounds.size.height - 85;
    
    self.btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPlay.frame = CGRectMake(15, bottomY, bottomWidth, 52);
    self.btnPlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    self.btnPlay.backgroundColor = [UIColor colorWithRed:0.1 green:0.75 blue:0.35 alpha:1.0];
    self.btnPlay.layer.cornerRadius = 14;
    [self.btnPlay setTitle:@"▶ PLAY (MOVE)" forState:UIControlStateNormal];
    [self.btnPlay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnPlay.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.btnPlay addTarget:self action:@selector(startSpoofing) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnPlay];
    
    self.btnStop = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnStop.frame = CGRectMake(15 + bottomWidth + 15, bottomY, bottomWidth, 52);
    self.btnStop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    self.btnStop.backgroundColor = [UIColor colorWithRed:0.9 green:0.25 blue:0.25 alpha:1.0];
    self.btnStop.layer.cornerRadius = 14;
    [self.btnStop setTitle:@"⏹ STOP (REAL GPS)" forState:UIControlStateNormal];
    [self.btnStop setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnStop.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.btnStop addTarget:self action:@selector(stopSpoofing) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStop];
    
    [self loadSavedState];
    [self setupFavoritesOverlay];
}

- (void)loadSavedState {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    BOOL spoofOn = [defs boolForKey:kCLS_PrefKey_SpoofActive];
    double lat = [defs doubleForKey:kCLS_PrefKey_TargetLat];
    double lon = [defs doubleForKey:kCLS_PrefKey_TargetLon];
    
    if (lat != 0.0 && lon != 0.0) {
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
        [self addPinAtCoordinate:coord];
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coord, 600, 600);
        [self.mapView setRegion:region animated:NO];
        if (spoofOn) {
            self.lblStatus.text = [NSString stringWithFormat:@"MOVING: %.4f, %.4f", lat, lon];
            self.lblStatus.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.4 alpha:1.0];
        } else {
            self.lblStatus.text = [NSString stringWithFormat:@"PIN: %.4f, %.4f", lat, lon];
        }
    }
}

- (void)handleMapTap:(UITapGestureRecognizer *)gesture {
    CGPoint touchPoint = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D touchCoord = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
    
    [self addPinAtCoordinate:touchCoord];
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:touchCoord.latitude forKey:kCLS_PrefKey_TargetLat];
    [defs setDouble:touchCoord.longitude forKey:kCLS_PrefKey_TargetLon];
    [defs synchronize];
    
    BOOL spoofOn = [defs boolForKey:kCLS_PrefKey_SpoofActive];
    if (spoofOn) {
        self.lblStatus.text = [NSString stringWithFormat:@"MOVING: %.4f, %.4f", touchCoord.latitude, touchCoord.longitude];
        self.lblStatus.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.4 alpha:1.0];
    } else {
        self.lblStatus.text = [NSString stringWithFormat:@"PINNED: %.4f, %.4f", touchCoord.latitude, touchCoord.longitude];
        self.lblStatus.textColor = [UIColor whiteColor];
    }
}

- (void)addPinAtCoordinate:(CLLocationCoordinate2D)coord {
    if (self.pin) {
        [self.mapView removeAnnotation:self.pin];
    }
    self.pin = [[MKPointAnnotation alloc] init];
    self.pin.coordinate = coord;
    self.pin.title = @"Spoofed Location";
    [self.mapView addAnnotation:self.pin];
}

- (void)startSpoofing {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    double lat = [defs doubleForKey:kCLS_PrefKey_TargetLat];
    double lon = [defs doubleForKey:kCLS_PrefKey_TargetLon];
    
    if (lat == 0.0 && lon == 0.0) {
        self.lblStatus.text = @"Select location on map first!";
        self.lblStatus.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
        return;
    }
    
    [defs setBool:YES forKey:kCLS_PrefKey_SpoofActive];
    [defs synchronize];
    
    self.lblStatus.text = [NSString stringWithFormat:@"MOVING: %.4f, %.4f", lat, lon];
    self.lblStatus.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.4 alpha:1.0];
    [self animateButtonPulse:self.btnPlay];
}

- (void)stopSpoofing {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:NO forKey:kCLS_PrefKey_SpoofActive];
    [defs synchronize];
    
    self.lblStatus.text = @"REAL GPS RESTORED";
    self.lblStatus.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
    [self animateButtonPulse:self.btnStop];
}

- (void)dismissRadar {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)animateButtonPulse:(UIButton *)btn {
    [UIView animateWithDuration:0.15 animations:^{
        btn.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            btn.transform = CGAffineTransformIdentity;
        }];
    }];
}

#pragma mark - FAVORITES MANAGER

- (void)setupFavoritesOverlay {
    self.favOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.favOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.favOverlay.hidden = YES;
    self.favOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.favOverlay];
    
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, self.view.bounds.size.height - 200)];
    card.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.favOverlay addSubview:card];
    
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, card.bounds.size.width - 80, 30)];
    header.text = @"Saved Favorites";
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:18];
    [card addSubview:header];
    
    UIButton *closeFav = [UIButton buttonWithType:UIButtonTypeCustom];
    closeFav.frame = CGRectMake(card.bounds.size.width - 50, 10, 40, 40);
    [closeFav setTitle:@"✕" forState:UIControlStateNormal];
    [closeFav setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeFav addTarget:self action:@selector(toggleFavoritesOverlay) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:closeFav];
    
    self.favTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 55, card.bounds.size.width, card.bounds.size.height - 55) style:UITableViewStylePlain];
    self.favTableView.backgroundColor = [UIColor clearColor];
    self.favTableView.delegate = self;
    self.favTableView.dataSource = self;
    self.favTableView.separatorColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    self.favTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [card addSubview:self.favTableView];
    
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kCLS_PrefKey_Favorites];
    self.favList = saved ? [saved mutableCopy] : [NSMutableArray array];
}

- (void)toggleFavoritesOverlay {
    self.favOverlay.hidden = !self.favOverlay.hidden;
    if (!self.favOverlay.hidden) {
        [self.favTableView reloadData];
    }
}

- (void)promptSaveCoordinate {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    double lat = [defs doubleForKey:kCLS_PrefKey_TargetLat];
    double lon = [defs doubleForKey:kCLS_PrefKey_TargetLon];
    
    if (lat == 0.0 && lon == 0.0) {
        self.lblStatus.text = @"Pin a location first before saving!";
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                   message:[NSString stringWithFormat:@"Save Favorite Location:\n%.4f, %.4f", lat, lon]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Location Name (e.g. Zone 1 / Hub)";
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields.firstObject.text;
        if (!name || name.length == 0) name = @"Favorite Spot";
        
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        [item setObject:name forKey:@"name"];
        [item setObject:@(lat) forKey:@"lat"];
        [item setObject:@(lon) forKey:@"lon"];
        
        [self.favList addObject:item];
        [[NSUserDefaults standardUserDefaults] setObject:self.favList forKey:kCLS_PrefKey_Favorites];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        self.lblStatus.text = [NSString stringWithFormat:@"Saved: %@", name];
    }];
    
    [alert addAction:saveAction];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.favList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCLS_FavCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCLS_FavCellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
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
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:lat forKey:kCLS_PrefKey_TargetLat];
    [defs setDouble:lon forKey:kCLS_PrefKey_TargetLon];
    [defs synchronize];
    
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
    [self addPinAtCoordinate:coord];
    [self.mapView setCenterCoordinate:coord animated:YES];
    
    [self toggleFavoritesOverlay];
    self.lblStatus.text = [NSString stringWithFormat:@"Loaded: %@", item[@"name"]];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.favList removeObjectAtIndex:indexPath.row];
        [[NSUserDefaults standardUserDefaults] setObject:self.favList forKey:kCLS_PrefKey_Favorites];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

@end

#pragma mark - HARDWARE KEYCHAIN DEVICE ID HELPER

static NSString *getPersistentDeviceHWID(void) {
    NSString *service = @"com.devabdullah.hadimod.hwid";
    NSString *account = @"device_unique_id";
    
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:service forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess && result) {
        NSData *data = (__bridge_transfer NSData *)result;
        NSString *hwid = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (hwid && hwid.length > 5) return hwid;
    }
    
    // Generate fresh persistent UUID
    NSString *newHWID = [[UIDevice currentDevice].identifierForVendor UUIDString];
    if (!newHWID) newHWID = [[NSUUID UUID] UUIDString];
    
    NSMutableDictionary *addQuery = [NSMutableDictionary dictionary];
    [addQuery setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [addQuery setObject:service forKey:(__bridge id)kSecAttrService];
    [addQuery setObject:account forKey:(__bridge id)kSecAttrAccount];
    [addQuery setObject:[newHWID dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecValueData];
    [addQuery setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
    
    SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    return newHWID;
}

#pragma mark - GESTURE INJECTION (3 Fingers Double Tap)

@interface CLSViewController (Launcher)
+ (void)cls_presentRadarScreen;
@end

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

static void CLS_InstallDoubleTapGesture(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            NSArray *windows = [UIApplication sharedApplication].windows;
            if (windows.count > 0) window = windows.firstObject;
        }
        if (!window) return;
        
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

#pragma mark - LICENSE ENFORCEMENT & REMOTE BINDING

static void showLicenseActivationDialog(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        if (!rootVC) return;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                       message:@"Enter your VIP GPS License Key to activate:"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"XXXX-XXXX-XXXX";
            textField.textAlignment = NSTextAlignmentCenter;
            textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
        }];
        
        UIAlertAction *activateAction = [UIAlertAction actionWithTitle:@"ACTIVATE" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *rawKey = alert.textFields.firstObject.text;
            NSString *key = [rawKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!key || key.length < 5) {
                showLicenseActivationDialog();
                return;
            }
            
            NSString *hwid = getPersistentDeviceHWID();
            
            // Remote verification against Hostinger VPS
            NSString *urlStr = [NSString stringWithFormat:@"https://hadimod.tech/admin/bind_dylib?key=%@&hwid=%@",
                                [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                                [hwid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
            
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
            req.HTTPMethod = @"GET";
            req.timeoutInterval = 10.0;
            
            [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                NSHTTPURLResponse *httpRes = (NSHTTPURLResponse *)response;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!error && httpRes.statusCode == 200) {
                        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                        [defs setObject:key forKey:kCLS_PrefKey_LicenseKey];
                        [defs setObject:hwid forKey:kCLS_PrefKey_BoundDev];
                        if (![defs doubleForKey:kCLS_PrefKey_FirstActive]) {
                            [defs setDouble:[[NSDate date] timeIntervalSince1970] forKey:kCLS_PrefKey_FirstActive];
                        }
                        [defs synchronize];
                        
                        CLS_InstallDoubleTapGesture();
                        
                        UIAlertController *succAlert = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                                          message:@"✓ Key Activated Successfully!\n3 Fingers Double-Tap anywhere to open GPS Radar."
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                        [succAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        [rootVC presentViewController:succAlert animated:YES completion:nil];
                    } else {
                        UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"DEV ABDULLAH X HADI MOD"
                                                                                          message:@"Activation failed. Key is expired, deleted, or locked to another iPhone!"
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                        [errAlert addAction:[UIAlertAction actionWithTitle:@"RETRY" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull a) {
                            showLicenseActivationDialog();
                        }]];
                        [rootVC presentViewController:errAlert animated:YES completion:nil];
                    }
                });
            }] resume];
        }];
        
        [alert addAction:activateAction];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

static void verifyLicenseOnAppLaunch(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSString *savedKey = [defs stringForKey:kCLS_PrefKey_LicenseKey];
        NSString *hwid = getPersistentDeviceHWID();
        
        // Shield 1: Local Clock Expiry (30 Days)
        double firstActive = [defs doubleForKey:kCLS_PrefKey_FirstActive];
        if (firstActive > 0) {
            double elapsed = [[NSDate date] timeIntervalSince1970] - firstActive;
            if (elapsed > (30.0 * 86400.0)) {
                [defs removeObjectForKey:kCLS_PrefKey_LicenseKey];
                [defs synchronize];
                savedKey = nil;
            }
        }
        
        if (!savedKey || savedKey.length < 5) {
            showLicenseActivationDialog();
            return;
        }
        
        // Shield 2: Remote Revocation & Multi-device Lock Check
        NSString *urlStr = [NSString stringWithFormat:@"https://hadimod.tech/admin/bind_dylib?key=%@&hwid=%@",
                            [savedKey stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                            [hwid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"GET";
        req.timeoutInterval = 8.0;
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSHTTPURLResponse *httpRes = (NSHTTPURLResponse *)response;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error && httpRes.statusCode == 200) {
                    CLS_InstallDoubleTapGesture();
                } else {
                    [defs removeObjectForKey:kCLS_PrefKey_LicenseKey];
                    [defs synchronize];
                    showLicenseActivationDialog();
                }
            });
        }] resume];
    });
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
    
    // 3. Register Application Did Become Active -> Triggers Password Popup on App Open!
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        verifyLicenseOnAppLaunch();
    }];
}
