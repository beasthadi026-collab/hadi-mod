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
                UIAlertController *failAlert = [UIAlertController alertControllerWithTitle:@"❌ Login Failed"
                                                                                   message:error ? error.localizedDescription : errorMsg
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                [failAlert addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    [self showVpsLoginDialog:presenter];
                }]];
                [presenter presentViewController:failAlert animated:YES completion:nil];
            }
        });
    }];
    [task resume];
}
%end
