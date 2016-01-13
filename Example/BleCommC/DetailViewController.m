//
//  DetailViewController.m
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController ()

@property NSMutableArray *msgs;

@end

@implementation DetailViewController {
}

#pragma mark - Managing the detail item

- (void)setPeripheralName:(id)peripheralName {
    if (_peripheralName != peripheralName) {
        _peripheralName = peripheralName;
            
        // Update the view.
        [self configureView];
    }
}

- (void)setPeripheralId:(id)peripheralId {
    if (_peripheralId != peripheralId) {
        _peripheralId = peripheralId;
        
        [self configureView];
    }
}

-(void) setPeripheral:(id) peripheralId peripheralName:(id)peripheralName {
    if (_peripheralName != peripheralName) {
        _peripheralName = peripheralName;
    }
    if (_peripheralId != peripheralId) {
        _peripheralId = peripheralId;
    }
    [self configureView];
}

- (IBAction)onConnect:(UIButton *)sender {
    [self connectToPeripheral];
}

- (IBAction)onSend:(id)sender {
    [self addMsg:self.msg.text];
    NSLog(@"Sending message : %@", self.msg.text);
    [self.bleComm send:self.msg.text];
}

- (IBAction)onDisconnect:(UIButton *)sender {
    [self disconnectFromPeripheral];
}

- (void)configureView {
    // Update the user interface for the detail item.
    if (self.peripheralName) {
        self.detailDescriptionLabel.text = [self.peripheralName description];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.msgs = [[NSMutableArray alloc] init];
    self.tvMsgs.delegate = self;
    self.tvMsgs.dataSource = self;
    [self configureView];
    [self initPeripheral];
    [self connectToPeripheral];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) initPeripheral
{
    if (!self.bleComm) {
        self.bleComm = [DefaultBLEComm new];
    }
    self.bleComm.delegate = self;
    self.bleComm.deviceId = [[NSUUID alloc] initWithUUIDString:[self.peripheralId description]];
    self.bleComm.sUUID = [CBUUID UUIDWithString:@SERVICE_UUID];
    self.bleComm.tUUID = [CBUUID UUIDWithString:@TX_UUID];
    self.bleComm.rUUID = [CBUUID UUIDWithString:@RX_UUID];
    self.bleComm.fUUID = [CBUUID UUIDWithString:@F_UUID];
    self.bleComm.packetSize = 100;
}

- (void) connectToPeripheral
{
    [self addMsg:@"Connecting"];
    [self.bleComm connect];
}

- (void) disconnectFromPeripheral
{
    [self addMsg:@"Disconnecting"];
    [self.bleComm disconnect];
}

-(void) onConnect
{
    [self addMsg:@"Connected"];
}

-(void) onDisconnect
{
    [self addMsg:@"Disconnected"];
}

-(void) onData:(NSString *) data
{
    NSLog(@"Got message : %@", data);
    [self addMsg:data];
}

-(void) addMsg:(NSString *) msg
{
    [self.msgs insertObject:msg atIndex:0];
    [self.tvMsgs reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.msgs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MsgCell" forIndexPath:indexPath];
    
    NSDate *object = self.msgs[indexPath.row];
    cell.textLabel.text = [object description];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}


@end
