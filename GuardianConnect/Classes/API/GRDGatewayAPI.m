//
//  GRDGatewayAPI.m
//  Guardian
//
//  Copyright © 2017 Sudo Security Group Inc. All rights reserved.
//

#import "GRDGatewayAPI.h"
#import "GRDVPNHelper.h"

#import <NetworkExtension/NetworkExtension.h>

@implementation GRDGatewayAPI

- (NSString *)apiHostname {
    return [[[GRDVPNHelper sharedInstance] mainCredential] hostname];
}

- (NSString *)apiAuthToken {
    return [[[GRDVPNHelper sharedInstance] mainCredential] apiAuthToken];
}

- (NSString *)deviceIdentifier {
    NSString *deviceId;
    GRDCredential *mainCreds = [[GRDVPNHelper sharedInstance] mainCredential];
    if (mainCreds.transportProtocol == TransportIKEv2) {
        deviceId = [mainCreds username];
        
    } else if (mainCreds.transportProtocol == TransportWireGuard) {
        deviceId = [mainCreds clientId];
    }
    
    return deviceId;
}

- (BOOL)isVPNConnected {
    return ([[[NEVPNManager sharedManager] connection] status] == NEVPNStatusConnected);
}

- (NSString *)baseHostname {
    GRDCredential *main = [[GRDVPNHelper sharedInstance] mainCredential];
    if (main) {
        return [main hostname];
    }
	
	return nil;
}

- (BOOL)_canMakeApiRequests {
    if ([self baseHostname] == nil) {
        return NO;
    } else {
        return YES;
    }
}


#pragma mark - Misc

- (NSMutableURLRequest *)_requestWithEndpoint:(NSString *_Nonnull)apiEndpoint andPostRequestData:(NSData *_Nonnull)postRequestDat {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", [self baseHostname], apiEndpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
	
	[request setHTTPMethod:@"POST"];
    [request setHTTPBody:postRequestDat];
    
    return request;
}


- (void)getServerStatusWithCompletion:(void (^ _Nullable)(NSString * _Nullable))completion {
    if ([self _canMakeApiRequests] == NO) {
        GRDErrorLog(@"Cannot make API requests !!! won't continue");
        if (completion) completion(@"Failed to send API request: API target hostname missing");
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/vpnsrv/api/server-status", [self baseHostname]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setTimeoutInterval:10];
    [request setHTTPMethod:@"GET"];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:10];
	[sessionConf setTimeoutIntervalForResource:10];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error != nil) {
			if (completion) completion([NSString stringWithFormat:@"Failed to check VPN server status: %@", [error localizedDescription]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			if (completion) completion([NSString stringWithFormat:@"VPN server status not 200 Ok. Received status code instead: %ld", statusCode]);
			return;
		}
		
		completion(nil);
    }];
    
    [task resume];
}

# pragma mark - v1.3 APIs

- (void)registerDeviceForTransportProtocol:(NSString *)transportProtocol hostname:(NSString *)hostname subscriberCredential:(NSString *)subscriberCredential validForDays:(NSInteger)validFor transportOptions:(NSDictionary *)options completion:(void (^)(NSDictionary * _Nullable, BOOL, NSString * _Nullable))completion {
	NSString *url = [NSString stringWithFormat:@"https://%@/api/v1.3/device", hostname];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
	[request setHTTPMethod:@"POST"];
	
	NSMutableDictionary *requestBody = [[NSMutableDictionary alloc] initWithDictionary:options];
	[requestBody setObject:subscriberCredential forKey:@"subscriber-credential"];
	[requestBody setObject:transportProtocol forKey:@"transport-protocol"];
	
	NSError *jsonError;
	[request setHTTPBody:[NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError]];
	if (jsonError != nil) {
		GRDErrorLogg(@"Failed to encode request body: %@", jsonError);
		if (completion) completion(nil, NO, @"Failed to encode request body");
		return;
	}
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			GRDErrorLogg(@"Failed to send request: %@", error);
			if (completion) completion(nil, NO, @"Failed to send request");
			return;
		}
		
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode == 200) {
			NSError *jsonError;
			NSDictionary *apiResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
			if (jsonError != nil) {
				GRDErrorLogg(@"Failed to decode API response: %@", jsonError);
				if (completion) completion(nil, NO, @"Failed to decode API response");
				return;
			}
			
			if (completion) completion(apiResponse, YES, nil);
			return;
			
		} else {
			NSError *jsonError;
			NSDictionary *errorJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
			if (jsonError != nil) {
				GRDErrorLogg(@"Failed to decode API error message: %@", jsonError);
				if (completion) completion(nil, NO, @"Failed to decode API error message");
				return;
			}
			
			NSString *errorTitle = errorJSON[@"error-title"];
			NSString *errorMessage = errorJSON[@"error-message"];
			
			GRDErrorLogg(@"Unknown error: %@ %@. Status code: %ld", errorTitle, errorMessage, statusCode);
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", errorMessage, statusCode]);
		}
	}];
	[task resume];
}

