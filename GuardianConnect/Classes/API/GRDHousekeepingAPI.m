//
//  GRDHousekeepingAPI.m
//  Guardian
//
//  Created by Constantin Jacob on 18.11.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDHousekeepingAPI.h>

@implementation GRDHousekeepingAPI

- (instancetype)init {
	self = [super init];
	if (self) {
		//
		// Ensure that housekeeping API requests always have
		// a valid hostname set to begin with
		self.housekeepingHostname = kConnectAPIHostname;
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults valueForKey:kGRDHousekeepingAPIHostname] != nil) {
			self.housekeepingHostname = [defaults stringForKey:kGRDHousekeepingAPIHostname];
		}
		
		if ([defaults valueForKey:kGRDConnectAPIHostname] != nil) {
			self.connectAPIHostname = [defaults stringForKey:kGRDConnectAPIHostname];
		}
		
		self.connectPublishableKey = [GRDKeychain getPasswordStringForAccount:kGRDConnectPublishableKey];
		
		GRDDebugLog(@"housekeeping-api-hostname:%@; connect-api-hostname:%@; connect-publishable-key:%@", self.housekeepingHostname, self.connectAPIHostname, self.connectPublishableKey);
	}
	
	return self;
}

- (NSMutableURLRequest *)housekeepingAPIRequestFor:(NSString *)apiEndpoint {
	NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", self.housekeepingHostname, apiEndpoint]];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setTimeoutInterval:15];
	
	return request;
}

- (NSMutableURLRequest *)connectAPIRequestFor:(NSString *)apiEndpoint {
	NSString *baseHostname = kConnectAPIHostname;
	if (self.connectAPIHostname != nil) {
		if ([self.connectAPIHostname isEqualToString:@""] == NO) {
			baseHostname = self.connectAPIHostname;
		}
	}
	
	NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", baseHostname, apiEndpoint]];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	if ([self connectPublishableKey] != nil) {
		[request setValue:[self connectPublishableKey] forHTTPHeaderField:@"GRD-Connect-Publishable-Key"];
	}
	
	return request;
}

- (void)getDeviceToken:(void (^)(id  _Nullable token, NSError * _Nullable error))completion {
    Class dcDeviceClass = NSClassFromString(@"DCDevice");
    __block NSString *defaultDevice = @"helloMyNameIs-iPhoneSimulator";
    if (!dcDeviceClass) {
        if (completion) {
            completion(defaultDevice, [NSError errorWithDomain:NSCocoaErrorDomain code:420 userInfo:@{}]);
        }
		
    } else {
        //this is fine since we are doing a class availability check above.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

        [[DCDevice currentDevice] generateTokenWithCompletionHandler:^(NSData * _Nullable token, NSError * _Nullable error) {
            if (token != nil && [token respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
                defaultDevice = [token base64EncodedStringWithOptions:0];
            }
			
            if (completion) completion(defaultDevice, error);
        }];
#pragma clang diagnostic pop
    }
}

# pragma mark - IAP Receipt Validation

- (void)verifyReceipt:(NSString * _Nullable)encodedReceipt bundleId:(NSString * _Nonnull)bundleId completion:(void (^)(NSArray <GRDReceiptLineItem *>* _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1.2/verify-receipt"]];
	if (encodedReceipt == nil) {
		NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
		if (receiptData == nil) {
			GRDLog(@"This device has no App Store receipt");
			if (completion) completion(nil, NO, @"No App Store receipt data present");
			return;
		}
		
		encodedReceipt = [receiptData base64EncodedStringWithOptions:0];
	}
	
	NSData *postData = [NSJSONSerialization dataWithJSONObject:@{@"receipt-data":encodedReceipt, @"bundle-id": bundleId} options:0 error:nil];
    [request setHTTPBody:postData];
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
            GRDLog(@"Failed to retrieve receipt data: %@", error);
            if (completion) completion(nil, NO, @"Failed to retrieve receipt data from server");
            return;
        }
        
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 204) {
            GRDLog(@"Successful request. No active subscription found");
            if (completion) completion(nil, YES, nil);
            return;
            
        } else if (statusCode == 200) {
            NSError *jsonError = nil;
            NSArray *validLineItems = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError != nil) {
                GRDWarningLogg(@"Failed to read valid line items: %@", jsonError);
                if (completion) completion(nil, YES, [NSString stringWithFormat:@"Failed to decode valid line items: %@", [jsonError localizedDescription]]);
                return;
                
            } else {
				__block NSMutableArray <GRDReceiptLineItem *> *items = [NSMutableArray new];
				[validLineItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
					[items addObject:[[GRDReceiptLineItem alloc] initWithDictionary:obj]];
				}];
                if (completion) completion(items, YES, nil);
                return;
            }
            
        } else {
			NSError *jsonError;
			NSDictionary *errorJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
			if (jsonError != nil) {
				if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to decode response error message JSON"]);
				return;
			}
			
			NSString *errorTitle = errorJSON[@"error-title"];
			NSString *errorMessage = errorJSON[@"error-message"];
			
            GRDErrorLogg(@"Unknown error %@ - %@. Status code: %ld", errorTitle, errorMessage, statusCode);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", errorMessage, statusCode]);
        }
    }];
    [task resume];
}

