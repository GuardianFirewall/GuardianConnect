//
//  GRDHousekeepingAPI.m
//  Guardian
//
//  Created by Constantin Jacob on 18.11.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDHousekeepingAPI.h>
#import <GuardianConnect/NSObject+Dictionary.h>

@implementation GRDHousekeepingAPI

- (instancetype)initWithAppKey:(NSString *)appKey andAppBundleId:(NSString *)appBundleId {
	self = [GRDHousekeepingAPI new];
	if (self) {
		self.appKey 		= appKey;
		self.appBundleId 	= appBundleId;
	}
	
	return self;
}

- (NSMutableURLRequest *)requestWithEndpoint:(NSString *)apiEndpoint andPostRequestData:(NSData *)postRequestDat {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://connect-api.guardianapp.com%@", apiEndpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
	if ([self appKey] != nil) {
		[request setValue:[self appKey] forHTTPHeaderField:@"GRD-CNT-App-Key"];
	}
	if ([self appBundleId] != nil) {
		[request setValue:[self appBundleId] forHTTPHeaderField:@"GRD-CNT-Bundle-Id"];
	}
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:postRequestDat];
    
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

- (void)verifyReceipt:(NSString * _Nullable)encodedReceipt bundleId:(NSString * _Nonnull)bundleId completion:(void (^)(NSArray <GRDReceiptItem *>* _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1.2/verify-receipt"]];
	if (encodedReceipt == nil) {
		NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
		if (receiptData == nil) {
			GRDDebugLog(@"This device has no App Store receipt");
			if (completion) completion(nil, NO, @"No App Store receipt data present");
			return;
		}
		
		encodedReceipt = [receiptData base64EncodedStringWithOptions:0];
	}
	
	NSData *postData = [NSJSONSerialization dataWithJSONObject:@{@"receipt-data":encodedReceipt, @"bundle-id": bundleId} options:0 error:nil];
    [request setHTTPBody:postData];
    [request setHTTPMethod:@"POST"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to retrieve receipt data: %@", error);
            if (completion) completion(nil, NO, @"Failed to retrieve receipt data from server");
            return;
        }
        
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 204) {
            GRDDebugLog(@"Successful request. No active subscription found");
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
				__block NSMutableArray <GRDReceiptItem *> *items = [NSMutableArray new];
				[validLineItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
					[items addObject:[[GRDReceiptItem alloc] initWithDictionary:obj]];
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

- (void)createSubscriberCredentialForBundleId:(NSString *)bundleId withValidationMethod:(GRDHousekeepingValidationMethod)validationMethod customKeys:(NSMutableDictionary * _Nullable)dict completion:(void (^)(NSString * _Nullable subscriberCredential, BOOL success, NSString * _Nullable errorMessage))completion {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1.2/subscriber-credential/create"]];
	
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
				GRDLog(@"ReceiptData is nil");
				if (completion) {
					completion(nil, NO, @"AppStore receipt missing");
				}
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
		NSString *petToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
		if (petToken == nil) {
			GRDLog(@"Failed to retrieve PEToken from keychain");
			if (completion) completion(nil, NO, @"Failed to retrieve PEToken from keychain. Please try again");
			return;
		}
		
		[jsonDict setObject:@"pe-token" forKey:@"validation-method"];
		[jsonDict setObject:petToken forKey:@"pe-token"];
		
	} else if (validationMethod == ValidationMethodCustom) {
		jsonDict = dict;
		
	} else {
		if (completion) completion(nil, NO, @"validation method missing");
		return;
	}
	
	NSError *jsonErr;
	NSData *requestData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonErr];
	if (jsonErr != nil) {
		GRDErrorLog(@"Failed to encode JSON request body: %@", jsonErr);
		if (completion) completion(nil, NO, @"Failed to encode JSON request body");
		return;
	}
		
	if ([self appKey] != nil) {
		[request setValue:[self appKey] forHTTPHeaderField:@"GRD-CNT-App-Key"];
	}
	if ([self appBundleId] != nil) {
		[request setValue:[self appBundleId] forHTTPHeaderField:@"GRD-CNT-Bundle-Id"];
	}
	
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:requestData];
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
	NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			GRDLog(@"Failed to create subscriber credential: %@", [error localizedDescription]);
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Couldn't create subscriber credential: %@", [error localizedDescription]]);
			return;
		}
		
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		if (statusCode == 500) {
			GRDLog(@"Housekeeping failed to return subscriber credential");
			if (completion) completion(nil, NO, @"Internal server error - couldn't create subscriber credential");
			return;
			
		} else if (statusCode == 400) {
			GRDLog(@"Failed to create subscriber credential. Faulty input values");
			if (completion) completion(nil, NO, @"Failed to create subscriber credential. Faulty input values");
			return;
			
		} else if (statusCode == 401) {
			GRDLog(@"No subscription present");
			if (completion) completion(nil, NO, @"No subscription present");
			return;
			
		} else if (statusCode == 410) {
			GRDLog(@"Subscription expired");
			// Not sending an error message back so that we're not showing a useless error to the user
			// The app should transition to free/unpaid if required
			if (completion) completion(nil, NO, nil);
			return;
			
		} else if (statusCode == 200) {
			NSDictionary *dictFromJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if (completion) completion([dictFromJSON objectForKey:@"subscriber-credential"], YES, nil);
			return;
			
		} else {
			GRDLog(@"Unknown server error");
			if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown server error: %ld", statusCode]);
		}
	}];
	[task resume];
}

