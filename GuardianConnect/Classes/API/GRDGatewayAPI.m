//
//  GRDGatewayAPI.m
//  Guardian
//
//  Copyright © 2017 Sudo Security Group Inc. All rights reserved.
//

#import "GRDGatewayAPI.h"
#import "GRDVPNHelper.h"

@implementation GRDGatewayAPI

#pragma mark - Convenience helpers

- (void)getServerStatusForHostname:(NSString *)hostname completion:(void (^ _Nullable)(NSError * _Nullable))completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/server-status", hostname]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:10];
    [request setHTTPMethod:@"GET"];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:10];
	[sessionConf setTimeoutIntervalForResource:10];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error != nil) {
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"SGW server status response not 200 Ok: %@", apiErr]]);
			return;
		}
		
		completion(nil);
    }];
    
    [task resume];
}

# pragma mark - Device Management

- (void)registerDeviceCredentialForTransportProtocol:(NSString *)transportProtocol hostname:(NSString *)hostname subscriberCredential:(NSString *)subscriberCredential transportOptions:(NSDictionary *)options deviceFilterConfigs:(NSDictionary *)deviceFilterConfigs clientRules:(NSArray *)clientRules multihopExitRegion:(NSString *)multihopExitRegion completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSString *url = [NSString stringWithFormat:@"https://%@/api/v1.4/device-credentials", hostname];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
	[request setHTTPMethod:@"POST"];
	
	NSMutableDictionary *requestBody = [[NSMutableDictionary alloc] initWithDictionary:options];
	[requestBody setObject:subscriberCredential forKey:@"subscriber-credential"];
	[requestBody setObject:transportProtocol forKey:@"transport-protocol"];
	
	if (deviceFilterConfigs != nil) {
		[requestBody setObject:deviceFilterConfigs forKey:@"device-filter-config"];
	}
	
	if (clientRules != nil) {
		[requestBody setObject:clientRules forKey:@"client-rules"];
	}
	
	if (multihopExitRegion != nil) {
		[requestBody setObject:multihopExitRegion forKey:@"multihop-exit-region"];
	}
	
	NSError *jsonError;
	[request setHTTPBody:[NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError]];
	if (jsonError != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON encode request body: %@", [jsonError localizedDescription]]]);
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
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request to register device credential: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to register device credential: %@", apiErr]]);
			return;
		}
		
		NSError *jsonError;
		NSDictionary *credentialData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON decode API response data: %@", [jsonError localizedDescription]]]);
			return;
		}
		
		if (completion) completion(credentialData, nil);
	}];
	[task resume];
}

- (void)verifyCredentialsForClientId:(NSString *)clientId withAPIToken:(NSString *)apiToken hostname:(NSString *)hostname subscriberCredential:(NSString *)subCred completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/verify-credentials", hostname, clientId]]];
	[request setValue:apiToken forHTTPHeaderField:kGRDAPIAuthTokenHTTPHeader];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setTimeoutInterval:30];
    
    NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
			if (completion) completion(YES, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
            return;
        }
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to verify SGW credentials: %@", apiErr]]);
			return;
		}
		
		if (completion) completion(YES, nil);
    }];
    [task resume];
}

- (void)invalidateCredentialsForClientId:(NSString *)clientId apiToken:(NSString *)apiToken hostname:(NSString *)hostname subscriberCredential:(NSString *)subCred completion:(void (^)(NSError * _Nullable))completion {    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/invalidate-credentials", hostname, clientId]]];
    
    NSError *jsonErr;
    NSData *requestBody = [NSJSONSerialization dataWithJSONObject:@{kKeychainStr_APIAuthToken: apiToken, kKeychainStr_SubscriberCredential: subCred} options:0 error:&jsonErr];
    if (jsonErr != nil) {
        if (completion) completion(jsonErr);
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
			GRDErrorLogg(@"Failed to send EAP credential invalidation request: %@", [error localizedDescription]);
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send EAP credential invalidation request: %@", [error localizedDescription]]]);
            return;
        }
        
        NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to invalidate VPN credentials: %@", apiErr]]);
			return;
		}
		
		if (completion) completion(nil);
    }];
    [task resume];
}


# pragma mark - Alerts

- (void)getEventsForClientId:(NSString *)clientId apiAuthToken:(NSString *)apiAuthToken hostname:(NSString *)hostname completion:(void(^)(NSArray *alerts, NSError *_Nullable error))completion {
	if ([[GRDVPNHelper sharedInstance] dummyDataForDebugging]) {
		// Returning dummy data so that we can debug easily in the simulator
		completion([self _fakeAlertsArray], nil);
		return;
	}

	NSString *apiEndpoint = [NSString stringWithFormat:@"/api/v1.4/device/%@/alerts", clientId];
	NSString *finalHost = [NSString stringWithFormat:@"https://%@%@", hostname, apiEndpoint];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:finalHost]];
	[request setValue:apiAuthToken forHTTPHeaderField:kGRDAPIAuthTokenHTTPHeader];
	[request setTimeoutInterval:45];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:45];
	[sessionConf setTimeoutIntervalForResource:45];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to fetch alerts: %@", apiErr]]);
			return;
		}
		
		NSError *jsonError = nil;
		NSArray *alertsDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON decode alerts response data: %@", [jsonError localizedDescription]]]);
			return;
		}
		
		if (completion) completion(alertsDict, nil);
	}];
	[task resume];
}

