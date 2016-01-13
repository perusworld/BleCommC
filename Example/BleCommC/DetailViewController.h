//
//  DetailViewController.h
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Constants.h"
#import <BleCommC/BLE.h>

@interface DetailViewController : UIViewController <CommDelegate, UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) id peripheralName;
@property (strong, nonatomic) id peripheralId;

-(void) setPeripheral:(id) peripheralId peripheralName:(id)peripheralName;

- (IBAction)onConnect:(UIButton *)sender;
- (IBAction)onSend:(id)sender;
- (IBAction)onDisconnect:(UIButton *)sender;

@property (weak, nonatomic) IBOutlet UITextField *msg;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@property (weak, nonatomic) IBOutlet UITableView *tvMsgs;

@property (strong, nonatomic) DefaultBLEComm *bleComm;

@end

