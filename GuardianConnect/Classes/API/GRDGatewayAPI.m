//
//  GRDGatewayAPI.m
//  Guardian
//
//  Copyright © 2017 Sudo Security Group Inc. All rights reserved.
//

#import "GRDGatewayAPI.h"
#import <NetworkExtension/NetworkExtension.h>
#import "GRDVPNHelper.h"

@implementation GRDGatewayAPI
@synthesize healthCheckTimer;

- (NSString *)apiHostname {
    return [[[GRDVPNHelper sharedInstance] mainCredential] hostname];
}

- (NSString *)apiAuthToken {
    return [[[GRDVPNHelper sharedInstance] mainCredential] apiAuthToken];
}

- (NSString *)deviceIdentifier {
    return [[[GRDVPNHelper sharedInstance] mainCredential] username];
}

- (BOOL)isVPNConnected {
    return ([[[NEVPNManager sharedManager] connection] status] == NEVPNStatusConnected);
}

/// legacy, this will be going away in the future
- (void)_loadCredentialsFromKeychain {
    [[GRDVPNHelper sharedInstance] setMainCredential:[GRDCredentialManager mainCredentials]];
}

- (NSString *)baseHostname {
    GRDCredential *main = [[GRDVPNHelper sharedInstance] mainCredential];
    if (main){
        return [main hostname];
    }
    return [[NSUserDefaults standardUserDefaults] valueForKey:kGRDHostnameOverride];
}

- (BOOL)_canMakeApiRequests {
    if ([self baseHostname] == nil) {
        return NO;
    } else {
        return YES;
    }
}

#pragma mark - Network health checks
- (void)stopHealthCheckTimer {
    if (self.healthCheckTimer != nil) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
}

- (void)startHealthCheckTimer {
    LOG_SELF;
    [self stopHealthCheckTimer];
    self.healthCheckTimer = [NSTimer scheduledTimerWithTimeInterval:10 repeats:true block:^(NSTimer * _Nonnull timer) {
        [self networkHealthCheck];
    }];
}

- (void)networkHealthCheck {
    [self networkProbeWithCompletion:^(BOOL status, NSError *error) {
        GRDNetworkHealthType health = GRDNetworkHealthUnknown;
        if ([error code] == NSURLErrorNotConnectedToInternet ||
            //[error code] == NSURLErrorTimedOut || // comment out until we are 100% file will be available - network health NEVER comes back as bad when this is off during testing.
            [error code] == NSURLErrorInternationalRoamingOff || [error code] == NSURLErrorDataNotAllowed) {
            NSLog(@"[DEBUG] network health check is bad mkay");
            health = GRDNetworkHealthBad;
        } else {
            health = GRDNetworkHealthGood;
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kGuardianNetworkHealthStatusNotification object:[NSNumber numberWithInteger:health]];
    }];
}

- (void)networkProbeWithCompletion:(void (^)(BOOL status, NSError *error))completion {
    //https://guardianapp.com/network-probe.txt
    //easier than the usual setup, and doing it in the bg so it will be fine.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSURL *URL = [NSURL URLWithString:@"https://guardianapp.com/network-probe.txt"];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.0];
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"[DEBUG][networkProbeWithCompletion] error!! %@", error);
                completion(false,error);
            } else {
                //TODO: do we actually care about the contents of the file?
                completion(true, error);
            }
        }];
        [task resume];
    });
}


- (NSMutableURLRequest *)_requestWithEndpoint:(NSString *)apiEndpoint andPostRequestData:(NSData *)postRequestDat {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", [self baseHostname], apiEndpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
	
	[request setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forHTTPHeaderField:@"X-Guardian-Build"];
	
	[request setHTTPMethod:@"POST"];
    [request setHTTPBody:postRequestDat];
    
    return request;
}

