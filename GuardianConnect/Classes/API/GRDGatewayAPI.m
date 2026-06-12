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
		if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to JSON encode request body: %@", [jsonError localizedDescription]]);
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
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to send request to register device: %@", [error localizedDescription]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to register device: %@", apiErr]);
			return;
		}
		
		NSError *jsonError;
		NSDictionary *sgwCredential = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError != nil) {
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to JSON decode API response data: %@", [jsonError localizedDescription]]);
			return;
		}
		
		if (completion) completion(sgwCredential, YES, nil);
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
            if (completion) completion(NO, NO, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]);
            return;
        }
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(YES, NO, [NSString stringWithFormat:@"Failed to validate VPN credentials: %@", apiErr]);
			return;
		}
		
		if (completion) completion(YES, YES, nil);
    }];
    [task resume];
}

- (void)invalidateCredentialsForClientId:(NSString *)clientId apiToken:(NSString *)apiToken hostname:(NSString *)hostname subscriberCredential:(NSString *)subCred completion:(void (^)(NSError * _Nullable))completion {
    if (clientId == nil || apiToken == nil || hostname == nil || subCred == nil) {
        GRDErrorLogg(@"nil value detected. Unable to send request to invalidate the device's credentials");
        if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"VPN credential not invalidated. Credential specific value missing to complete the request"]);
        return;
    }
	
	GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
	if (![mainCredentials canSendSGWAPIRequests]) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"SGW credential is missing a hostname, cannot send API requests!"]]);
		return;
	}
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/device/%@/invalidate-credentials", hostname, clientId]]];
    
    NSError *jsonErr;
    NSData *requestBody = [NSJSONSerialization dataWithJSONObject:@{kKeychainStr_APIAuthToken: apiToken, kKeychainStr_SubscriberCredential: subCred} options:0 error:&jsonErr];
    if (jsonErr != nil) {
        GRDErrorLogg(@"Failed to encode request JSON: %@", [jsonErr localizedDescription]);
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
            if (completion) completion(error);
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

- (void)getEvents:(void(^)(NSArray *alerts, BOOL success, NSString *_Nullable error))completion {
	if ([[GRDVPNHelper sharedInstance] dummyDataForDebugging]) {
		// Returning dummy data so that we can debug easily in the simulator
		completion([self _fakeAlertsArray], YES, nil);
		return;
	}
	
	GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
	if (![mainCredentials canSendSGWAPIRequests]) {
		if (completion) completion(nil, NO, @"SGW credential is missing a hostname, cannot send API requests!");
		return;
	}

	NSString *apiEndpoint = [NSString stringWithFormat:@"/api/v1.2/device/%@/alerts", [mainCredentials clientId]];
	NSString *finalHost = [NSString stringWithFormat:@"https://%@%@", [mainCredentials hostname], apiEndpoint];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:finalHost]];
	
	NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken: [mainCredentials apiAuthToken]};
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
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to connect to SGW host while fetching alerts: %@", [error localizedDescription]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to fetch alerts: %@", apiErr]);
			return;
		}
		
		NSError *jsonError = nil;
		NSArray *alertsDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		if (jsonError) {
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to JSON decode alerts response data: %@", [jsonError localizedDescription]]);
			return;
		}
		
		if (completion) completion(alertsDict, YES, nil);
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

- (void)setPushToken:(NSString *_Nonnull)pushToken andDataTrackersEnabled:(BOOL)dataTrackers locationTrackersEnabled:(BOOL)locationTrackers pageHijackersEnabled:(BOOL)pageHijackers mailTrackersEnabled:(BOOL)mailTrackers completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion {
	GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
	if (![mainCredentials canSendSGWAPIRequests]) {
		if (completion) completion(NO, @"SGW credential is missing a hostname, cannot send API requests!");
		return;
	}

	NSDictionary *jsonDict = @{kKeychainStr_APIAuthToken:[mainCredentials apiAuthToken], @"push-token": pushToken, @"push-data-tracker": [NSNumber numberWithBool:dataTrackers], @"push-location-tracker": [NSNumber numberWithBool:locationTrackers], @"push-page-hijacker": [NSNumber numberWithBool:pageHijackers], @"push-mail-tracker": [NSNumber numberWithBool:mailTrackers]};
	
	NSError *jsonErr;
	NSData *requestBody = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(NO, [NSString stringWithFormat:@"Failed to JSON encode request data: %@", [jsonErr localizedDescription]]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"/api/v1.1/device/%@/set-push-token", [mainCredentials clientId]]]];
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
			GRDLog(@"Request error = %@", error);
			if (completion) completion(NO, NSLocalizedString(@"An error occured trying to set the push token", nil));
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(NO, [NSString stringWithFormat:@"Failed to set the APNS token: %@", apiErr]);
			return;
		}
		
		if (completion) completion(YES, nil);
	}];
	
	[task resume];
}

- (void)removePushTokenWithCompletion:(void (^)(BOOL, NSString * _Nullable))completion {
	GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
	if (![mainCredentials canSendSGWAPIRequests]) {
		if (completion) completion(NO, @"SGW credential is missing a hostname, cannot send API requests!");
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.1/device/%@/remove-push-token", [mainCredentials hostname], [mainCredentials clientId]]]];
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
			completion(NO, NSLocalizedString(@"Failed to connect to server to remove the push token", nil));
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(NO, [NSString stringWithFormat:@"Failed to remove the APNS token: %@", apiErr]);
			return;
		}
		
		completion(YES, nil);
	}];
	
	[task resume];
}


# pragma mark - Device Filter Configs

- (void)getDeviceFitlerConfigsForDeviceId:(NSString *)deviceId apiToken:(NSString *)apiToken completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
	if (![mainCredentials canSendSGWAPIRequests]) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"SGW credential is missing a hostname, cannot send API requests!"]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/device/%@/config/filters", [mainCredentials hostname], deviceId]]];
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

- (void)setDeviceFilterConfigsForDeviceId:(NSString *)deviceId apiToken:(NSString *)apiToken deviceConfigFilters:(NSDictionary *)configFilters completion:(void (^)(NSError * _Nullable))completion {
	GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
	if (![mainCredentials canSendSGWAPIRequests]) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"SGW credential is missing a hostname, cannot send API requests!"]);
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/device/%@/config/filters", [mainCredentials hostname], deviceId]]];
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
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to set device filter configs: %@", apiErr]]);
			return;
		}
		
		if (completion) completion(nil);
	}];
	[task resume];
}

@end
