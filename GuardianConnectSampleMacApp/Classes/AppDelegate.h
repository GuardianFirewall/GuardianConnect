//
//  AppDelegate.h
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import "GCSubscriptionManager.h"
#import "MainMenuController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet MainMenuController *mainMenuController;

- (IBAction)refreshEventData:(id)sender;

@end

