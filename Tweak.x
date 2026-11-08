#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

static BOOL isSpoofingEnabled = YES;
static double targetLatitude = 24.4539;   // Lat coordinates
static double targetLongitude = 54.3773;  // Lon coordinates

// Hook CLLocationManager to override static location queries
%hook CLLocationManager

- (CLLocation *)location {
    if (isSpoofingEnabled) {
        return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(targetLatitude, targetLongitude)
                                             altitude:10.0
                                   horizontalAccuracy:5.0
                                     verticalAccuracy:5.0
                                            timestamp:[NSDate date]];
    }
    return %orig;
}

%end

// Hook the delegate callbacks for live location updates
%hook NSObject

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (isSpoofingEnabled) {
        CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(targetLatitude, targetLongitude)
                                                           altitude:10.0
                                                 horizontalAccuracy:5.0
                                                   verticalAccuracy:5.0
                                                          timestamp:[NSDate date]];
        %orig(manager, @[spoofed]);
    } else {
        %orig(manager, locations);
    }
}

%end

// Hook UIWindow for two-finger double-tap menu toggle
%hook UIWindow

- (void)didAddSubview:(UIView *)subview {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTweakToggle:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.numberOfTouchesRequired = 2;
        [self addGestureRecognizer:doubleTap];
    });
}

%new
- (void)handleTweakToggle:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        isSpoofingEnabled = !isSpoofingEnabled;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"GPS Tweak"
                                                                       message:isSpoofingEnabled ? @"GPS Hook: ACTIVE" : @"GPS Hook: DISABLED"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

%end