- (void)verifyReceiptData:(NSString *)encodedReceiptData bundleId:(NSString *)bundleId completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1.3/verify-receipt"]];
	if (encodedReceiptData == nil) {
		NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
		if (receiptData == nil) {
			GRDLog(@"This device has no App Store receipt");
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"No App Store receipt data present"]);
			return;
		}
		
		encodedReceiptData = [receiptData base64EncodedStringWithOptions:0];
	}
	
	NSData *postData = [NSJSONSerialization dataWithJSONObject:@{@"receipt-data":encodedReceiptData, @"bundle-id": bundleId} options:0 error:nil];
	[request setHTTPBody:postData];
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
			GRDLog(@"Failed to retrieve receipt data: %@", error);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Failed to retrieve receipt data from server"]);
			return;
		}
		
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			if (statusCode == 204) {
				if (completion) completion(nil, nil);
				return;
			}
			
			GRDAPIError *error = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:error.message]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode JSON response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(responseData, nil);
	}];
	[task resume];
}


# pragma mark - Subscriber Credentials

- (void)createSubscriberCredentialForBundleId:(NSString *)bundleId withValidationMethod:(GRDHousekeepingValidationMethod)validationMethod customKeys:(NSMutableDictionary * _Nullable)dict completion:(void (^)(NSString * _Nullable subscriberCredential, BOOL success, NSError * _Nullable errorMessage))completion {
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/subscriber-credential/create"];
	
	NSMutableDictionary *jsonDict = [[NSMutableDictionary alloc] init];
	if (validationMethod == ValidationMethodAppStoreReceipt) {
		NSString *appStoreReceipt;
		NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
		if (receiptData == nil) {
			// Note from CJ 2021-09-09:
			// This is a little bit of hand-wavey bullshit
			// but it might be useful in the future who knows.
			// For the time being it'll be used to enable the Mac app
			// to create Subscriber Credentials and connection with encoded
			// Apple in-app purchase receipts copied from the Guardian Firewall iOS app
			NSString *userDefaultsEncodedIAPReceipt = [[NSUserDefaults standardUserDefaults] stringForKey:kGuardianEncodedAppStoreReceipt];
			if (userDefaultsEncodedIAPReceipt == nil) {
				if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"AppStore receipt missing"]);
				return;
			}
			
			GRDLog(@"Found hard coded IAP receipt in NSUserDefaults. Trying that one");
			appStoreReceipt = userDefaultsEncodedIAPReceipt;
			
		} else {
			GRDLog(@"Base64 encoding AppStore receipt");
			appStoreReceipt = [receiptData base64EncodedStringWithOptions:0];
		}
		
		[jsonDict setObject:@"iap-apple" forKey:@"validation-method"];
		[jsonDict setObject:bundleId forKey:@"bundle-id"];
		[jsonDict setObject:appStoreReceipt forKey:@"app-receipt"];
		
	} else if (validationMethod == ValidationMethodPEToken) {
		GRDPEToken *petToken = [GRDPEToken currentPEToken];
		if (petToken == nil) {
			if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Failed to generate Subscriber Credential. Validation method PE-Token selected but a PE-Token is not available on device"]);
			return;
		}
		
		[jsonDict setObject:@"pe-token" forKey:@"validation-method"];
		[jsonDict setObject:petToken.token forKey:@"pe-token"];
		
	} else if (validationMethod == ValidationMethodCustom) {
		jsonDict = dict;
		
	} else {
		if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"validation method missing"]);
		return;
	}
	
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode JSON request body: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Couldn't create subscriber credential: %@", [error localizedDescription]]]);
			return;
		}
		
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiError = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to create Subscriber Credential: %@", apiError]]);
			return;
		}

		NSDictionary *dictFromJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		if (completion) completion([dictFromJSON objectForKey:@"subscriber-credential"], YES, nil);
		return;
	}];
	[task resume];
}


