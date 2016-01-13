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

@protocol ScanDelegate
@optional
-(void) onReady;
-(void) onScanDone;
@required
@end

@protocol CommDelegate
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

@property id<BleComm> bleComm;
@property id<CommDelegate> commDelegate;
@property (nonatomic) int packetSize;

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

@interface BLEScan : NSObject <CBCentralManagerDelegate> {
    
}

@property (strong, nonatomic) NSMutableArray *peripherals;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBUUID* sUUID;
@property (nonatomic,assign) id <ScanDelegate> delegate;

-(void) doInit;
-(int) doScan:(int) timeout;

-(void) scanTimer:(NSTimer *)timer;

@end

@interface DefaultBLEComm : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate, BleComm> {
}

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
@property (nonatomic,assign) id <CommDelegate> delegate;
@property (strong, nonatomic) NSMutableArray *features;
@property (strong, nonatomic) DataHandler* dataHandler;

@end

#endif /* BLE_h */