- (void)getServerStatusWithCompletion:(void (^)(GRDGatewayAPIResponse *apiResponse))completion {
    if ([self _canMakeApiRequests] == NO) {
        NSLog(@"[DEBUG][getServerStatus] cannot make API requests !!! won't continue");
        if (completion) {
            completion([GRDGatewayAPIResponse deniedResponse]);
        }
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", [self baseHostname], kSGAPI_ServerStatus]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setTimeoutInterval:10.0f];
    [request setHTTPMethod:@"GET"];
    [request setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forHTTPHeaderField:@"X-Guardian-Build"];
    
#if GUARDIAN_INTERNAL
    GRDDebugHelper *debugHelper = [[GRDDebugHelper alloc] initWithTitle:@"getServerStatusWithCompletion"];
#endif
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
#if GUARDIAN_INTERNAL
        [debugHelper logTimeWithMessage:@"request completion block start"];
#endif
        
        GRDGatewayAPIResponse *respObj = [[GRDGatewayAPIResponse alloc] init];
        respObj.urlResponse = response;
        
        if (error) {
            if (error.code == NSURLErrorCannotConnectToHost) {
                NSLog(@"Couldn't get server status. Host is offline");
                respObj.responseStatus = GRDGatewayAPIServerNotOK;
                if (completion) completion(respObj);
                
            } else {
                NSLog(@"[DEBUG][getServerStatus] request error = %@", error);
                respObj.error = error;
                respObj.responseStatus = GRDGatewayAPIUnknownError;
                completion(respObj);
            }
        } else {
            if ([(NSHTTPURLResponse *)response statusCode] == 200) {
                respObj.responseStatus = GRDGatewayAPIServerOK;
            } else if ([(NSHTTPURLResponse *)response statusCode] == 500) {
                NSLog(@"[DEBUG][getServerStatus] Server error! Need to use different server");
                respObj.responseStatus = GRDGatewayAPIServerInternalError;
            } else if ([(NSHTTPURLResponse *)response statusCode] == 404) {
                NSLog(@"[DEBUG][getServerStatus] Endpoint not found on this server!");
                respObj.responseStatus = GRDGatewayAPIEndpointNotFound;
            } else {
                NSLog(@"[DEBUG][getServerStatus] unknown error!");
                respObj.responseStatus = GRDGatewayAPIUnknownError;
            }
            
            if (data != nil) {
                // The /server-status endpoint has been changed to never return data.
                // This is legacy that way meant to report the capcity-score to the app
                // It is now reported through housekeeping. This will be removed in the next API iteration
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                respObj.jsonData = json;
            }
            
#if GUARDIAN_INTERNAL
            [debugHelper logTimeWithMessage:@"request completion block end"];
#endif
            completion(respObj);
        }
    }];
    
    [task resume];
}

- (void)verifyEAPCredentialsUsername:(NSString *)eapUsername apiToken:(NSString *)apiToken andSubscriberCredential:(NSString *)subscriberCredential forVPNNode:(NSString *)vpnNode completion:(void (^)(BOOL, BOOL, NSString * _Nullable, BOOL))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.2/device/%@/verify-credentials", vpnNode, eapUsername]]];
    
    if (eapUsername == nil || apiToken == nil || subscriberCredential == nil || vpnNode == nil) {
        if (completion) completion(NO, NO, @"nil variable detected. Aborting", NO);
        return;
    }
    
    NSError *encodingError;
    NSData *jsonBody = [NSJSONSerialization dataWithJSONObject:@{@"subscriber-credential": subscriberCredential, @"api-auth-token": apiToken} options:0 error:&encodingError];
    if (encodingError != nil) {
        GRDLog(@"Failed to encode JSON body: %@", encodingError);
        if (completion) completion(NO, NO, @"Failed to encode JSON body", NO);
        return;
    }
    
    [request setHTTPBody:jsonBody];
    [request setHTTPMethod:@"POST"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to send request: %@", error);
            if (completion) completion(NO, NO, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]], NO);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 200) {
            if (completion) completion(YES, YES, nil, NO);
            return;
        
        } else {
            NSError *decodeError;
            NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeError];
            if (decodeError != nil) {
                GRDLog(@"Failed to decode error JSON from VPN node: %@", decodeError);
                if (completion) completion(YES, NO, @"Failed to deocde error JSON from VPN node", NO);
                return;
            }
            
            NSString *errorMessage = [errorDict objectForKey:@"error-message"];
            GRDLog(@"Request failed. Client needs to migrate! Server status code: %ld - error message: %@", statusCode, errorMessage);
            if ([errorMessage containsString:@"Subscriber Credential"]) {
                GRDLog(@"Subscriber Credential invalid or expired. Obtain a new one");
                if (completion) completion(YES, NO, @"Request failed. Client needs to migrate!", YES);
                
            } else {
                if (completion) completion(YES, NO, @"Request failed. Client needs to migrate!", NO);
            }
            return;
        }
    }];
    [task resume];
}

