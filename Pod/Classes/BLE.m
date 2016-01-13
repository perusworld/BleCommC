//
//  BLE.m
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BLE.h"

@implementation BLEScan


@synthesize centralManager;
@synthesize peripherals;
@synthesize delegate;

- (void) doInit
{
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

-(int) doScan:(int) timeout
{
    if (self.peripherals) {
        [self.peripherals removeAllObjects];
    } else {
        self.peripherals = [NSMutableArray new];
    }
    
    if (self.centralManager.state != CBCentralManagerStatePoweredOn)
    {
        NSLog(@"CoreBluetooth not correctly initialized !");
        return -1;
    }
    
    [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];
    
    [self.centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:self.sUUID] options:nil];
    
    NSLog(@"scanForPeripheralsWithServices");
    
    return 0;
}

-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"did connect");
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self.delegate onReady];
    } else if (central.state == CBCentralManagerStatePoweredOff) {
        
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    for(int i = 0; i < self.peripherals.count; i++)
    {
        CBPeripheral *p = [self.peripherals objectAtIndex:i];
        
        if ((p.identifier == NULL) || (peripheral.identifier == NULL))
            continue;
        
        if ([p.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString])
        {
            [self.peripherals replaceObjectAtIndex:i withObject:peripheral];
            NSLog(@"Duplicate UUID found updating...");
            return;
        }
    }
    
    [self.peripherals addObject:peripheral];
    
    NSLog(@"New UUID, adding");
    
    NSLog(@"didDiscoverPeripheral");
}

- (void) scanTimer:(NSTimer *)timer
{
    [self.centralManager stopScan];
    NSLog(@"Stopped Scanning");
    [self.delegate onScanDone];
}

@end

@implementation DefaultBLEComm


@synthesize centralManager;
@synthesize currentPeripheral;
@synthesize deviceId;
@synthesize sUUID;
@synthesize tUUID;
@synthesize rUUID;
@synthesize fUUID;
@synthesize delegate;
@synthesize features;
@synthesize dataHandler;

-(id) init
{
    self = [super init];
    if (!self.packetSize) {
        self.packetSize = 100;
    }
    return self;
}

- (void) connect
{
    if (self.centralManager) {
        if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
            [self continueConnection];
        }
    } else {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
}

- (void) send:(NSString *)data
{
    NSLog(@"Sending message");
    [self sendData:data];
}

- (void) disconnect
{
    [self.centralManager cancelPeripheralConnection:self.currentPeripheral];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self continueConnection];
    } else if (central.state == CBCentralManagerStatePoweredOff) {
    }
}

- (void)continueConnection
{
    if (deviceId) {
        NSArray *peripheralArray = [centralManager retrievePeripheralsWithIdentifiers:@[deviceId]];
        
        if(1 == [peripheralArray count])
        {
            NSLog(@"Connecting to Peripheral - %@", peripheralArray[0]);
            [self connectPeripheral:peripheralArray[0]];
        }
    }
}

