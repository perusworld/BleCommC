//
//  BLE.m
//  VendLib
//
//  Created by Saravana Shanmugam on 06/01/2016.
//  Copyright © 2016 Saravana Shanmugam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLE.h"

static const NSInteger kMaxConnectionAttempts   = 3;
static const CGFloat kConnectionTimeout         = 5.0f;

@implementation BLEOBject

-(BOOL) hasAllDeviceInfo
{
    return (self.manufacturerName && self.modelNumber && self.serialNumber && self.hardwareRevision && self.firmwareRevision && self.softwareRevision);
}

-(NSString *) getValue:(CBUUID *)chr
{
    NSString * ret = nil;
    NSString * chrId = [chr UUIDString];
    if ([chrId isEqualToString:@MANU_NAME]) {
        ret = self.manufacturerName;
    } else if ([chrId isEqualToString:@MODEL_NUM]) {
        ret = self.modelNumber;
    } else if ([chrId isEqualToString:@SERIAL_NUM]) {
        ret = self.serialNumber;
    } else if ([chrId isEqualToString:@FW_REV]) {
        ret = self.firmwareRevision;
    } else if ([chrId isEqualToString:@HW_REV]) {
        ret = self.hardwareRevision;
    } else if ([chrId isEqualToString:@SW_REV]) {
        ret = self.softwareRevision;
    }

    return ret;
}

@end

@implementation BLEScan

@synthesize centralManager;
@synthesize peripherals;
@synthesize delegate;

#pragma mark - LifeCycle

- (void)doInit
{
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

}

#pragma mark - PublicMethods

- (NSInteger)startScan:(int)timeout
{
    if (self.peripherals) {
        [self.peripherals removeAllObjects];
    } else {
        self.peripherals = [NSMutableArray new];
    }
    
    if (self.centralManager.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"BLE: CoreBluetooth not correctly initialized!");
        
        return -1;
    }
    
    if (self.sUUID) {
        [self.centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:self.sUUID] options:nil];
        self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];
    } else {
        return -1;
    }
    
    NSLog(@"BLE: ScanForPeripheralsWithServices");
    
    return 0;
}

- (NSInteger)doScan:(NSInteger)timeout
{
    return [self startScan:timeout];
}

#pragma mark - PrivateMethods

- (void)scanTimer:(NSTimer *)timer
{
    [self onScanTimeout];
}

-(void) onScanTimeout
{
    [self.centralManager stopScan];
    
    NSLog(@"BLE: Stopped Scanning");
    
    if ([self.delegate respondsToSelector:@selector(onScanDone)]) {
        [self.delegate onScanDone];
    }
}

- (void)tearDown
{
    [self.scanTimer invalidate];
    self.scanTimer = nil;
    
    [self.centralManager stopScan];
    
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        if ([self.delegate respondsToSelector:@selector(onReady)]) {
            [self.delegate onReady];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(onPoweredOff)]) {
            [self.delegate onPoweredOff];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.peripheral.identifier.UUIDString == %@", peripheral.identifier.UUIDString];
    BLEOBject *obj = [[self.peripherals filteredArrayUsingPredicate:predicate] firstObject];
    
    if (obj) {
        NSLog(@"BLE: Duplicate UUID found updating: %@", peripheral);
        
        obj.peripheral = peripheral;
        obj.uuid = peripheral.identifier.UUIDString;
        obj.name = peripheral.name;
        obj.RSSI = RSSI;
    } else {
        NSLog(@"BLE: New device found: %@", peripheral);
        
        obj = [BLEOBject new];
        obj.peripheral = peripheral;
        obj.uuid = peripheral.identifier.UUIDString;
        obj.name = peripheral.name;
        obj.RSSI = RSSI;
        obj.connectionAttempts = 0;
        [self.peripherals addObject:obj];
        [self onDeviceDiscovery:obj];
    }
}

-(void) onDeviceDiscovery:(BLEOBject *)bleObject
{
}

@end

@implementation DeviceInfoBLEScan

@synthesize characteristics;

#pragma mark - LifeCycle