- (void)verifyCredentialsForClientId:(NSString *)clientId withAPIToken:(NSString *)apiToken hostname:(NSString *)hostname subscriberCredential:(NSString *)subCred completion:(void (^)(BOOL, BOOL, NSString * _Nullable))completion {
    if (clientId == nil || apiToken == nil || subCred == nil || hostname == nil) {
        if (completion) completion(NO, NO, @"nil variable detected. Aborting");
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/device/%@/verify-credentials", hostname, clientId]]];
    
    NSError *encodingError;
    NSData *jsonBody = [NSJSONSerialization dataWithJSONObject:@{kKeychainStr_APIAuthToken: apiToken, kKeychainStr_SubscriberCredential: subCred} options:0 error:&encodingError];
    if (encodingError != nil) {
        GRDErrorLogg(@"Failed to encode JSON body: %@", encodingError);
        if (completion) completion(NO, NO, @"Failed to encode JSON body");
        return;
    }
    
    [request setHTTPBody:jsonBody];
    [request setHTTPMethod:@"POST"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setTimeoutInterval:30];
    
    NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDErrorLogg(@"Failed to send request: %@", error);
            if (completion) completion(NO, NO, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 200) {
            if (completion) completion(YES, YES, nil);
            return;
        
        } else {
            NSError *decodeError;
            NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeError];
            if (decodeError != nil) {
                GRDErrorLogg(@"Failed to decode error JSON from VPN node: %@", decodeError);
                if (completion) completion(YES, NO, @"Failed to deocde error JSON from VPN node");
                return;
            }
            
            NSString *errorMessage = [errorDict objectForKey:@"error-message"];
            GRDErrorLogg(@"Request failed. Credentials are no longer valid! Server status code: %ld - error message: %@", statusCode, errorMessage);
            if (completion) completion(YES, NO, @"Credentials invalid. Client needs to migrate!");
            return;
        }
    }];
    [task resume];
}

- (void)invalidateCredentialsForClientId:(NSString *)clientId apiToken:(NSString *)apiToken hostname:(NSString *)hostname subscriberCredential:(NSString *)subCred completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if (clientId == nil || apiToken == nil || hostname == nil || subCred == nil) {
        GRDErrorLogg(@"nil value detected. Unable to send request to invalidate the device's credentials");
        if (completion) completion(NO, @"nil value detected. Unable to send request to invalidate the device's credentials");
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/device/%@/invalidate-credentials", hostname, clientId]]];
    
    NSError *jsonErr;
    NSData *requestBody = [NSJSONSerialization dataWithJSONObject:@{kKeychainStr_APIAuthToken: apiToken, kKeychainStr_SubscriberCredential: subCred} options:0 error:&jsonErr];
    if (jsonErr != nil) {
        GRDErrorLogg(@"Failed to encode request JSON: %@", jsonErr);
        if (completion) completion(NO, [NSString stringWithFormat:@"Failed to encode request JSON body: %@", jsonErr]);
        return;
    }
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestBody];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
			GRDErrorLogg(@"Failed to send EAP credential invalidation request: %@", error);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to send EAP credential invalidation request: %@", [error localizedDescription]]);
            return;
        }
        
        NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 200) {
            if (completion) completion(YES, nil);
            return;
        
        } else {
            NSError *decodeError;
            NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeError];
            if (decodeError != nil) {
                GRDErrorLogg(@"Failed to decode error JSON from VPN node: %@", decodeError);
                if (completion) completion(NO, @"Failed to deocde error JSON from VPN node");
                return;
            }
            
            NSString *errorMessage = errorDict[@"error-message"];
			if (errorMessage == nil) {
				if (completion) completion(NO, @"Failed to invalidate the device's credentials. API response returned no error message");
				return;
			}
			
            GRDErrorLogg(@"Failed to invalidate device's credentials. Status code: %ld - error message: %@", statusCode, errorMessage);
            if (completion) completion(NO, @"Failed to invalidate the device's credentials");
            return;
        }
    }];
    [task resume];
}


