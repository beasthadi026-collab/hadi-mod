#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

static BOOL isSpoofingEnabled = YES;
static double targetLatitude = 24.4539;
static double targetLongitude = 54.3773;

static NSString *const kHadiModBase64Logo = @"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";

static void loadSavedCoordinates() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"HadiMod_Lat"]) {
        targetLatitude = [defaults doubleForKey:@"HadiMod_Lat"];
        targetLongitude = [defaults doubleForKey:@"HadiMod_Lon"];
        isSpoofingEnabled = [defaults boolForKey:@"HadiMod_Enabled"];
    }
}

// Hook CLLocationManager to return custom coordinates
%hook CLLocationManager

- (CLLocation *)location {
    if (isSpoofingEnabled) {
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
    if (isSpoofingEnabled && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocation *spoofed = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(targetLatitude, targetLongitude)
                                                           altitude:15.0
                                                 horizontalAccuracy:5.0
                                                   verticalAccuracy:5.0
                                                          timestamp:[NSDate date]];
        [self.delegate locationManager:self didUpdateLocations:@[spoofed]];
    }
}

%end

// Hook UIWindow to listen for 2-finger double tap gesture
%hook UIWindow

- (void)didAddSubview:(UIView *)subview {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loadSavedCoordinates();
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleHadiModMenu:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.numberOfTouchesRequired = 2;
        [self addGestureRecognizer:doubleTap];
    });
}

%new
- (void)handleHadiModMenu:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    
    UIViewController *rootVC = self.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    if (!rootVC) return;

    NSString *title = @"\n\n\n\n⚡ HADI MOD ⚡";
    NSString *message = @"Custom GPS Controller & Teleport";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // Decode and display custom branding logo
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:kHadiModBase64Logo options:0];
    if (imageData) {
        UIImage *logoImage = [UIImage imageWithData:imageData];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:logoImage];
        imageView.frame = CGRectMake(100, 15, 70, 70);
        imageView.layer.cornerRadius = 35;
        imageView.layer.masksToBounds = YES;
        imageView.layer.borderWidth = 2.0;
        imageView.layer.borderColor = [UIColor redColor].CGColor;
        [alert.view addSubview:imageView];
    }

    // Latitude input field
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Latitude (e.g. 24.4539)";
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.text = [NSString stringWithFormat:@"%.6f", targetLatitude];
    }];

    // Longitude input field
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Longitude (e.g. 54.3773)";
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.text = [NSString stringWithFormat:@"%.6f", targetLongitude];
    }];

    // Apply Location Action
    UIAlertAction *applyAction = [UIAlertAction actionWithTitle:@"Apply Location" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *latStr = alert.textFields[0].text;
        NSString *lonStr = alert.textFields[1].text;
        
        if (latStr.length > 0 && lonStr.length > 0) {
            targetLatitude = [latStr doubleValue];
            targetLongitude = [lonStr doubleValue];
            isSpoofingEnabled = YES;

            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setDouble:targetLatitude forKey:@"HadiMod_Lat"];
            [defaults setDouble:targetLongitude forKey:@"HadiMod_Lon"];
            [defaults setBool:YES forKey:@"HadiMod_Enabled"];
            [defaults synchronize];
        }
    }];

    // Turn Off Spoofing
    UIAlertAction *offAction = [UIAlertAction actionWithTitle:@"Turn OFF Spoof" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        isSpoofingEnabled = NO;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:NO forKey:@"HadiMod_Enabled"];
        [defaults synchronize];
    }];

    // Cancel
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:applyAction];
    [alert addAction:offAction];
    [alert addAction:cancelAction];

    [rootVC presentViewController:alert animated:YES completion:nil];
}

%end
