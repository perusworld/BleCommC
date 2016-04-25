//
//  MasterViewController.m
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"

@interface MasterViewController ()

@property NSMutableArray *names;
@property NSMutableArray *ids;
@end

@implementation MasterViewController

@synthesize bleScan;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(doRescan:)];
    self.navigationItem.rightBarButtonItem = refreshButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    self.bleScan = [BLEScan new];
    
//    self.bleScan = [DeviceInfoBLEScan new];
//    ((DeviceInfoBLEScan *) self.bleScan).characteristics = @[[CBUUID UUIDWithString:@MODEL_NUM], [CBUUID UUIDWithString:@SERIAL_NUM]];
    
//    self.bleScan = [FilteredBLEScan new];
//    ((FilteredBLEScan *) self.bleScan).includeFilter = [NSPredicate predicateWithFormat:@"SELF.serialNumber == %@ && SELF.modelNumber == %@", @"s/n", @"m/n"];
//    ((FilteredBLEScan *) self.bleScan).excludeFilter = [NSPredicate predicateWithFormat:@"SELF.serialNumber != nil && SELF.modelNumber != nil"];
    
    self.bleScan.sUUID = [CBUUID UUIDWithString:@SERVICE_UUID];
    self.bleScan.delegate = self;
    [self.bleScan doInit];
}

-(void) onReady
{
    if (self.ids) {
        [self.ids removeAllObjects];
    } else {
        self.ids = [[NSMutableArray alloc] init];
    }
    if (self.names) {
        [self.names removeAllObjects];
    } else {
        self.names = [[NSMutableArray alloc] init];
    }
    [self.names insertObject:@"Scanning...." atIndex:0];
    [self.tableView reloadData];
    [self.bleScan doScan:SCAN_TIMEOUT];
}

-(void) onScanDone
{
    NSLog(@"Done Scan");
    [self.names removeAllObjects];
    [self.ids removeAllObjects];
    for(int i = 0; i < self.bleScan.peripherals.count; i++)
    {
        BLEOBject *obj = [self.bleScan.peripherals objectAtIndex:i];

        [self.names insertObject:[NSString stringWithFormat:@"%@ (%@)", obj.name, obj.RSSI] atIndex:0];
        [self.ids insertObject:obj.uuid atIndex:0];
    }
    [self.tableView reloadData];
}


- (void)viewWillAppear:(BOOL)animated {
    self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)doRescan:(id)sender {
    [self onReady];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSString *periName = self.names[indexPath.row];
        NSString *periId = self.ids[indexPath.row];
        DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        [controller setPeripheral:periId peripheralName:periName];
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

- (BOOL) shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    return (0 < self.ids.count);
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.names.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    NSDate *object = self.names[indexPath.row];
    cell.textLabel.text = [object description];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

@end