- (void) connectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connecting to peripheral with UUID : %@", peripheral.identifier.UUIDString);
    
    self.currentPeripheral = peripheral;
    self.currentPeripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral
                       options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (peripheral.identifier != NULL)
        NSLog(@"Connected to %@ successful", peripheral.identifier.UUIDString);
    else
        NSLog(@"Connected to NULL successful");
    
    self.currentPeripheral = peripheral;
    [self.currentPeripheral discoverServices:@[self.sUUID]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self preDisconnected];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error)
    {
        for (int i=0; i < peripheral.services.count; i++)
        {
            CBService *s = [peripheral.services objectAtIndex:i];
            if ([s.UUID isEqual:self.sUUID]) {
                [peripheral discoverCharacteristics:nil forService:s];
            }
        }
    }
    else
    {
        NSLog(@"Service discovery was unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error)
    {
        for (int i=0; i < service.characteristics.count; i++)
        {
            CBCharacteristic *ch = service.characteristics[i];
            if ([ch.UUID isEqual:self.rUUID]) {
                self.rxCharacteristic = ch;
                NSLog(@"Got rxChr");
            } else if ([ch.UUID isEqual:self.tUUID]) {
                self.txCharacteristic = ch;
                NSLog(@"Got txChr");
            }
        }
        if (nil != self.rxCharacteristic && nil != self.txCharacteristic) {
            [peripheral setNotifyValue:true forCharacteristic:self.rxCharacteristic];
            [peripheral discoverDescriptorsForCharacteristic:self.rxCharacteristic];
        }
    }
    else
    {
        NSLog(@"Characteristic discorvery unsuccessful!");
    }
}

 - (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (!error) {
        for (int index=0; index < characteristic.descriptors.count; index++) {
            if ([characteristic.descriptors[index].UUID isEqual:self.fUUID]) {
                [peripheral readValueForDescriptor:characteristic.descriptors[index]];
            }
        }
    } else {
        NSLog(@"Descriptors discorvery unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    if (!error) {
        NSString *stringFromData = [[NSString alloc] initWithData:descriptor.value encoding:NSUTF8StringEncoding];
        NSLog(@"The String is %@", stringFromData);
        if (self.features) {
            [self.features removeAllObjects];
        } else {
            self.features = [[NSMutableArray alloc] init];
        }
        if (0 == [stringFromData length]) {
            [self.features addObject:@SIMPLE];
        } else {
            [self.features addObjectsFromArray:[stringFromData componentsSeparatedByString:@","]];
        }
        [self postConnection];
    } else {
        NSLog(@"Descriptor update value unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (!error)
    {
        if (self.dataHandler) {
            [self.dataHandler onData:characteristic.value];
        }
    }
    else
    {
        NSLog(@"updateValueForCharacteristic failed!");
    }
}

- (void) sendData:(NSString *) data
{
    if (self.dataHandler) {
        [self.dataHandler writeString:data];
    }
}

- (void) preDisconnected
{
    [self.delegate onDisconnect];
}

- (void) postConnection
{
    if (!self.dataHandler) {
        if ([self.features containsObject:@SIMPLE]) {
            self.dataHandler = [[DataHandler alloc] initWith:self commDelegate:self.delegate packetSize:self.packetSize];
        } else if ([self.features containsObject:@PROTOCOL]) {
            self.dataHandler = [[ProtocolDataHandler alloc] initWith:self commDelegate:self.delegate packetSize:self.packetSize];
        } else {
            NSLog(@"Unsupported data handler");
        }
    }
    if (self.dataHandler) {
        [self.dataHandler onConnectionFinalized];
    }
}

-(void) writeRawData:(NSData *)data
{
    if (self.txCharacteristic) {
        [self.currentPeripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

@end


@implementation DataHandler


-(id) initWith:(id<BleComm>) bleComm commDelegate:(id<CommDelegate>) commDelegate packetSize:(int)packetSize
{
    self = [super init];
    
    self.bleComm = bleComm;
    self.commDelegate = commDelegate;
    self.packetSize = packetSize;
    
    return self;
}

-(void) onConnectionFinalized
{
    [self.commDelegate onConnect];
}

-(void) onData:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.commDelegate onData:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    });
}

-(void) writeRaw:(NSData *)data
{
    int dataLength = data.length;
    int limit = self.packetSize;
    
    if (dataLength <= limit) {
        [self.bleComm writeRawData:data];
    } else {
        int len = limit;
        int loc = 0;
        int idx = 0;
        while (loc < dataLength) {
            
            int rmdr = dataLength - loc;
            
            if (rmdr <= len) {
                len = rmdr;
            }
            
            NSRange range = NSMakeRange(loc, len);
            UInt8 newBytes[len];
            [data getBytes:&newBytes range:range];
            [self.bleComm writeRawData:[[NSData alloc] initWithBytes:newBytes length:len]];
            loc += len;
            idx += 1;
        }
    }
}

-(void) writeString:(NSString *)data
{
    [self writeRaw:[[NSData alloc] initWithBytes:data.UTF8String length:data.length]];
}

@end


@implementation ProtocolDataHandler {
    NSData *pingOutData;
    bool insync;
    NSMutableData *chunkedData;
    UInt8 dataLength;
}

static UInt8  PingIn = 0xCC;
static UInt8  PingOut = 0xDD;
static UInt8  Data =  0xEE;
static UInt8  ChunkedDataStart = 0xEB;
static UInt8  ChunkedData = 0xEC;
static UInt8  ChunkedDataEnd = 0xED;
static UInt8  EOMFirst = 0xFE;
static UInt8  EOMSecond = 0xFF;
static UInt8  cmdLength = 3;



-(id) initWith:(id<BleComm>) bleComm commDelegate:(id<CommDelegate>) commDelegate packetSize:(int)packetSize
{
    self = [super initWith:bleComm commDelegate:commDelegate packetSize:packetSize];
    pingOutData = [[NSData alloc] initWithBytes:(unsigned char[]){PingOut, EOMFirst, EOMSecond} length:3];
    insync = false;
    dataLength = packetSize - cmdLength;
    return self;
}

-(void) onConnectionFinalized
{
    insync = false;
}

-(void) pingIn
{
    [self writeRaw:pingOutData];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.commDelegate onConnect];
    });
    
}

-(void) pingOut
{
    //NOOP
}

-(void) onDataPacket:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.commDelegate onData:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    });
}

