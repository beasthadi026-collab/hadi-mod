#import <CoreLocation/CoreLocation.h>

static BOOL isSpoofingEnabled = YES;
static double targetLatitude = 24.4539;
static double targetLongitude = 54.3773;

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

- (void)startUpdatingLocation {
    %orig;
    if (isSpoofingEnabled && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(targetLatitude, targetLongitude)
                                                           altitude:10.0
                                                 horizontalAccuracy:5.0
                                                   verticalAccuracy:5.0
                                                          timestamp:[NSDate date]];
        [self.delegate locationManager:self didUpdateLocations:@[spoofed]];
    }
}

%end
