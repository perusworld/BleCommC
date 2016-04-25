//
//  BLE.h
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#ifndef BLE_h
#define BLE_h

#import <CoreBluetooth/CoreBluetooth.h>

#define SIMPLE          "simple"
#define PROTOCOL        "protocol"
#define DEVICE_INFO     "180A"
#define MANU_NAME       "2A29"
#define MODEL_NUM       "2A24"
#define SERIAL_NUM      "2A25"
#define HW_REV          "2A27"
#define FW_REV          "2A26"
#define SW_REV          "2A28"

@protocol ScanDelegate <NSObject>
@optional
-(void) onReady;
-(void) onPoweredOff;
-(void) onScanDone;
@required
@end

@protocol CommDelegate <NSObject>
@optional
-(void) onConnect;
-(void) onDisconnect;
-(void) onData:(NSString *) data;
@required
@end

@protocol BleComm
@optional
-(void) connect;
-(void) send:(NSString *) data;
-(void) writeRawData:(NSData *) data;
-(void) disconnect;
@end

@interface DataHandler : NSObject {
}

@property (nonatomic, weak) id <BleComm> bleComm;
@property (nonatomic, weak) id <CommDelegate> commDelegate;
@property (nonatomic, assign) int packetSize;

-(id) initWith:(id<BleComm>) bleComm commDelegate:(id<CommDelegate>) commDelegate packetSize:(int) packetSize;
-(void) onConnectionFinalized;
-(void) onData:(NSData *)data;
-(void) writeRaw:(NSData *)data;
-(void) writeString:(NSString *)data;

@end

@interface ProtocolDataHandler : DataHandler {
}

-(id) initWith:(id<BleComm>) bleComm commDelegate:(id<CommDelegate>) commDelegate packetSize:(int) packetSize;
-(void) onConnectionFinalized;
-(void) writeString:(NSString *)data;

-(void) pingIn;
-(void) pingOut;
-(void) onDataPacket:(NSData *) data;
@end

@interface BLEOBject : NSObject

@property (strong, nonatomic) CBPeripheral *peripheral;
@property (strong, nonatomic) NSString *uuid;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *manufacturerName;
@property (strong, nonatomic) NSString *modelNumber;
@property (strong, nonatomic) NSString *serialNumber;
@property (strong, nonatomic) NSString *hardwareRevision;
@property (strong, nonatomic) NSString *firmwareRevision;
@property (strong, nonatomic) NSString *softwareRevision;
@property (strong, nonatomic) NSNumber *RSSI;
@property (assign, nonatomic) NSInteger connectionAttempts;

- (BOOL)hasAllDeviceInfo;
- (NSString *)getValue:(CBUUID *) chr;

@end

@interface BLEScan : NSObject <CBCentralManagerDelegate>

@property (strong, nonatomic) NSMutableArray *peripherals;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBUUID *sUUID;
@property (strong, nonatomic) NSTimer *scanTimer;
@property (weak, nonatomic) id <ScanDelegate> delegate;

- (void)doInit;

- (NSInteger)startScan:(NSInteger)timeout;

- (NSInteger)doScan:(NSInteger)timeout;

- (void)scanTimer:(NSTimer *)timer;

-(void)onScanTimeout;
-(void)onDeviceDiscovery:(BLEOBject *) bleObject;

- (void)tearDown;

@end

@interface DeviceInfoBLEScan : BLEScan <CBPeripheralDelegate>

@property (nonatomic) BOOL haltUpdate;
@property (strong, nonatomic) CBUUID *iUUID;
@property (strong, nonatomic) NSArray *characteristics;
@property (strong, nonatomic) NSTimer *connectionTimer;
@property (assign, nonatomic) NSInteger connectionAttempts;

- (void) updateDeviceInfo;
- (void)onDiscoverServices:(CBPeripheral *)peripheral;
- (void)onDiscoverCharacteristics:(CBPeripheral *)peripheral service:(CBService *)service;
- (void)onUpdateCharacteristic:(CBPeripheral *)peripheral bleObject:(BLEOBject *)bleObject;
@end

@interface FilteredBLEScan : DeviceInfoBLEScan
@property (strong, nonatomic) NSPredicate *includeFilter;
@property (strong, nonatomic) NSPredicate *excludeFilter;

@end

@interface DefaultBLEComm : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate, BleComm>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *currentPeripheral;
@property (strong, nonatomic) CBCharacteristic *txCharacteristic;
@property (strong, nonatomic) CBCharacteristic *rxCharacteristic;
@property (strong, nonatomic) CBUUID* sUUID;
@property (strong, nonatomic) CBUUID* tUUID;
@property (strong, nonatomic) CBUUID* rUUID;
@property (strong, nonatomic) CBUUID* fUUID;
@property (nonatomic) int packetSize;
@property (strong, nonatomic) NSUUID* deviceId;
@property (nonatomic, weak) id <CommDelegate> delegate;
@property (strong, nonatomic) NSMutableArray *features;
@property (strong, nonatomic) DataHandler* dataHandler;

@end

#endif /* BLE_h */