- (void)registerAndCreateWithHostname:(NSString *)hostname subscriberCredential:(NSString *)subscriberCredential validForDays:(NSInteger)validFor completion:(void (^)(NSDictionary * _Nullable, BOOL, NSString * _Nullable))completion {
    NSLog(@"hostname: %@", hostname);
    //we don't need to do [self _canMakeApiRequests] here because that just checks for a hostname, and we get a hostname as one of the parameters.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.1/register-and-create", hostname]]];
    [request setHTTPMethod:@"POST"];
    
    NSDictionary *jsonDict = @{@"subscriber-credential":subscriberCredential, @"valid-for":[NSNumber numberWithInteger:validFor]};
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
    
#if GUARDIAN_INTERNAL
    GRDDebugHelper *debugHelper = [[GRDDebugHelper alloc] initWithTitle:@"registerAndCreateWithSubscriberCredential"];
#endif
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
#if GUARDIAN_INTERNAL
        [debugHelper logTimeWithMessage:@"request completion block start"];
#endif
        if (error != nil) {
            NSLog(@"Couldn't connect to host: %@", [error localizedDescription]);
            if (completion) completion(nil, NO, @"Error connecting to server");
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            NSLog(@"Internal server error authenticating with subscriber credential");
            if (completion) completion(nil, NO, @"Internal server error authenticating with subscriber credential");
            return;
            
        } else if (statusCode == 410 || statusCode == 406) {
            NSLog(@"Subscriber credential invalid: %@", subscriberCredential);
            [GRDKeychain removeSubscriberCredentialWithRetries:3];
            if (completion) completion(nil, NO, @"Invalid Subscriber Credential. Please try again.");
            return;
            
        } else if (statusCode == 400) {
            NSLog(@"Subscriber credential missing");
            if (completion) completion(nil, NO, @"Subscriber credential missing");
            return;
            
        } else if (statusCode == 402) {
            NSLog(@"Free user trying to connect to a paid only server");
            if (completion) completion(nil, NO, @"Trying to connect to a premium server as a free user");
            return;
        } else if (statusCode == 200) {
            NSDictionary *dictFromJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(dictFromJSON, YES, nil);
            return;
            
        } else {
            NSLog(@"Unknown error: %ld", statusCode);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown error: %ld", statusCode]);
        }
        
#if GUARDIAN_INTERNAL
        [debugHelper logTimeWithMessage:@"request completion block end"];
#endif
    }];
    [task resume];
}

- (void)registerAndCreateWithSubscriberCredential:(NSString *)subscriberCredential validForDays:(NSInteger)validFor completion:(void (^)(NSDictionary * _Nullable, BOOL, NSString * _Nullable))completion {
    [self registerAndCreateWithHostname:[self baseHostname] subscriberCredential:subscriberCredential validForDays:validFor completion:completion];
}

- (void)invalidateEAPCredentials:(NSString *)eapUsername andAPIToken:(NSString *)apiToken completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if ([self _canMakeApiRequests] == NO) {
        GRDLog(@"Cannot make API requests! Aborting");
        if (completion) completion(NO, @"Cannot make API requests");
        return;
    }
    
    if ([self apiAuthToken] == nil) {
        GRDLog(@"No auth token! Can't invalidate EAP credentials");
        if (completion) completion(NO, @"No auth token. Can't invalidate EAP credentials");
        return;
        
    } else if ([self deviceIdentifier] == nil) {
        GRDLog(@"No device id. Can't invalidate EAP credentials");
        if (completion) completion(NO, @"No device id. Can't invalidate EAP credentials");
        return;
    }
    
    NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken: [self apiAuthToken]};
    
    NSURLRequest *request = [self _requestWithEndpoint:[NSString stringWithFormat:@"/api/v1.2/device/%@/invalidate-credentials", [self deviceIdentifier]] andPostRequestData:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to send EAP credential invalidation request: %@", error);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to send EAP credential invalidation request: %@", [error localizedDescription]]);
            return;
        }
        
        NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500 || statusCode == 410 ||statusCode == 401 || statusCode == 400) {
            NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *errorMessage = [errorDict objectForKey:@"error-message"];
            GRDLog(@"Failed to invalidate EAP credentials: %@", errorMessage);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to invalidate EAP credentials: %@", errorMessage]);
            return;
            
        } else if (statusCode == 200) {
            if (completion) completion(YES, nil);
            return;
            
        } else {
            GRDLog(@"Unknown status code: %ld", statusCode);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to invalidate EAP credentials. Unknown status code: %ld", statusCode]);
        }
    }];
    [task resume];
}