-(void) onData:(NSData *)newData
{
    UInt8 data[newData.length];
    UInt8 len = newData.length;
    NSData *msgData;
    [newData getBytes:data length:len];
    if (cmdLength < len) {
        UInt8 msg[len - cmdLength];
        for (int index=1; index<= len-cmdLength; index++) {
            msg[index - 1] = data[index];
        }
        msgData = [[NSData alloc] initWithBytes:msg length:len-cmdLength];
        
    }
    if (EOMFirst == data[len - 2] && EOMSecond == data[len - 1]) {
        if (data[0] == PingIn) {
            [self pingIn];
        } else if (data[0] == PingOut) {
            [self pingOut];
        } else if (data[0] == PingOut) {
            [self pingOut];
        } else if (data[0] == Data) {
            [self onDataPacket:msgData];
        } else if (data[0] == ChunkedDataStart) {
            chunkedData = [[NSMutableData alloc] init];
            [chunkedData appendData:msgData];
        } else if (data[0] == ChunkedData) {
            [chunkedData appendData:msgData];
        } else if (data[0] == ChunkedDataEnd) {
            [chunkedData appendData:msgData];
            [self onDataPacket:chunkedData];
        } else {
            //Unknown
        }
    }}

-(void) writeString:(NSString *)string
{
    NSMutableData *data = [[NSMutableData alloc] init];
    if (dataLength < string.length) {
        int toIndex = 0;
        UInt8 dataMarker = ChunkedData;
        for (int index = 0; index < string.length; index = index + dataLength) {
            [data setLength:0];
            toIndex = MIN(index + dataLength, string.length);
            NSString *chunk = [string substringWithRange:NSMakeRange(index, toIndex-index)];
            dataMarker = (index == 0) ? ChunkedDataStart : (toIndex == string.length ? ChunkedDataEnd : ChunkedData);
            [data appendBytes:(unsigned char[]){dataMarker} length:1];
            [data appendBytes:chunk.UTF8String length:chunk.length];
            [data appendBytes:(unsigned char[]){EOMFirst, EOMSecond} length:2];
            [self writeRaw:data];
        }
    } else {
        [data appendBytes:(unsigned char[]){Data} length:1];
        [data appendBytes:string.UTF8String length:string.length];
        [data appendBytes:(unsigned char[]){EOMFirst, EOMSecond} length:2];
        [self writeRaw:data];
    }
}

@end