#pragma mark - PET Magic Link

- (void)requestPETokenInformationForToken:(NSString *)token completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1/users/info-for-pe-token"];
    
    NSData *jsonDict = [NSJSONSerialization dataWithJSONObject:@{@"pe-token": token} options:0 error:nil];
    [request setHTTPBody:jsonDict];
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

		NSDictionary *petInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		if (completion) completion(petInfo, nil);
		return;
    }];
    [task resume];
}


#pragma mark - Time Zone & VPN Hostnames

- (void)requestTimeZonesForRegionsWithCompletion:(void (^)(NSArray * _Nullable, NSError * _Nullable))completion {
    NSMutableURLRequest *request = [self housekeepingAPIRequestFor:@"/api/v1.1/servers/timezones-for-regions"];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:20];
	[sessionConf setTimeoutIntervalForResource:20];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDDebugLog(@"Failed to hit endpoint: %@", error);
            if (completion) completion(nil, error);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDDebugLog(@"Failed to obtain list of known timezones. Error: %@", apiErr);
            if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[apiErr description]]);
            
        } else {
            NSArray *timezones = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(timezones, nil);
        }
    }];
    [task resume];
}

- (void)requestServersForRegion:(NSString *)region regionPrecision:(NSString *)precision paidServers:(BOOL)paidServers featureEnvironment:(GRDServerFeatureEnvironment)featureEnvironment betaCapableServers:(BOOL)betaCapable completion:(void (^)(NSArray *, NSError *))completion {
	NSNumber *payingUserAsNumber = [NSNumber numberWithBool:paidServers];
	NSNumber *featureEnvAsInt = [NSNumber numberWithInt:(int)featureEnvironment];
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"region":region, @"paid":payingUserAsNumber, @"feature-environment": featureEnvAsInt, @"beta-capable": @(betaCapable), @"region-precision": precision} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self housekeepingAPIRequestFor:@"/api/v1.3/servers/hostnames-for-region"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:20];
	[sessionConf setTimeoutIntervalForResource:20];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSArray *servers = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(servers, nil);
	}];
	[task resume];
}

- (void)requestAllServerRegions:(void (^)(NSArray <NSDictionary *> * _Nullable items, BOOL success, NSError * _Nullable errorMessage))completion {
    NSMutableURLRequest *request = [self housekeepingAPIRequestFor:@"/api/v1/servers/all-server-regions"];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:15];
	[sessionConf setTimeoutIntervalForResource:15];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to get retrieve all regions: %@", [error localizedDescription]]]);
			return;
        }
        
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Failed to retrieve regions. Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSArray *returnItems = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		if (completion) completion(returnItems, YES, nil);
		return;
    }];
    [task resume];
}