// full (prototype) endpoint: "/vpnsrv/api/device/<device_token>/set-push-token"
// input: "auth-token" and "push-token" (POST format)
- (void)setPushToken:(NSString *)pushToken andDataTrackersEnabled:(BOOL)dataTrackers locationTrackersEnabled:(BOOL)locationTrackers pageHijackersEnabled:(BOOL)pageHijackers mailTrackersEnabled:(BOOL)mailTrackers completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion {
    if ([self _canMakeApiRequests] == NO) {
        NSLog(@"[DEBUG][bindPushToken] cannot make API requests !!! won't continue");
        if (completion){
            completion(false, @"[DEBUG][bindPushToken] cannot make API requests !!! won't continue");
        }
        return;
    }
    
    if ([self apiAuthToken] == nil) {
        NSLog(@"[DEBUG][bindAPNs] no auth token! cannot bind push token.");
        if (completion){
            completion(false, @"[DEBUG][bindAPNs] no auth token! cannot bind push token.");
        }
        return;
    } else if ([self deviceIdentifier] == nil) {
        NSLog(@"[DEBUG][bindAPNs] no device id! cannot bind push token.");
        if (completion){
            completion(false, @"[DEBUG][bindAPNs] no device id! cannot bind push token.");
        }
        return;
    }

    NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken:[self apiAuthToken], @"push-token": pushToken, @"push-data-tracker": [NSNumber numberWithBool:dataTrackers], @"push-location-tracker": [NSNumber numberWithBool:locationTrackers], @"push-page-hijacker": [NSNumber numberWithBool:pageHijackers], @"push-mail-tracker": [NSNumber numberWithBool:mailTrackers]};
    
    NSURLRequest *request = [self _requestWithEndpoint:[NSString stringWithFormat:@"/api/v1.1/device/%@/set-push-token", [self deviceIdentifier]] andPostRequestData:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[DEBUG][bindAPNs] request error = %@", error);
            if (completion){
                completion(false, NSLocalizedString(@"An error occured trying to set the push token", nil));
            }
            return;
            
        } else {
            NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode == 500) {
                NSLog(@"Failed to set push token");
                if (completion){
                    completion(false, NSLocalizedString(@"Failed to set push token - Internal Server Error", nil));
                }
                return;
                
            } else if (statusCode == 401) {
                NSLog(@"Failed to set push token. Auth token missing");
                if (completion){
                    completion(false, NSLocalizedString(@"Failed to set push token - Auth token missing", nil));
                }
                return;
                
            } else if (statusCode == 400) {
                NSLog(@"Failed to set push token. Device ID missing");
                if (completion){
                    completion(false, NSLocalizedString(@"Failed to set push token - Device ID missing", nil));
                }
                return;
                
            } else if (statusCode == 200) {
                if (completion){
                    completion(true, nil);
                }
                return;
                
            } else {
                NSLog(@"Unknown server error. status code: %ld", statusCode);
                if (completion){
                    completion(false, NSLocalizedString(@"Failed to set push token. Unknown error", nil));
                }
                return;
            }
        }
    }];
    
    [task resume];
}

- (void)removePushTokenWithCompletion:(void (^)(BOOL, NSString * _Nullable))completion {
    if ([self _canMakeApiRequests] == NO) {
        NSLog(@"[DEBUG][bindPushToken] cannot make API requests !!! won't continue");
        return;
    }
    
    if ([self apiAuthToken] == nil) {
        NSLog(@"[DEBUG][bindAPNs] no auth token! cannot bind push token.");
        return;
    } else if ([self deviceIdentifier] == nil) {
        NSLog(@"[DEBUG][bindAPNs] no device id! cannot bind push token.");
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.1/device/%@/remove-push-token", [self baseHostname], [self deviceIdentifier]]]];
    [request setHTTPMethod:@"POST"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Failed to remove push token: %@", error);
            completion(false, NSLocalizedString(@"Failed to connect to server to remove push token. Please try again", nil));
            return;
        }
        
        NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            NSLog(@"Failed to remove push token from server - Internal Server Error");
            completion(false, NSLocalizedString(@"Failed to remove push token. Please try again", nil));
            return;
            
        } else if (statusCode == 200) {
            completion(true, nil);
            return;
            
        } else {
            NSLog(@"Failed to remove push token from server. Unknown error code: %ld", statusCode);
            completion(false, NSLocalizedString(@"Failed to remove push token from server. Unknown server error", nil));
            return;
        }
    }];
    
    [task resume];
}

