//
//  AppDelegate.h
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSButton *createButton;
@property (weak) IBOutlet NSButton *onDemandCheckbox;

- (IBAction)login:(id)sender;
- (IBAction)createVPNConnection:(id)sender;
- (IBAction)clearKeychain:(id)sender;
@end