- (void)doInit
{
    [super doInit];
    self.iUUID = [CBUUID UUIDWithString:@DEVICE_INFO];
    if (self.characteristics) {
        //NOOP
    } else {
        self.characteristics = @[[CBUUID UUIDWithString:@MANU_NAME], [CBUUID UUIDWithString:@MODEL_NUM], [CBUUID UUIDWithString:@SERIAL_NUM],[CBUUID UUIDWithString:@HW_REV], [CBUUID UUIDWithString:@FW_REV], [CBUUID UUIDWithString:@SW_REV]];
    }
    
    if (!self.connectionAttempts) {
        self.connectionAttempts = kMaxConnectionAttempts;
    }
}

-(NSInteger) startScan:(int)timeout {
    _haltUpdate = NO;
    return [super startScan:timeout];
}

- (void)connectPeripheral:(BLEOBject *)obj
{
    NSLog(@"BLE: Connecting to peripheral with UUID : %@", obj.peripheral.identifier.UUIDString);
    
    obj.connectionAttempts++;
    
    if (obj.connectionAttempts <= self.connectionAttempts) {
        
        obj.peripheral.delegate = self;
        [self.centralManager connectPeripheral:obj.peripheral
                                       options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
        
        if (self.connectionTimer != nil) {
            [self.connectionTimer invalidate];
            self.connectionTimer = nil;
        }
        
        self.connectionTimer = [NSTimer scheduledTimerWithTimeInterval:kConnectionTimeout target:self selector:@selector(connectionTimeOut:) userInfo:obj repeats:NO];
    } else {
        NSLog(@"BLE: Max connection attempts for this device");
        [self.centralManager cancelPeripheralConnection:obj.peripheral];
        
        [self updateDeviceInfo];
    }
}

- (void) updateDeviceInfo
{
    BOOL done = TRUE;
    
    if (!_haltUpdate) {
        for (int index = 0; index < self.peripherals.count; index++) {
            
            BLEOBject *obj = [self.peripherals objectAtIndex:index];
            
            if (![obj hasAllDeviceInfo] && obj.connectionAttempts < self.connectionAttempts) {
                done = FALSE;
                [self connectPeripheral:obj];
                
                break;
            }
        }
    }
    if (done) {
        if ([self.delegate respondsToSelector:@selector(onScanDone)]) {
            [self.delegate onScanDone];
        }
    }
}

-(void) onScanTimeout
{
    [self.centralManager stopScan];
    
    NSLog(@"BLE: Stopped Scanning");
    
    //AW - Sort by RSSI so closest devices get scanned first
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"RSSI" ascending:NO];
    self.peripherals = [[NSMutableArray alloc] initWithArray:[self.peripherals sortedArrayUsingDescriptors:@[sortDescriptor]]];
    [self updateDeviceInfo];
}

/*
 * AW - The CBCentralManager's scanning/connecting will keep this object alive and delay dealloc. Stop scanning and cancel all connections.
 */

- (void)tearDown
{
    [super tearDown];
    for (BLEOBject *device in self.peripherals) {
        if (device.peripheral.state == CBPeripheralStateConnecting || device.peripheral.state == CBPeripheralStateConnected) {
            [self.centralManager cancelPeripheralConnection:device.peripheral];
        }
    }
}