- (void)generateSignupTokenForIAPPro:(void (^)(NSDictionary * _Nullable, BOOL, NSString * _Nullable))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1/users/signup-token-for-iap"]];
    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    if (receiptData == nil) {
        GRDLog(@"receiptData == nil");
        if (completion) {
            completion(nil, NO, @"No App Store receipt data present");
        }
        return;
    }
    NSData *postData = [NSJSONSerialization dataWithJSONObject:@{@"receipt-data":[receiptData base64EncodedStringWithOptions:0]} options:0 error:nil];
    [request setHTTPBody:postData];
    [request setHTTPMethod:@"POST"];
	if ([self appKey] != nil) {
		[request setValue:[self appKey] forHTTPHeaderField:@"GRD-CNT-App-Key"];
	}
	if ([self appBundleId] != nil) {
		[request setValue:[self appBundleId] forHTTPHeaderField:@"GRD-CNT-Bundle-Id"];
	}
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to send request: %@", error);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            GRDLog(@"Internal server error!");
            if (completion) completion(nil, NO, @"Failed to generate signup token: Internal Server Error");
            return;
            
        } else if (statusCode == 412) {
            GRDLog(@"Information missing from receipt!");
            if (completion) completion(nil, NO, @"Failed to generate signup token: Missing information in AppStore receipt. If this issue persists please contact our technical support");
            return;
            
        } else if (statusCode == 204) {
            GRDLog(@"No Pro subscription found in receipt or receipt already used to generate an account");
            if (completion) completion(nil, NO, @"Failed to generate signup token: No Pro subscription found in AppStore receipt or this receipt was already used to generate an account. If this issue persist please contact our technical support");
            return;
            
        } else if (statusCode == 200) {
            NSDictionary *userInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(userInfo, YES, nil);
            return;
            
        } else {
            GRDLog(@"Unknown server error. Status code: %ld", statusCode);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown server error. Status code: %ld", statusCode]);
        }
    }];
    [task resume];
}

- (void)requestPETokenInformationForToken:(NSString *)token completion:(void (^)(NSDictionary * _Nullable, NSString * _Nullable, BOOL))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1/users/info-for-pe-token"]];
    
    NSData *jsonDict = [NSJSONSerialization dataWithJSONObject:@{@"pe-token": token} options:0 error:nil];
    [request setHTTPBody:jsonDict];
    [request setHTTPMethod:@"POST"];
	if ([self appKey] != nil) {
		[request setValue:[self appKey] forHTTPHeaderField:@"GRD-CNT-App-Key"];
	}
	if ([self appBundleId] != nil) {
		[request setValue:[self appBundleId] forHTTPHeaderField:@"GRD-CNT-Bundle-Id"];
	}
	
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to send request: %@", [error localizedDescription]);
            if (completion) completion(nil, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]], NO);
            return;
        }
        
        
        NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            GRDLog(@"Internal server error");
            if (completion) completion(nil, @"Internal server error requesting information for your authentication token. Please try again. If this issue persists please contact our technical support.", NO);
            return;
            
        } else if (statusCode == 400) {
            GRDLog(@"Bad request");
            if (completion) completion(nil, @"Badly formatted server request try to query information for your authentication token. Please try again. If this issue persists please contact our technical support.", NO);
            return;
            
        } else if (statusCode == 401) {
            GRDLog(@"Couldn't find pe-token in database");
            if (completion) completion(nil, @"Unable to find authentication token in database. Please try again. If this issue persists please contact our technical support.", NO);
            return;
            
        } else if (statusCode == 200) {
            NSDictionary *petInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(petInfo, nil, YES);
            return;
            
        } else {
            GRDLog(@"Unknown server error: %ld", statusCode);
            if (completion) completion(nil, [NSString stringWithFormat:@"Unknown server error: %ld", statusCode], NO);
        }
    }];
    [task resume];
}

