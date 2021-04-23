//
//  AppDelegate.h
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCSubscriptionManager.h"


@interface AppDelegate : NSObject <NSApplicationDelegate, GCSubscriptionManagerDelegate>

@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSTextField *dataTrackerField;
@property (weak) IBOutlet NSTextField *mailTrackerField;
@property (weak) IBOutlet NSTextField *pageHijackerField;
@property (weak) IBOutlet NSTextField *locationTrackerField;
@property (weak) IBOutlet NSButton *createButton;
@property (weak) IBOutlet NSButton *refreshButton;
@property (weak) IBOutlet NSButton *onDemandCheckbox;

- (IBAction)login:(id)sender;
- (IBAction)createVPNConnection:(id)sender;
- (IBAction)clearKeychain:(id)sender;
- (IBAction)spoofReceiptData:(id)sender;
- (IBAction)refreshEventData:(id)sender;
@end