# pragma mark - Alerts

- (void)getEvents:(void(^)(NSDictionary *response, BOOL success, NSString *_Nullable error))completion {
    if ([GRDVPNHelper sharedInstance].dummyDataForDebugging == NO) {
        if ([self _canMakeApiRequests] == NO) {
			GRDLog(@"Cannot make API requests !!! won't continue");
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
        NSString *apiAuthToken = [self apiAuthToken];
        if (apiAuthToken == nil || [apiAuthToken isEqualToString:@""]) {
            if (completion) completion(nil, NO, @"API auth token missing!");
            return;
        }
        
        NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken: apiAuthToken};
        [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
        [request setHTTPMethod:@"POST"];
		[request setTimeoutInterval:45];
		
		NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
		[sessionConf setWaitsForConnectivity:YES];
		[sessionConf setTimeoutIntervalForRequest:45];
		[sessionConf setTimeoutIntervalForResource:45];
		NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error != nil) {
                GRDLog(@"Couldn't connect to host: %@", [error localizedDescription]);
                if (completion) completion(nil, NO, @"Error connecting to host for getEvents");
                return;
            }
            
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode == 500) {
                GRDLog(@"Internal server error");
                if (completion) completion(nil, NO, @"Internal server error" );
                return;
                
            } else if (statusCode == 410 || statusCode == 401) {
                GRDLog(@"Auth failure. Needs to migrate device");
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
                                @"host":@"pippio.com",
                                @"message":@"'Arbor (pippio.com)' is known to collect device information, occasionally including location data",
                                @"timestamp":curDateStr,
                                @"title":@"Data Tracker",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
        
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"privacy-tracker-app-location",
                                @"host":@"v1.blueberry.cloud.databerries.com",
                                @"message":@"'Teemo' is known to collect GPS location information",
                                @"timestamp":curDateStr,
                                @"title":@"Location Tracker",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
        
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"privacy-tracker-mail",
                                @"host":@"www.responsys.net",
                                @"message":@"'Oracle Responsys' is known to track your receipt of e-mail messages",
                                @"timestamp":curDateStr,
                                @"title":@"Mail Tracker",
                                @"uuid":[[NSUUID UUID] UUIDString] }];
        
        
        [fakeAlerts addObject:@{@"action":@"drop",
                                @"category":@"ads/aggressive",
                                @"host":@"ad.turn.com",
                                @"message":@"'ad.turn.com' from causing potential forced ad redirect",
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
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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


# pragma mark - APNS

// full (prototype) endpoint: "/vpnsrv/api/device/<device_token>/set-push-token"
// input: "auth-token" and "push-token" (POST format)
- (void)setPushToken:(NSString *_Nonnull)pushToken andDataTrackersEnabled:(BOOL)dataTrackers locationTrackersEnabled:(BOOL)locationTrackers pageHijackersEnabled:(BOOL)pageHijackers mailTrackersEnabled:(BOOL)mailTrackers completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion {
	if ([self _canMakeApiRequests] == NO) {
		GRDLog(@"Cannot make API requests !!! won't continue");
		if (completion) {
			completion(false, @"Cannot make API requests !!! won't continue");
		}
		return;
	}
	
	if ([self apiAuthToken] == nil) {
		GRDLog(@"No auth token! cannot bind push token.");
		if (completion){
			completion(false, @"No auth token! cannot bind push token.");
		}
		return;
		
	} else if ([self deviceIdentifier] == nil) {
		GRDLog(@"No device id! cannot bind push token.");
		if (completion){
			completion(false, @"No device id! cannot bind push token.");
		}
		return;
	}

	NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken:[self apiAuthToken], @"push-token": pushToken, @"push-data-tracker": [NSNumber numberWithBool:dataTrackers], @"push-location-tracker": [NSNumber numberWithBool:locationTrackers], @"push-page-hijacker": [NSNumber numberWithBool:pageHijackers], @"push-mail-tracker": [NSNumber numberWithBool:mailTrackers]};
	
	NSMutableURLRequest *request = [self _requestWithEndpoint:[NSString stringWithFormat:@"/api/v1.1/device/%@/set-push-token", [self deviceIdentifier]] andPostRequestData:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			GRDLog(@"Request error = %@", error);
			if (completion){
				completion(false, NSLocalizedString(@"An error occured trying to set the push token", nil));
			}
			return;
			
		} else {
			NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
			if (statusCode == 500) {
				GRDLog(@"Failed to set push token");
				if (completion){
					completion(false, NSLocalizedString(@"Failed to set push token - Internal Server Error", nil));
				}
				return;
				
			} else if (statusCode == 401) {
				GRDLog(@"Failed to set push token. Auth token missing");
				if (completion){
					completion(false, NSLocalizedString(@"Failed to set push token - Auth token missing", nil));
				}
				return;
				
			} else if (statusCode == 400) {
				GRDLog(@"Failed to set push token. Device ID missing");
				if (completion){
					completion(false, NSLocalizedString(@"Failed to set push token - Device ID missing", nil));
				}
				return;
				
			} else if (statusCode == 200) {
				if (completion) {
					completion(true, nil);
				}
				return;
				
			} else {
				GRDLog(@"Unknown server error. status code: %ld", statusCode);
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
		GRDLog(@"Cannot make API requests !!! won't continue");
		return;
	}
	
	if ([self apiAuthToken] == nil) {
		GRDLog(@"No auth token! cannot bind push token.");
		return;
		
	} else if ([self deviceIdentifier] == nil) {
		GRDLog(@"No device id! cannot bind push token.");
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.1/device/%@/remove-push-token", [self baseHostname], [self deviceIdentifier]]]];
	[request setHTTPMethod:@"POST"];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			GRDLog(@"Failed to remove push token: %@", error);
			completion(false, NSLocalizedString(@"Failed to connect to server to remove push token. Please try again", nil));
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode == 500) {
			GRDLog(@"Failed to remove push token from server - Internal Server Error");
			completion(false, NSLocalizedString(@"Failed to remove push token. Please try again", nil));
			return;
			
		} else if (statusCode == 200) {
			completion(true, nil);
			return;
			
		} else {
			GRDLog(@"Failed to remove push token from server. Unknown error code: %ld", statusCode);
			completion(false, NSLocalizedString(@"Failed to remove push token from server. Unknown server error", nil));
			return;
		}
	}];
	
	[task resume];
}