- (void)requestAllServerRegionsWithPrecision:(NSString * _Nonnull)precision completion:(void (^)(NSArray <NSDictionary *> * _Nullable items, NSError * _Nullable error))completion {
	NSMutableURLRequest *request = [self housekeepingAPIRequestFor:[NSString stringWithFormat:@"/api/v1.3/servers/all-server-regions/%@", precision]];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:15];
	[sessionConf setTimeoutIntervalForResource:15];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to get retrieve all regions: %@", [error localizedDescription]]]);
			return;
		}
		
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Failed to retrieve regions. Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSArray *returnItems = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		if (completion) completion(returnItems, nil);
		return;
	}];
	[task resume];
}

- (void)requestSmartProxyRoutingHostsWithCompletion:(void (^)(NSArray * _Nullable, NSError * _Nullable))completion {
	NSMutableURLRequest *request = [self housekeepingAPIRequestFor:@"/api/v1/smart-proxy-routing/hosts"];
	[request setHTTPMethod:@"GET"];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, error);
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to fetch smart proxy hosts with HTTP response status code: %ld; error-title: %@; error-message: %@", statusCode, apiErr.title, apiErr.message]]);
			return;
		}
		
		NSError *jsonErr;
		NSArray *hostsArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to JSON decode response data: %@", jsonErr]]);
			return;
		}
		
		if (completion) completion(hostsArray, nil);
	}];
	[task resume];
}


# pragma mark - Connect Subscriber

- (void)newConnectSubscriberWith:(NSString *)identifier secret:(NSString *)secret deviceNickname:(NSString *)deviceNickname acceptedTOS:(BOOL)acceptedTOS email:(NSString *)email andCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"ep-grd-subscriber-identifier": identifier, @"ep-grd-subscriber-secret": secret, @"ep-grd-subscriber-pet-nickname": deviceNickname, @"ep-grd-subscriber-accepted-tos": [NSNumber numberWithBool:acceptedTOS], @"ep-grd-subscriber-email": email} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.3/partners/subscribers/new"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 201) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *subscriber = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]] );
			return;
		}
		
		if (completion) completion(subscriber, nil);
		return;
	}];
	[task resume];
}

- (void)connectDeviceReferenceForConnectSubscriber:(NSString *)identifier secret:(NSString *)secret PEToken:(NSString *)peToken completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"ep-grd-subscriber-identifier": identifier, @"ep-grd-subscriber-secret": secret, @"pe-token": peToken} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/device-reference"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *deviceDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]] );
			return;
		}
		
		if (completion) completion(deviceDict, nil);
	}];
	[task resume];
}

- (void)updateConnectSubscriberWith:(NSString *)email identifier:(NSString *)identifier secret:(NSString *)secret andCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"ep-grd-subscriber-identifier": identifier, @"ep-grd-subscriber-secret": secret, @"ep-grd-subscriber-email": email} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/update"];
	[request setHTTPMethod:@"PUT"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *subscriber = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(subscriber, nil);
		return;
	}];
	[task resume];
}

- (void)validateConnectSubscriberWith:(NSString *)identifier secret:(NSString *)secret pet:(NSString * _Nonnull)pet andCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"ep-grd-subscriber-identifier": identifier, @"ep-grd-subscriber-secret": secret, kKeychainStr_PEToken: pet} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/validate"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *subscriber = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(subscriber, nil);
		return;
	}];
	[task resume];
}

- (void)logoutConnectSubscriberWithPEToken:(NSString *)pet andCompletion:(void (^)(NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{kKeychainStr_PEToken: pet} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/logout"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		if (completion) completion(nil);
		return;
	}];
	[task resume];
}

- (void)checkConnectSubscriberGuardianAccountCreationStateWithIdentifier:(NSString *)identifier secret:(NSString *)secret completion:(void (^)(NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"ep-grd-subscriber-identifier": identifier, @"ep-grd-subscriber-secret": secret} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/account-creation-state"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			if ([apiErr.message containsString:@"not yet setup"]) {
				if (completion) completion([GRDErrorHelper errorWithErrorCode:GRDErrGuardianAccountNotSetup andErrorMessage:@"Guardian account setup not yet completed"]);
				return;
			}
			
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		if (completion) completion(nil);
	}];
	[task resume];
}



# pragma mark - Connect Devices