- (void)getEvents:(void(^)(NSDictionary *response, BOOL success, NSString *error))completion {
    if (self.dummyDataForDebugging == NO) {
        if ([self _canMakeApiRequests] == NO) {
            NSLog(@"[DEBUG][getEvents] cannot make API requests !!! won't continue");
            if (completion) completion(nil, NO, @"cant make API requests");
            return;
        }
        
        if (![self deviceIdentifier]) {
            if (completion) completion(nil, NO, @"An error occured!, Missing device id!");
            return;
        }
        
        NSString *apiEndpoint = [NSString stringWithFormat:@"/api/v1.1/device/%@/alerts", [self deviceIdentifier]];
        NSString *finalHost = [NSString stringWithFormat:@"https://%@%@", [self baseHostname], apiEndpoint];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:finalHost]];
        NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken:[self apiAuthToken]};
        [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
        [request setHTTPMethod:@"POST"];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error != nil) {
                GRDLog(@"Couldn't connect to host: %@", [error localizedDescription]);
                if (completion) completion(nil, NO, @"Error connecting to host for getEvents");
                return;
            }
            
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode == 500) {
                GRDLog(@"Internal server error");
                if (completion) completion(nil, NO,@"Internal server error" );
                return;
                
            } else if (statusCode == 410 || statusCode == 401) {
                GRDLog(@"Auth failure. Needs to migrate device");
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kAppNeedsSelfRepair];
                if (completion) completion(nil, NO, @"Authentication failed. Server migration required");
                return;
                
            } else if (statusCode == 400) {
                GRDLog(@"Bad Request");
                if (completion) completion(nil, NO, @"Subscriber credential missing");
                return;
                
            } else if (statusCode == 200) {
                NSError *jsonError = nil;
                NSDictionary *dictFromJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError) {
                    GRDLog(@"Failed to decode JSON with alerts: %@", jsonError);
                    if (completion) completion(nil, NO, @"Failed to decode JSON");
                    
                } else {
                    if (completion) completion(dictFromJSON, YES, nil);
                }
                return;
                
            } else {
                GRDLog(@"Unknown error: %ld", statusCode);
                if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown error: %ld", statusCode]);
            }
        }];
        [task resume];
        
    } else {
        // Returning dummy data so that we can debug easily in the simulator
        completion([NSDictionary dictionaryWithObject:[self _fakeAlertsArray] forKey:@"alerts"], YES, nil);
    }
}

- (NSArray *)_fakeAlertsArray {
    NSString *curDateStr = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
    NSMutableArray *fakeAlerts = [NSMutableArray array];
   
    NSInteger i = 0;
    for (i = 0; i < 1000; i++){
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"privacy-tracker-app",
                                @"host":@"analytics.localytics.com",
                                @"message":@"Prevented 'Localytics' from obtaining unknown data from device. Prevented 'Localytics' from obtaining unknown data from device Prevented 'Localytics' from obtaining unknown data from device Prevented 'Localytics' from obtaining unknown",
                                @"timestamp":curDateStr,
                                @"title":@"Data Tracker",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
        
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"privacy-tracker-app-location",
                                @"host":@"api.beaconsinspace.com",
                                @"message":@"Prevented 'Beacons In Space' from obtaining unknown data from device",
                                @"timestamp":curDateStr,
                                @"title":@"Location Tracker",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
        
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"privacy-tracker-mail",
                                @"host":@"api.phishy-mcphishface-thisisanexampleofalonghostname.com",
                                @"message":@"Prevented 'Phishy McPhishface' from obtaining unknown data from device",
                                @"timestamp":curDateStr,
                                @"title":@"Mail Tracker",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
        
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"encryption-allows-invalid-https",
                                @"host":@"facebook.com",
                                @"message":@"Prevented 'Facebook', you're welcome",
                                @"timestamp":curDateStr,
                                @"title":@"Blocked MITM",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
        
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"ads/aggressive",
                                @"host":@"google.com",
                                @"message":@"Prevented Google from forcing shit you don't need down your throat",
                                @"timestamp":curDateStr,
                                @"title":@"Page Hijacker",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
    }
    
    return [NSArray arrayWithArray:fakeAlerts];
}