- (NSArray *)_fakeAlertsArray {
    NSString *curDateStr = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
    NSMutableArray *fakeAlerts = [NSMutableArray array];
   
    NSInteger i = 0;
    for (i = 0; i < 1000; i++) {
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


# pragma mark - APNS

- (void)setPushNotificationServiceTokenWithData:(NSDictionary *)tokenData hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSError * _Nullable))completion {
	NSMutableDictionary *requestData = [NSMutableDictionary dictionaryWithDictionary:tokenData];
	[requestData setValue:apiAuthToken forKey:kKeychainStr_APIAuthToken];
//	NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken:[mainCredentials apiAuthToken], @"push-token": pushToken, @"push-data-tracker": [NSNumber numberWithBool:dataTrackers], @"push-location-tracker": [NSNumber numberWithBool:locationTrackers], @"push-page-hijacker": [NSNumber numberWithBool:pageHijackers], @"push-mail-tracker": [NSNumber numberWithBool:mailTrackers]};
	
	NSError *jsonErr;
	NSData *requestBody = [NSJSONSerialization dataWithJSONObject:requestData options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/set-push-token", hostname, deviceId]]];
	[request setHTTPMethod:@"POST"];
	[request setTimeoutInterval:30];
	[request setHTTPBody:requestBody];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to set APNS token: %@", apiErr]]);
			return;
		}
		
		if (completion) completion(nil);
	}];
	
	[task resume];
}

- (void)removePushNotificationServiceTokenForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSError * _Nullable))completion {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/remove-push-token", hostname, deviceId]]];
	[request setValue:apiAuthToken forHTTPHeaderField:kGRDAPIAuthTokenHTTPHeader];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to remove the push notification service token: %@", apiErr]]);
			return;
		}
		
		completion(nil);
	}];
	
	[task resume];
}


# pragma mark - Device Filter Configs

- (void)getDeviceFitlerConfigsForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/config/filters", hostname, deviceId]]];
	[request setValue:apiAuthToken forHTTPHeaderField:kGRDAPIAuthTokenHTTPHeader];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to fetch device filter configs: %@", apiErr]]);
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

- (void)setDeviceFilterConfigs:(NSDictionary *)configFilters hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiToken:(NSString *)apiToken completion:(void (^)(NSError * _Nullable))completion {
	NSMutableDictionary *requestData = [NSMutableDictionary dictionaryWithDictionary:configFilters];
	[requestData setValue:apiToken forKey:kKeychainStr_APIAuthToken];
	NSError *jsonErr;
	NSData *requestBody = [NSJSONSerialization dataWithJSONObject:requestData options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON encode request data: %@", jsonErr]]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/config/filters", hostname, deviceId]]];
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
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to set device filter configs: %@", apiErr]]);
			return;
		}
		
		if (completion) completion(nil);
	}];
	[task resume];
}

# pragma mark - Client Rules

- (void)getClientRulesForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSArray * _Nullable, NSError * _Nullable))completion {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/config/rules", hostname, deviceId]]];
	[request setValue:apiAuthToken forHTTPHeaderField:kGRDAPIAuthTokenHTTPHeader];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to fetch client rules: %@", apiErr]]);
			return;
		}
		
		NSError *jsonError;
		NSArray *clientRulesRaw = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError != nil) {
			if (completion) completion(nil, jsonError);
			return;
		}
		if (completion) completion(clientRulesRaw, nil);
	}];
	[task resume];
}

- (void)setClientRules:(NSArray *)rulesRaw hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSArray * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestBody = [NSJSONSerialization dataWithJSONObject:@{@"client-rules": rulesRaw, kKeychainStr_APIAuthToken: apiAuthToken} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON encode request data: %@", jsonErr]]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/config/rules", hostname, deviceId]]];
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
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to set client rules: %@", apiErr]]);
			return;
		}
		
		NSError *jsonErr;
		NSArray *clientRulesRaw = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON decode response data: %@", jsonErr]]);
			return;
		}
		
		if (completion) completion(clientRulesRaw, nil);
	}];
	[task resume];
}

# pragma mark - Mutlihop

- (void)getMultihopRegionConfigsForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/config/multihop", hostname, deviceId]]];
	[request setValue:apiAuthToken forHTTPHeaderField:kGRDAPIAuthTokenHTTPHeader];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to fetch multihop region config: %@", apiErr]]);
			return;
		}
		
		NSError *jsonError;
		NSDictionary *multihopRegionConfigRaw = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError != nil) {
			if (completion) completion(nil, jsonError);
			return;
		}
		if (completion) completion(multihopRegionConfigRaw, nil);
	}];
	[task resume];
}

- (void)setMultihopExitRegion:(NSString *)exitRegion hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestBody = [NSJSONSerialization dataWithJSONObject:@{@"multihop-exit-region": exitRegion, kKeychainStr_APIAuthToken: apiAuthToken} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON encode request data: %@", jsonErr]]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.4/device/%@/config/multihop", hostname, deviceId]]];
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
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", error]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to set multihop exit region: %@", apiErr]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *multihopExitRegionsRaw = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON decode response data: %@", jsonErr]]);
			return;
		}
		
		if (completion) completion(multihopExitRegionsRaw, nil);
	}];
	[task resume];
}

@end
