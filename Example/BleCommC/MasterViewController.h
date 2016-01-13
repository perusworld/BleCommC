//
//  MasterViewController.h
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Constants.h"
#import <BleCommC/BLE.h>

@class DetailViewController;

@interface MasterViewController : UITableViewController <ScanDelegate>

@property (strong, nonatomic) DetailViewController *detailViewController;
@property (strong, nonatomic) BLEScan *bleScan;


@end