#pragma mark - Time Zone & VPN Hostname endpoints

- (void)requestTimeZonesForRegionsWithCompletion:(void (^)(NSArray *timezones, BOOL success, NSUInteger responseStatusCode))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://connect-api.guardianapp.com/api/v1.1/servers/timezones-for-regions"]]];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error != nil) {
            GRDLog(@"Failed to hit endpoint: %@", error);
            if (completion) completion(nil, NO, 0);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode != 200) {
            if (completion) completion(nil, NO, statusCode);
            
        } else {
            NSArray *timezones = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(timezones, YES, statusCode);
        }
    }];
    [task resume];
}

- (void)requestServersForRegion:(NSString *)region paidServers:(BOOL)paidServers featureEnvironment:(GRDServerFeatureEnvironment)featureEnvironment betaCapableServers:(BOOL)betaCapable completion:(void (^)(NSArray *, BOOL))completion {
	NSNumber *payingUserAsNumber = [NSNumber numberWithBool:paidServers];
    NSData *requestJSON = [NSJSONSerialization dataWithJSONObject:@{@"region":region, @"paid":payingUserAsNumber, @"feature-environment": [NSNumber numberWithInt:(int)featureEnvironment], @"beta-capable": @(betaCapable)} options:0 error:nil];
    NSMutableURLRequest *request = [self requestWithEndpoint:@"/api/v1.2/servers/hostnames-for-region" andPostRequestData:requestJSON];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to hit endpoint: %@", error);
            if (completion) completion(nil, NO);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 400) {
            GRDLog(@"region key missing or mangled in JSON");
            if (completion) completion(nil, NO);
            return;
            
        } else if (statusCode == 500) {
            GRDLog(@"Internal server error");
            if (completion) completion(nil, NO);
            return;
            
        } else if (statusCode == 200) {
            NSArray *servers = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) {
                completion(servers, YES);
            }
        } else {
            GRDLog(@"Uncaught http response status: %ld", statusCode);
            if (completion) completion(nil, NO);
            return;
        }
    }];
    [task resume];
}

- (void)requestAllHostnamesWithCompletion:(void (^)(NSArray * _Nullable, BOOL))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1.1/servers/all-hostnames"]];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Request failed: %@", error);
            if (completion) completion(nil, NO);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            GRDLog(@"Internal server error");
            if (completion) completion(nil, NO);
            
        } else if (statusCode == 200) {
            NSArray *servers = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(servers, YES);
            
        } else {
            GRDLog(@"Uncaught http response status: %ld", statusCode);
            if (completion) completion(nil, NO);
            return;
        }
    }];
    [task resume];
}

- (void)requestAllServerRegions:(void (^)(NSArray <NSDictionary *> * _Nullable items, BOOL success))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1/servers/all-server-regions"]];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
	NSURLSessionConfiguration *sessionConf = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	[sessionConf setWaitsForConnectivity:YES];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConf];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to get all region items: %@", error);
            if (completion) completion(nil, NO);
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            GRDLog(@"Internal server error");
            if (completion) completion(nil, NO);
            return;
            
        } else if (statusCode == 204) {
            GRDLog(@"Came back empty");
            if (completion) completion(@[], YES);
            return;
            
        } else if (statusCode == 200) {
            NSArray *returnItems = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(returnItems, YES);
            return;
            
        } else {
            GRDLog(@"Unknown server response: %ld", statusCode);
            if (completion) completion(nil, NO);
        }
    }];
    [task resume];
}


@end
