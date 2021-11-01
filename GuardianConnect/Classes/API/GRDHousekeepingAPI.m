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

- (NSMutableURLRequest *)requestWithEndpoint:(NSString *)apiEndpoint andPostRequestData:(NSData *)postRequestDat {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://connect-api.guardianapp.com%@", apiEndpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    [request setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forHTTPHeaderField:@"X-Guardian-Build"];
    if ([[GRDVPNHelper sharedInstance] connectAPIKey]){
        [request setValue:[[GRDVPNHelper sharedInstance] connectAPIKey] forHTTPHeaderField:@"GRD-API-Key"];
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

# warning this needs to be yeeted outta here
- (NSArray *)receiptIgnoreProducts {
    return @[kGuardianSubscriptionTypeCustomDayPass];
}

- (void)verifyReceipt:(NSString * _Nullable)encodedReceipt bundleId:(NSString * _Nonnull)bundleId filtered:(BOOL)filtered completion:(void (^)(NSArray <GRDReceiptItem *>* _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage))completion {
	[self verifyReceipt:encodedReceipt bundleId:bundleId completion:^(NSArray<GRDReceiptItem *> * _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage) {
		if (completion) {
			if (success == NO) {
				completion(validLineItems, success, errorMessage);
			
			} else {
				if ([validLineItems count] < 1) {
					completion(validLineItems, success, errorMessage);
					return;
						
				} else {
					NSSortDescriptor *expireDesc = [[NSSortDescriptor alloc] initWithKey:@"expiresDate" ascending:true];
					NSArray *sorted = [validLineItems sortedArrayUsingDescriptors:@[expireDesc]];
					completion(sorted, success, errorMessage);
				}
			}
		}
	}];
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
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Failed to retrieve receipt data: %@", error);
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
                GRDWarningLog(@"Failed to read valid line items: %@", jsonError);
                if (completion) completion(nil, YES, [NSString stringWithFormat:@"Failed to decode valid line items: %@", [jsonError localizedDescription]]);
                return;
                
            } else {
				__block NSMutableArray <GRDReceiptItem *> *items = [NSMutableArray new];
				[validLineItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
					GRDReceiptItem *item = [[GRDReceiptItem alloc] initWithDictionary:obj];
					//dont wan't to process those at all, so dont add the item for them.
					if (![[self receiptIgnoreProducts] containsObject:item.productId]) {
						[items addObject:item];
					}
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
			
            GRDErrorLog(@"Unknown error %@ - %@. Status code: %ld", errorTitle, errorMessage, statusCode);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown error: %@ - Status code: %ld", errorMessage, statusCode]);
        }
    }];
    [task resume];
}

- (void)createNewSubscriberCredentialWithValidationMethod:(GRDHousekeepingValidationMethod)validationMethod completion:(void (^)(NSString * _Nullable, BOOL, NSString * _Nullable))completion {
    
#if GUARDIAN_INTERNAL
    GRDDebugHelper *debugHelper = [[GRDDebugHelper alloc] initWithTitle:@"createNewSubscriberCredentialWithValidationMethod"];
#endif
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1/subscriber-credential/create"]];
    
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
                NSLog(@"[DEBUG][createNewSubscriberCredentialWithValidationMethod] receiptData == nil");
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
        
        [jsonDict setObject:@"iap-guardian" forKey:@"validation-method"];
        [jsonDict setObject:appStoreReceipt forKey:@"app-receipt"];
        
    } else if (validationMethod == ValidationmethodPEToken) {
        NSString *petToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
        if (petToken == nil) {
            NSLog(@"[createNewSubscriberCredentialWithValidationMethod] Failed to retrieve PEToken from keychain");
            if (completion) completion(nil, NO, @"Failed to retrieve PEToken from keychain. Please try again");
            return;
        }
        
        [jsonDict setObject:@"pe-token" forKey:@"validation-method"];
        [jsonDict setObject:petToken forKey:@"pe-token"];
        
    } else {
        if (completion) completion(nil, NO, @"validation method missing");
        return;
    }
    
    [request setHTTPMethod:@"POST"];
    if ([[GRDVPNHelper sharedInstance] connectAPIKey]) {
        [request setValue:[[GRDVPNHelper sharedInstance] connectAPIKey] forHTTPHeaderField:@"GRD-API-Key"];
    }
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil]];
    
#if GUARDIAN_INTERNAL
    [debugHelper logTimeWithMessage:@"about to send POST request to API"];
#endif
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
#if GUARDIAN_INTERNAL
        [debugHelper logTimeWithMessage:@"request completion block start"];