- (void)addConnectDeviceWith:(NSString *)peToken nickname:(NSString *)nickname acceptedTOS:(BOOL)acceptedTOS andCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"pe-token": peToken, @"ep-grd-device-nickname": nickname, @"ep-grd-device-accepted-tos": [NSNumber numberWithBool:acceptedTOS]} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/devices/add"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *device = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(device, nil);
		return;
	}];
	[task resume];
}

- (void)updateConnectDevice:(NSString *)deviceUUID withPEToken:(NSString *)peToken nickname:(NSString *)nickname andCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"pe-token": peToken, @"ep-grd-device-nickname": nickname, @"ep-grd-device-uuid": deviceUUID} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/devices/update"];
	[request setHTTPMethod:@"PUT"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *device = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(device, nil);
		return;
	}];
	[task resume];
}

- (void)listConnectDevicesForPEToken:(NSString * _Nullable)peToken orIdentifier:(NSString * _Nullable)identifier andSecret:(NSString * _Nullable)secret withCompletion:(void (^)(NSArray * _Nullable, NSError * _Nullable))completion {
	if (peToken == nil && [peToken isEqualToString:@""] && identifier == nil && [identifier isEqualToString:@""] && secret == nil && [secret isEqualToString:@""]) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Unable to send API request. Did not receive a PE-Token or a subscriber identifier & secret!"]);
		return;
	}
	
	NSMutableDictionary *body = [NSMutableDictionary new];
	if (peToken != nil) {
		[body setObject:peToken forKey:@"pe-token"];
		
	} else {
		[body setObject:identifier forKey:@"ep-grd-subscriber-identifier"];
		[body setObject:secret forKey:@"ep-grd-subscriber-secret"];
	}
	
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/devices/list"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSArray *devices = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(devices, nil);
		return;
	}];
	[task resume];
}

- (void)deleteConnectDevice:(NSString *)deviceUUID withPEToken:(NSString * _Nullable)peToken orIdentifier:(NSString * _Nullable)identifier andSecret:(NSString * _Nullable)secret andCompletion:(void (^)(NSError * _Nullable))completion {
	if (peToken == nil && [peToken isEqualToString:@""] && identifier == nil && [identifier isEqualToString:@""] && secret == nil && [secret isEqualToString:@""]) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Unable to send API request. Did not receive a PE-Token or a subscriber identifier & secret!"]);
		return;
	}
	
	NSMutableDictionary *body = [NSMutableDictionary new];
	[body setObject:deviceUUID forKey:@"ep-grd-device-uuid"];
	
	if (peToken != nil) {
		[body setObject:peToken forKey:@"pe-token"];
		
	} else {
		[body setObject:identifier forKey:@"ep-grd-subscriber-identifier"];
		[body setObject:secret forKey:@"ep-grd-subscriber-secret"];
	}
	
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/device/delete"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		if (completion) completion(nil);
		return;
	}];
	[task resume];
}

- (void)validateConnectDevicePEToken:(NSString *)peToken andCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion {
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:@{@"pe-token": peToken} options:0 error:&jsonErr];
	if (jsonErr != nil) {
		if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to encode request data: %@", [jsonErr localizedDescription]]]);
		return;
	}
	
	NSMutableURLRequest *request = [self connectAPIRequestFor:@"/api/v1.2/partners/subscriber/device/validate"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	[request setTimeoutInterval:30];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	[sessionConf setTimeoutIntervalForRequest:30];
	[sessionConf setTimeoutIntervalForResource:30];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]]);
			return;
		}
		
		NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode != 200) {
			GRDAPIError *apiErr = [[GRDAPIError alloc] initWithData:data andStatusCode:statusCode];
			GRDErrorLogg(@"Error title: %@ message: %@ status code: %ld", apiErr.title, apiErr.message, statusCode);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", apiErr.message, statusCode]]);
			return;
		}
		
		NSError *jsonErr;
		NSDictionary *device = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if (jsonErr != nil) {
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to decode response data: %@", [jsonErr localizedDescription]]]);
			return;
		}
		
		if (completion) completion(device, nil);
		return;
	}];
	[task resume];
}

@end