- (void)setAlertsDownloadTimestampWithCompletion:(void (^)(BOOL, NSString * _Nullable))completion {
    if ([self _canMakeApiRequests] == NO) {
        GRDLog(@"Cannot make API requests !!! won't continue");
        if (completion) completion(NO, @"cant make API requests");
        return;
    }
    
    if (![self deviceIdentifier]) {
        GRDLog(@"Missing device id. Can't send API requests");
        if (completion) completion(NO, @"Missing device id. Can't send API requests");
        return;
    }
    
    NSError *jsonEncodeErr;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{kKeychainStr_APIAuthToken: [self apiAuthToken]} options:0 error:&jsonEncodeErr];
    if (jsonEncodeErr != nil) {
        GRDLog(@"Failed to encode JSON: %@", jsonEncodeErr);
        if (completion) completion(NO, NSLocalizedString(@"Failed to encode JSON", nil));
        return;
    }
    
    NSMutableURLRequest *request = [self _requestWithEndpoint:[NSString stringWithFormat:@"/api/v1.2/device/%@/set-alerts-download-timestamp", [self deviceIdentifier]] andPostRequestData:jsonData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to send API request: %@", error);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to send API request: %@", [error localizedDescription]]);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500 || statusCode == 401 || statusCode == 400) {
            NSDictionary *errorJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *errorTitle = [errorJSON objectForKey:@"error-title"];
            NSString *errorMessage = [errorJSON objectForKey:@"error-message"];
            if (errorTitle == nil && errorMessage == nil) {
                GRDLog(@"No error message returned for status code: %ld", statusCode);
                if (completion) completion(NO, [NSString stringWithFormat:@"Request failed but no error message was returned for status code: %ld", statusCode]);
                return;
            }
            
        } else if (statusCode == 200) {
            if (completion) completion(YES, nil);
            return;
            
        } else {
            GRDLog(@"Request failed with unknown status code: %ld", statusCode);
            if (completion) completion(NO, [NSString stringWithFormat:@"Request failed with unknown status code: %ld", statusCode]);
        }
    }];
    [task resume];
}

- (void)getAlertTotals:(void (^)(NSDictionary * _Nullable, BOOL, NSString * _Nullable))completion {
    if ([self _canMakeApiRequests] == NO) {
        GRDLog(@"Cannot make API requests !!! won't continue");
        if (completion) completion(nil, NO, @"cant make API requests");
        return;
    }
    
    if (![self deviceIdentifier]) {
        if (completion) completion(nil, NO, @"An error occured!, Missing device id!");
        return;
    }
    
    NSString *apiEndpoint = [NSString stringWithFormat:@"/api/v1.1/device/%@/alert-totals", [self deviceIdentifier]];
    NSString *finalHost = [NSString stringWithFormat:@"https://%@%@", [self baseHostname], apiEndpoint];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:finalHost]];
    NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken:[self apiAuthToken]};
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
    [request setHTTPMethod:@"POST"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to send request: %@", [error localizedDescription]);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            GRDLog(@"Failed to get alert totals: Internal Server Error!");
            if (completion) completion(nil, NO, @"Failed to get alert totals. Internal Server Error");
            return;
            
        } else if (statusCode == 400) {
            GRDLog(@"Failed to get alert totals: Bad request");
            if (completion) completion(nil, NO, @"Failed to get alert totals: Malformed request!");
            return;
            
        } else if (statusCode == 200) {
            NSDictionary *alertTotals = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(alertTotals, YES, nil);
            return;
            
        } else {
            GRDLog(@"Unknown server error. Status code: %ld", statusCode);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown server error. Status code: %ld", statusCode]);
        }
    }];
    [task resume];
}

@end