#endif
        if (error != nil) {
            NSLog(@"Failed to create subscriber credential: %@", [error localizedDescription]);
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Couldn't create subscriber credential: %@", [error localizedDescription]]);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            NSLog(@"Housekeeping failed to return subscriber credential");
            if (completion) completion(nil, NO, @"Internal server error - couldn't create subscriber credential");
            return;
            
        } else if (statusCode == 400) {
            NSLog(@"Failed to create subscriber credential. Faulty input values");
            if (completion) completion(nil, NO, @"Failed to create subscriber credential. Faulty input values");
            return;
            
        } else if (statusCode == 401) {
            NSLog(@"No subscription present");
            if (completion) completion(nil, NO, @"No subscription present");
            return;
            
        } else if (statusCode == 410) {
            NSLog(@"Subscription expired");
            // Not sending an error message back so that we're not showing a useless error to the user
            // The app should transition to free/unpaid if required
            if (completion) completion(nil, NO, nil);
            return;
            
        } else if (statusCode == 200) {
            NSDictionary *dictFromJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion([dictFromJSON objectForKey:@"subscriber-credential"], YES, nil);
            return;
            
        } else {
            NSLog(@"Unknown server error");
            if (completion) completion(nil, NO, [NSString stringWithFormat:@"Unknown server error: %ld", statusCode]);
        }
        
#if GUARDIAN_INTERNAL
        [debugHelper logTimeWithMessage:@"request completion block end"];
#endif
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
    if ([[GRDVPNHelper sharedInstance] connectAPIKey]){
        [request setValue:[[GRDVPNHelper sharedInstance] connectAPIKey] forHTTPHeaderField:@"GRD-API-Key"];
    }
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
    if ([[GRDVPNHelper sharedInstance] connectAPIKey]){
        [request setValue:[[GRDVPNHelper sharedInstance] connectAPIKey] forHTTPHeaderField:@"GRD-API-Key"];
    }
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
    
    NSURLSession *session = [NSURLSession sharedSession];
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

- (void)requestServersForRegion:(NSString *)region paidServers:(BOOL)paidServers featureEnvironment:(GRDHousekeepingServerFeatureEnvironment)featureEnvironment completion:(void (^)(NSArray *, BOOL))completion {
	NSNumber *payingUserAsNumber = [NSNumber numberWithBool:paidServers];
    NSData *requestJSON = [NSJSONSerialization dataWithJSONObject:@{@"region":region, @"paid":payingUserAsNumber, @"feature-environment": [NSNumber numberWithInt:(int)featureEnvironment]} options:0 error:nil];
    NSMutableURLRequest *request = [self requestWithEndpoint:@"/api/v1.2/servers/hostnames-for-region" andPostRequestData:requestJSON];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error != nil) {
            NSLog(@"[requestServersForRegion] Failed to hit endpoint: %@", error);
            if (completion) completion(nil, NO);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 400) {
            NSLog(@"[requestServersForRegion] region key missing or mangled in JSON");
            if (completion) completion(nil, NO);
            return;
            
        } else if (statusCode == 500) {
            NSLog(@"[requestServersForRegion] Internal server error");
            if (completion) completion(nil, NO);
            return;
            
        } else if (statusCode == 200) {
            NSArray *servers = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) {
                completion(servers, YES);
            }
        } else {
            NSLog(@"[requestServersForRegion] Uncaught http response status: %ld", statusCode);
            if (completion) completion(nil, NO);
            return;
        }
    }];
    [task resume];
}

- (void)requestAllHostnamesWithCompletion:(void (^)(NSArray * _Nullable, BOOL))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1.1/servers/all-hostnames"]];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[requestAllHostnamesWithCompletion] Request failed: %@", error);
            if (completion) completion(nil, NO);
            return;
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            NSLog(@"[requestAllHostnamesWithCompletion] Internal server error");
            if (completion) completion(nil, NO);
            
        } else if (statusCode == 200) {
            NSArray *servers = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(servers, YES);
            
        } else {
            NSLog(@"[requestAllHostnamesWithCompletion] Uncaught http response status: %ld", statusCode);
            if (completion) completion(nil, NO);
            return;
        }
    }];
    [task resume];
}

- (void)requestAllServerRegions:(void (^)(NSArray <NSDictionary *> * _Nullable items, BOOL success))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1/servers/all-server-regions"]];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Failed to get all region items: %@", error);
            if (completion) completion(nil, NO);
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            NSLog(@"[requestAllServerRegions] Internal server error");
            if (completion) completion(nil, NO);
            return;
            
        } else if (statusCode == 204) {
            NSLog(@"[requestAllServerRegions] came back empty");
            if (completion) completion(@[], YES);
            return;
            
        } else if (statusCode == 200) {
            NSArray *returnItems = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(returnItems, YES);
            return;
            
        } else {
            NSLog(@"Unknown server response: %ld", statusCode);
            if (completion) completion(nil, NO);
        }
    }];
    [task resume];
}

