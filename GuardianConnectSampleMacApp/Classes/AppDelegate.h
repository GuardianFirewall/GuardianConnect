//
//  AppDelegate.h
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCSubscriptionManager.h"
#import "GCImageView.h"
#import "GCWindow.h"
#import "MainMenuController.h"

typedef NS_ENUM(NSInteger, GRDButtonType) {
    GRDButtonTypeTotalAlerts = 10,
    GRDButtonTypeDataTracker,
    GRDButtonTypeLocationTracker,
    GRDButtonTypeMailTracker,
    GRDButtonTypePageHijacker,
};


@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet MainMenuController *mainMenuController;

- (IBAction)refreshEventData:(id)sender;

@end

