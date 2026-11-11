#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

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
    if ([_realDelegate respondsToSelector:aSelector]) {
        return YES;
    }
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
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    BOOL spoofActive = [defs boolForKey:@"HadiMod_SpoofEnabled"];
    
    if (spoofActive) {
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
    
    if ([_realDelegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [_realDelegate locationManager:manager didUpdateLocations:locations];
    }
}

@end

static const void *HadiProxyKey = &HadiProxyKey;

@implementation CLLocationManager (HadiTalabatHook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method origReceipt = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
        Method swizReceipt = class_getInstanceMethod([NSBundle class], @selector(talabat_appStoreReceiptURL));
        if (origReceipt && swizReceipt) {
            method_exchangeImplementations(origReceipt, swizReceipt);
        }

        Method origSetDel = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:));
        Method swizSetDel = class_getInstanceMethod([CLLocationManager class], @selector(hadi_setDelegate:));
        if (origSetDel && swizSetDel) {
            method_exchangeImplementations(origSetDel, swizSetDel);
        }

        Method origLoc = class_getInstanceMethod([CLLocationManager class], @selector(location));
        Method swizLoc = class_getInstanceMethod([CLLocationManager class], @selector(hadi_location));
        if (origLoc && swizLoc) {
            method_exchangeImplementations(origLoc, swizLoc);
        }
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
    return [self hadi_location];
}

@end
