//
//  BLE.h
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

static NSString * const kSimpleIdentifier           = @"simple";
static NSString * const kProtocolIdentifier         = @"protocol";
static NSString * const kDeviceInfoIdentifer        = @"180A";
static NSString * const kManufacturerIdentifier     = @"2A29";
static NSString * const kModelNumberIdentifier      = @"2A24";
static NSString * const kSerialNumberIdentifier     = @"2A25";
static NSString * const kHardwareRevisionIdentifier = @"2A27";
static NSString * const kFirmwareRevisionIdentifier = @"2A26";
static NSString * const kSoftwareRevisionIdentifier = @"2A28";

@protocol ScanDelegate <NSObject>

@optional

- (void)onReady;

- (void)onPoweredOff;

- (void)onScanDone;

@end

@protocol CommDelegate <NSObject>

@optional

- (void)onConnect;

- (void)onDisconnect;

- (void)onData:(NSString *)data;

@end

@protocol BleComm

@optional

- (void)connect;

- (void)send:(NSString *)data;

- (void)writeRawData:(NSData *)data;

- (void)disconnect;

@end

@interface DataHandler : NSObject

@property (nonatomic, weak) id <BleComm> bleComm;
@property (nonatomic, weak) id <CommDelegate> commDelegate;
@property (nonatomic, assign) NSInteger packetSize;

- (instancetype)initWith:(id <BleComm>)bleComm commDelegate:(id <CommDelegate>)commDelegate packetSize:(NSInteger)packetSize;

- (void)onConnectionFinalized;

- (void)onData:(NSData *)data;

- (void)writeRaw:(NSData *)data;

- (void)writeString:(NSString *)data;

@end

@interface ProtocolDataHandler : DataHandler

- (instancetype)initWith:(id <BleComm>)bleComm commDelegate:(id <CommDelegate>)commDelegate packetSize:(NSInteger)packetSize;

- (void)onConnectionFinalized;

- (void)writeString:(NSString *)data;

- (void)pingIn;

- (void)pingOut;

- (void)onDataPacket:(NSData *)data;

@end

@interface BLEOBject : NSObject

@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *manufacturerName;
@property (nonatomic, strong) NSString *modelNumber;
@property (nonatomic, strong) NSString *serialNumber;
@property (nonatomic, strong) NSString *hardwareRevision;
@property (nonatomic, strong) NSString *firmwareRevision;
@property (nonatomic, strong) NSString *softwareRevision;
@property (nonatomic, strong) NSNumber *RSSI;
@property (nonatomic, assign) NSInteger connectionAttempts;

@end

@interface BLEScan : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) NSMutableArray *peripherals;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBUUID *sUUID;
@property (nonatomic, strong) CBUUID *iUUID;
@property (nonatomic, strong) NSTimer *scanTimer;
@property (nonatomic, weak) id <ScanDelegate> delegate;
@property (nonatomic, strong) NSTimer *connectionTimer;
@property (nonatomic, assign) NSInteger connectionAttempts;
@property (nonatomic, strong) NSArray *characteristics;
@property (nonatomic, assign) BOOL withDeviceInfo;

- (NSInteger)startScan:(CGFloat)timeout withDeviceInfo:(BOOL)deviceInfo;

- (void)tearDown;

@end

@interface DeviceInfoBLEScan : BLEScan

@property (nonatomic, assign) BOOL haltUpdate;
@property (nonatomic, strong) NSString *modelNumber;
@property (nonatomic, strong) NSString *serialNumber;

- (instancetype)initWithDelegate:(id <ScanDelegate>)delegate andCharacteristics:(NSArray *)characteristics;

@end

@interface DefaultBLEComm : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate, BleComm>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *currentPeripheral;
@property (nonatomic, strong) CBCharacteristic *txCharacteristic;
@property (nonatomic, strong) CBCharacteristic *rxCharacteristic;
@property (nonatomic, strong) CBUUID *sUUID;
@property (nonatomic, strong) CBUUID *tUUID;
@property (nonatomic, strong) CBUUID *rUUID;
@property (nonatomic, strong) CBUUID *fUUID;
@property (nonatomic, assign) NSInteger packetSize;
@property (nonatomic, strong) NSUUID *deviceId;
@property (nonatomic, weak) id <CommDelegate> delegate;
@property (nonatomic, strong) NSMutableArray *features;
@property (nonatomic, strong) DataHandler *dataHandler;

@end