# pragma mark - Device Filter Configs

- (void)getDeviceFitlerConfigsForDeviceId:(NSString *)deviceId apiToken:(NSString *)apiToken completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	if ([self baseHostname] == nil || [[self baseHostname] isEqualToString:@""]) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Cannot make API requests !!! won't continue"]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/device/%@/config/filters", [self baseHostname], deviceId]]];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, error);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Failed to register new Connect subscriber. Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonError;
		NSDictionary *deviceConfigFilters = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError != nil) {
			if (completion) completion(nil, jsonError);
			return;
		}
		if (completion) completion(deviceConfigFilters, nil);
	}];
	[task resume];
}

- (void)setDeviceFilterConfigsForDeviceId:(NSString *)deviceId apiToken:(NSString *)apiToken deviceConfigFilters:(NSDictionary *)configFilters completion:(void (^)(NSError * _Nullable))completion {
	if ([self baseHostname] == nil || [[self baseHostname] isEqualToString:@""]) {
		GRDLog(@"Cannot make API requests !!! won't continue");
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Cannot make API requests !!! won't continue"]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/device/%@/config/filters", [self baseHostname], deviceId]]];
	[request setHTTPMethod:@"POST"];
	
	NSMutableDictionary *jsonBody = [NSMutableDictionary dictionaryWithDictionary:configFilters];
	[jsonBody setValue:apiToken forKey:kKeychainStr_APIAuthToken];
	[request setHTTPBody:[NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:nil]];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(error);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];			
			GRDErrorLogg(@"Failed to register new Connect subscriber. Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		if (completion) completion(nil);
	}];
	[task resume];
}

@end