# pragma mark - User Endpoints

- (void)loginUserWithEMail:(NSString *)email password:(NSString *)password completion:(void (^)(NSDictionary * _Nullable response, NSString * _Nullable errorMessage, BOOL success))completion {
    
    if ([[email lowercaseString] isEqualToString:@"bad"]) {
        if (completion) {
            completion(@{@"error": @"bunk"}, @"dummy user bad login", FALSE);
            return;
        }
    }
   
    NSData *requestJSON = [NSJSONSerialization dataWithJSONObject:@{@"email":email, @"password":password} options:0 error:nil];
    NSMutableURLRequest *request = [self requestWithEndpoint:@"/api/v1/users/login" andPostRequestData:requestJSON];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setValue:@"1" forHTTPHeaderField:@"GRD-iOS-App"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[loginUserWithEMail] Failed with error: %@", error);
            if (completion) completion(nil, [NSString stringWithFormat:@"Failed to send login informaton to server: %@", [error localizedDescription]], NO);
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            NSLog(@"[loginUserWithEMail] Internal server error");
            if (completion) completion(nil, @"Internal server error", NO);
            return;
            
        } else if (statusCode == 404) {
            NSLog(@"[loginUserWithEMail] User not found");
            if (completion) completion(nil, @"Bad login data. Please try again", NO);
            return;
            
        } else if (statusCode == 400) {
            NSLog(@"[loginUserWithEMail] Bad request");
            if (completion) completion(nil, @"Failed to login. Bad request - please try again", NO);
            return;
            
        } else if (statusCode == 200) {//pe-token
            NSDictionary *authResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(authResponse, nil, YES);
            return;
            
        } else {
            NSLog(@"Unknown server response: %ld", statusCode);
            if (completion) completion(nil, [NSString stringWithFormat:@"Unknown server error: %ld", statusCode], NO);
        }
    }];
    [task resume];
}

- (void)signoutUserPET:(NSString *)petoken completion:(void (^)(BOOL, NSString * _Nullable))completion {
    if ([petoken isEqualToString:@""]) {
        GRDLog(@"Empty PE-Token. Nothing to do");
        if (completion) completion(YES, nil);
        return;
    }
    
    NSError *jsonEncodeError;
    NSData *requestJSON = [NSJSONSerialization dataWithJSONObject:@{@"pe-token": petoken} options:0 error:&jsonEncodeError];
    if (jsonEncodeError != nil) {
        GRDLog(@"Failed to encode JSON: %@", jsonEncodeError);
        if (completion) completion(NO, [NSString stringWithFormat:@"Failed to encode JSON: %@", [jsonEncodeError localizedDescription]]);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1/users/sign-out"]];
    [request setHTTPMethod:@"POST"];
    if ([[GRDVPNHelper sharedInstance] connectAPIKey]){
        [request setValue:[[GRDVPNHelper sharedInstance] connectAPIKey] forHTTPHeaderField:@"GRD-API-Key"];
    }
    [request setHTTPBody:requestJSON];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            GRDLog(@"Failed to send request: %@", error);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]);
            return;
        }
        
        NSError *jsonError;
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil && statusCode != 200) {
            GRDLog(@"Failed to decode JSON response: %@", jsonError);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to decode JSON response: %@", [error localizedDescription]]);
            return;
        }
        
        if (statusCode == 500) {
            GRDLog(@"Internal Server Error! Failed to mark PET as disabled");
            if (completion) completion(false, @"Internal Server Error! Failed to mark PET as disabled");
            
        } else if (statusCode == 419 || statusCode == 409) {
            GRDLog(@"Failed to mark PET as disabled: %@ - %@", [responseDict objectForKey:@"error-title"], [responseDict objectForKey:@"error-message"]);
            if (completion) completion(NO, [NSString stringWithFormat:@"Failed to mark PET as disabled: %@ - %@", [responseDict objectForKey:@"error-title"], [responseDict objectForKey:@"error-message"]]);
            return;
            
        } else if (statusCode == 200) {
            if (completion) completion(YES, nil);
            return;
            
        } else {
            NSString *errorTitle = [responseDict objectForKey:@"error-title"];
            NSString *errorMessage = [responseDict objectForKey:@"error-message"];
            if (errorTitle == nil || errorMessage == nil) {
                GRDLog(@"Failed to mark PET as disabled! Unknown status code: %ld", statusCode);
                if (completion) completion(NO, [NSString stringWithFormat:@"Failed to mark PET as disabled. Unknown status code: %ld", statusCode]);
                return;
                
            } else {
                GRDLog(@"Failed to mark PET as disabled! Unknown status code: %ld - %@ - %@", statusCode, errorTitle, errorMessage);
                if (completion) completion(NO, [NSString stringWithFormat:@"Failed to mark PET as disabled! Unknown status code: %ld - %@ - %@", statusCode, errorTitle, errorMessage]);
            }
        }
    }];
    [task resume];
}