- (void)connectionTimeOut:(NSTimer *)timer
{
    [self.connectionTimer invalidate];
    self.connectionTimer = nil;
    
    BLEOBject *object = timer.userInfo;
    object.connectionAttempts = kMaxConnectionAttempts;
    
    if (object.peripheral.state == CBPeripheralStateConnecting) {
        [self.centralManager cancelPeripheralConnection:object.peripheral];
    }
    
    [self updateDeviceInfo];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (self.connectionTimer != nil) {
        [self.connectionTimer invalidate];
        self.connectionTimer = nil;
    }
    
    if (peripheral.identifier != NULL) {
        NSLog(@"BLE: Connected to %@ successful, scanning for device info", peripheral.identifier.UUIDString);
    } else {
        NSLog(@"BLE: Connected to NULL successful");
    }
    
    if (self.iUUID) {
        [peripheral discoverServices:@[self.iUUID]];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"BLE: Did disconnect");
    [self updateDeviceInfo];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (self.connectionTimer != nil) {
        [self.connectionTimer invalidate];
        self.connectionTimer = nil;
    }
    
    NSLog(@"BLE: Did fail to connect");
    [self updateDeviceInfo];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error) {
        [self onDiscoverServices:peripheral];
    } else {
        NSLog(@"BLE: Service discovery was unsuccessful!");
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

-(void) onDiscoverServices:(CBPeripheral *)peripheral
{
    
    for (int index = 0; index < peripheral.services.count; index++) {
        
        CBService *service = [peripheral.services objectAtIndex:index];
        
        if ([service.UUID isEqual:self.iUUID]) {
            //AW - Due to some devices taking a long time to discover services, only request what's needed. Apple docs stress this point.
            [peripheral discoverCharacteristics:self.characteristics forService:service];
        }
    }

}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error) {
        [self onDiscoverCharacteristics:peripheral service:service];
    } else {
        NSLog(@"BLE: Characteristic discorvery unsuccessful!");
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

-(void) onDiscoverCharacteristics:(CBPeripheral *)peripheral service:(CBService *)service
{
    for (int index = 0; index < service.characteristics.count; index++) {
        CBCharacteristic *characteristic = service.characteristics[index];
        if ([self.characteristics containsObject:characteristic.UUID]) {
            [peripheral readValueForCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    BLEOBject *currentObject = [[self.peripherals filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.peripheral == %@", peripheral]] firstObject];
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@MANU_NAME]]) {
        currentObject.manufacturerName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@MODEL_NUM]]) {
        currentObject.modelNumber = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@SERIAL_NUM]]) {
        currentObject.serialNumber = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@HW_REV]]) {
        currentObject.hardwareRevision = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@FW_REV]]) {
        currentObject.firmwareRevision = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@SW_REV]]) {
        currentObject.softwareRevision= [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    }
    
    [self onUpdateCharacteristic:peripheral bleObject:currentObject];
    
}

-(void) onUpdateCharacteristic:(CBPeripheral *)peripheral bleObject:(BLEOBject *)bleObject
{
    BOOL found = YES;
    for (int index = 0; index < characteristics.count; index++) {
        if ([bleObject getValue:characteristics[index]]) {
            continue;
        } else {
            found = NO;
            break;
        }
    }
    if (found) {
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

@end

@implementation FilteredBLEScan

@synthesize includeFilter;
@synthesize excludeFilter;

-(void) onUpdateCharacteristic:(CBPeripheral *)peripheral bleObject:(BLEOBject *)bleObject
{
    if ([includeFilter evaluateWithObject:bleObject]) {
        NSLog(@"BLE: Device we are looking for has been found");
        self.haltUpdate = YES;
        [self.centralManager cancelPeripheralConnection:peripheral];
        [self.centralManager stopScan];
        [self.scanTimer invalidate];
        self.scanTimer = nil;
    } else if ([excludeFilter evaluateWithObject:bleObject]) {
        NSLog(@"BLE: Excluding device %@", bleObject.name);
        bleObject.connectionAttempts = kMaxConnectionAttempts;
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
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
        
        if (1 == [peripheralArray count])
        {
            NSLog(@"Connecting to Peripheral - %@", peripheralArray[0]);
            [self connectPeripheral:peripheralArray[0]];
        }
    }
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connecting to peripheral with UUID : %@", peripheral.identifier.UUIDString);
    
    self.currentPeripheral = peripheral;
    self.currentPeripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral
                                   options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (peripheral.identifier != NULL) {
        NSLog(@"Connected to %@ successful", peripheral.identifier.UUIDString);
    } else {
        NSLog(@"Connected to NULL successful");
    }
    
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
        for (int i = 0; i < peripheral.services.count; i++)
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
    if ([self.delegate respondsToSelector:@selector(onDisconnect)]) {
        [self.delegate onDisconnect];
    }
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
    if ([self.commDelegate respondsToSelector:@selector(onConnect)]) {
        [self.commDelegate onConnect];
    }
}

-(void) onData:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.commDelegate respondsToSelector:@selector(onData:)]) {
            [self.commDelegate onData:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        }
    });
}

-(void) writeRaw:(NSData *)data
{
    int dataLength = (int) data.length;
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
        if ([self.commDelegate respondsToSelector:@selector(onConnect)]) {
            [self.commDelegate onConnect];
        }
    });
    
}

-(void) pingOut
{
    //NOOP
}

-(void) onDataPacket:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.commDelegate respondsToSelector:@selector(onData:)]) {
            [self.commDelegate onData:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        }
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
            toIndex = (int)MIN(index + dataLength, string.length);
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