# pragma mark - Trial Days Endpoints

- (void)isEligibleForExtendedFreeWithCompletion:(void (^)(BOOL, BOOL, BOOL, NSInteger, NSString * _Nullable, NSInteger, NSString * _Nullable))completion {
    [self getDeviceToken:^(id _Nullable token, NSError * _Nullable error) {
        NSString *deviceCheckToken;
        if (token != nil && [token respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
            deviceCheckToken = [token base64EncodedStringWithOptions:0];
        } else {
            if (error != nil) {
                NSLog(@"DeviceCheck Token generation error: %@", error);
                if (completion) completion(NO, NO, NO, 0, nil, -1, [NSString stringWithFormat:@"DeviceCheck token generation failed. If this issue persists please contact our technical support! Error: %@", [error localizedDescription]]);
                return;
            }
            deviceCheckToken = @"helloMyNameIs-iPhoneSimulator";
        }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1.1/is-eligible-for-free"]];
        [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        
        NSError *jsonError = nil;
        NSData *jsonPayload = [NSJSONSerialization dataWithJSONObject:@{@"device-check-token": deviceCheckToken} options:0 error:&jsonError];
        if (jsonError) {
            GRDLog(@"jsonError: %@", jsonError);
            if (completion) completion(NO, NO, NO, 0, nil, -1, [NSString stringWithFormat:@"Failed to generate API payload. If this issue persists please contact our technical support! Error: %@", [jsonError localizedDescription]]);
            return;
        }
        
        [request setHTTPBody:jsonPayload];
        [request setHTTPMethod:@"POST"];
        if ([[GRDVPNHelper sharedInstance] connectAPIKey]){
            [request setValue:[[GRDVPNHelper sharedInstance] connectAPIKey] forHTTPHeaderField:@"GRD-API-Key"];
        }
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error != nil) {
                GRDLog(@"Failed to send request: %@", [error localizedDescription]);
                if (completion) completion(NO, NO, NO, 0, nil, -1, [NSString stringWithFormat:@"Failed to send request: %@", [error localizedDescription]]);
                return;
            }
            
            NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode == 500) {
                NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *errorTitle = [errorDict objectForKey:@"error-title"];
                NSString *errorMessage = [errorDict objectForKey:@"error-message"];
                GRDLog(@"%@ - %@", errorTitle, errorMessage);
                if (completion) completion(YES, NO, NO, 0, nil, -1, [NSString stringWithFormat:@"%@ - %@", errorTitle, errorMessage]);
                return;
                
            } else if (statusCode == 400) {
                NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *errorTitle = [errorDict objectForKey:@"error-title"];
                NSString *errorMessage = [errorDict objectForKey:@"error-message"];
                GRDLog(@"%@ - %@", errorTitle, errorMessage);
                if (completion) completion(YES, NO, NO, 0, nil, -1, [NSString stringWithFormat:@"%@ - %@", errorTitle, errorMessage]);
                return;
                
            } else if (statusCode == 300) {
                GRDLog(@"Old style trial balance activated");
                NSDictionary *petJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *peToken = [petJSON objectForKey:@"pe-token"];
                NSNumber *petExpirationDate = [petJSON objectForKey:@"pet-expires"];
                NSNumber *trialBalance = [petJSON objectForKey:@"trial-balance"];
                if (completion) completion(YES, YES, YES, [trialBalance integerValue], peToken, [petExpirationDate integerValue], nil);
                return;
                
            } else if (statusCode == 200) {
                GRDLog(@"Eligible for free day passes");
                NSDictionary *trialJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSNumber *trialBalance = [trialJSON objectForKey:@"trial-balance"];
                if (completion) completion(YES, NO, YES, [trialBalance integerValue], nil, -1, nil);
                return;
                
            } else {
                GRDLog(@"Unknown server error. Response status code: %ld", statusCode);
                if (completion) completion(NO, NO, NO, 0, nil, -1, [NSString stringWithFormat:@"Unknown server error. Response status code: %ld", statusCode]);
                return;
            }
        }];
        [task resume];
    }];
}

@end
