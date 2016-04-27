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

@end

@implementation BLEScan

#pragma mark - LifeCycle

- (instancetype)init
{
    if (self = [super init]) {
        
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        self.iUUID = [CBUUID UUIDWithString:kDeviceInfoIdentifer];
        self.characteristics = @[[CBUUID UUIDWithString:kManufacturerIdentifier], [CBUUID UUIDWithString:kModelNumberIdentifier], [CBUUID UUIDWithString:kSerialNumberIdentifier],[CBUUID UUIDWithString:kHardwareRevisionIdentifier], [CBUUID UUIDWithString:kFirmwareRevisionIdentifier], [CBUUID UUIDWithString:kSoftwareRevisionIdentifier]];
        
        if (!self.connectionAttempts) {
            self.connectionAttempts = kMaxConnectionAttempts;
        }
        
        self.peripherals = [NSMutableArray array];
    }
    
    return self;
}

#pragma mark - PublicMethods

/*
 * AW - deviceInfo parameter defines whether or not the scan will include device service discover
 */

- (NSInteger)startScan:(CGFloat)timeout withDeviceInfo:(BOOL)deviceInfo
{
    self.withDeviceInfo = deviceInfo;
    
    [self.peripherals removeAllObjects];
    
    if (self.centralManager.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"BLE: CoreBluetooth not correctly initialized!");
        
        return -1;
    }
    
    if (self.sUUID) {
        [self.centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:self.sUUID] options:nil];
        self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];
    } else {
        return -1;
    }
    
    NSLog(@"BLE: ScanForPeripheralsWithServices");
    
    return 0;
}

/*
 * AW - The CBCentralManager's scanning/connecting will keep this object alive and delay dealloc. Stop scanning and cancel all connections.
 */

- (void)tearDown
{
    [self.scanTimer invalidate];
    self.scanTimer = nil;
    
    [self.centralManager stopScan];
    
    for (BLEOBject *device in self.peripherals) {
        if (device.peripheral.state == CBPeripheralStateConnecting || device.peripheral.state == CBPeripheralStateConnected) {
            [self.centralManager cancelPeripheralConnection:device.peripheral];
        }
    }
}

#pragma mark - PrivateMethods

- (void)connectPeripheral:(BLEOBject *)obj
{
    NSLog(@"BLE: Connecting to peripheral with UUID : %@", obj.peripheral.identifier.UUIDString);
    
    obj.connectionAttempts++;
    
    if (obj.connectionAttempts <= self.connectionAttempts) {
        
        obj.peripheral.delegate = self;
        
        [self.centralManager connectPeripheral:obj.peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
        
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

- (void)updateDeviceInfo
{
    BOOL done = TRUE;
    
    for (int i = 0; i < self.peripherals.count; i++) {
        
        BLEOBject *object = [self.peripherals objectAtIndex:i];
        
        if (!object.serialNumber && object.connectionAttempts < self.connectionAttempts) {
            done = FALSE;
            [self connectPeripheral:object];
            
            break;
        }
    }
    
    if (done) {
        if ([self.delegate respondsToSelector:@selector(onScanDone)]) {
            [self.delegate onScanDone];
        }
    }
}

- (void)scanTimer:(NSTimer *)timer
{
    NSLog(@"BLE: Stopped Scanning");
    
    [self.centralManager stopScan];
    
    if (self.withDeviceInfo) {
        //AW - Sort by RSSI so closest devices get scanned first
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"RSSI" ascending:NO];
        self.peripherals = [[NSMutableArray alloc] initWithArray:[self.peripherals sortedArrayUsingDescriptors:@[sortDescriptor]]];
        [self updateDeviceInfo];
    } else {
        if ([self.delegate respondsToSelector:@selector(onScanDone)]) {
            [self.delegate onScanDone];
        }
    }
}

- (void)connectionTimeOut:(NSTimer *)timer
{
    if (timer.userInfo != nil) {
        BLEOBject *object = timer.userInfo;
        object.connectionAttempts = self.connectionAttempts;
        
        if (object.peripheral.state == CBPeripheralStateConnecting) {
            [self.centralManager cancelPeripheralConnection:object.peripheral];
        }
    }
    
    [self.connectionTimer invalidate];
    self.connectionTimer = nil;
    
    [self updateDeviceInfo];
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
        
        if (self.withDeviceInfo) {
            [self connectPeripheral:obj];
        }
    }
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

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error) {
        
        for (int i = 0; i < peripheral.services.count; i++) {
            
            CBService *service = [peripheral.services objectAtIndex:i];
            
            if ([service.UUID isEqual:self.iUUID]) {
                //AW - Due to some devices taking a long time to discover services, only request what's needed. Apple docs stress this point.
                [peripheral discoverCharacteristics:self.characteristics forService:service];
            }
        }
    } else {
        NSLog(@"BLE: Service discovery was unsuccessful!");
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error) {
        for (int i = 0; i < service.characteristics.count; i++) {
            CBCharacteristic *characteristic = service.characteristics[i];
            
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kManufacturerIdentifier]]) {
                [peripheral readValueForCharacteristic:characteristic];
            } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kModelNumberIdentifier]]) {
                [peripheral readValueForCharacteristic:characteristic];
            } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSerialNumberIdentifier]]) {
                [peripheral readValueForCharacteristic:characteristic];
            } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kHardwareRevisionIdentifier]]) {
                [peripheral readValueForCharacteristic:characteristic];
            } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kFirmwareRevisionIdentifier]]) {
                [peripheral readValueForCharacteristic:characteristic];
            } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSoftwareRevisionIdentifier]]) {
                [peripheral readValueForCharacteristic:characteristic];
            }
        }
    } else {
        NSLog(@"BLE: Characteristic discorvery unsuccessful!");
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    BLEOBject *currentObject = [[self.peripherals filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.peripheral == %@", peripheral]] firstObject];
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kManufacturerIdentifier]]) {
        currentObject.manufacturerName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kModelNumberIdentifier]]) {
        currentObject.modelNumber = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSerialNumberIdentifier]]) {
        currentObject.serialNumber = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kHardwareRevisionIdentifier]]) {
        currentObject.hardwareRevision = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kFirmwareRevisionIdentifier]]) {
        currentObject.firmwareRevision = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSoftwareRevisionIdentifier]]) {
        currentObject.softwareRevision= [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    }
}

@end

/*
 * AW - Only search for devices with certain characteristics. Speeds up search time.
 */

@implementation DeviceInfoBLEScan

#pragma mark - LifeCycle

- (instancetype)initWithDelegate:(id <ScanDelegate>)delegate andCharacteristics:(NSArray *)characteristics
{
    if (self = [super init]) {
        self.delegate = delegate;
        self.characteristics = characteristics;
    }
    
    return self;
}

#pragma mark - PrivateMethods

- (BOOL)hasDeviceBeenFound
{
    if ([[self.peripherals filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.serialNumber == %@ && SELF.modelNumber == %@", self.serialNumber, self.modelNumber]] count]) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    [super peripheral:peripheral didUpdateValueForCharacteristic:characteristic error:error];
    
    BLEOBject *currentObject = [[self.peripherals filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.peripheral == %@", peripheral]] firstObject];
    
    if ([self hasDeviceBeenFound]) {
        NSLog(@"BLE: Device we are looking for has been found");
        [self.centralManager cancelPeripheralConnection:peripheral];
        [self.centralManager stopScan];
        [self.scanTimer invalidate];
        self.scanTimer = nil;
        
        if ([self.delegate respondsToSelector:@selector(onScanDone)]) {
            [self.delegate onScanDone];
        }
        
        return;
    }
    
    //AW - when we have the device details, disconnect and if not the device we're looking for, mark connectAttempts as full so we won't connect again.
    if (currentObject.modelNumber && currentObject.serialNumber) {
        [self.centralManager cancelPeripheralConnection:peripheral];
        
        if (self.serialNumber && self.modelNumber && ![currentObject.modelNumber isEqualToString:self.modelNumber] && ![currentObject.serialNumber isEqualToString:self.serialNumber]) {
            currentObject.connectionAttempts = self.connectionAttempts;
        }
    }
}

@end

@implementation DefaultBLEComm

- (instancetype)init
{
    if (self = [super init]) {
        self.packetSize = 100;
    }
    
    return self;
}

- (void)connect
{
    if (self.centralManager) {
        if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
            [self continueConnection];
        }
    } else {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
}

- (void)send:(NSString *)data
{
    NSLog(@"BLE: Sending message");
    [self sendData:data];
}

- (void)disconnect
{
    [self.centralManager cancelPeripheralConnection:self.currentPeripheral];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self continueConnection];
    }
}

- (void)continueConnection
{
    if (self.deviceId) {
        NSArray *peripheralArray = [self.centralManager retrievePeripheralsWithIdentifiers:@[self.deviceId]];
        
        if (1 == [peripheralArray count]) {
            NSLog(@"BLE: Connecting to Peripheral - %@", peripheralArray[0]);
            [self connectPeripheral:peripheralArray[0]];
        }
    }
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"BLE: Connecting to peripheral with UUID : %@", peripheral.identifier.UUIDString);
    
    self.currentPeripheral = peripheral;
    self.currentPeripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (peripheral.identifier != NULL) {
        NSLog(@"BLE: Connected to %@ successful", peripheral.identifier.UUIDString);
    } else {
        NSLog(@"BLE: Connected to NULL successful");
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
    if (!error) {
        
        for (int i = 0; i < peripheral.services.count; i++) {
            
            CBService *s = [peripheral.services objectAtIndex:i];
            
            if ([s.UUID isEqual:self.sUUID]) {
                [peripheral discoverCharacteristics:nil forService:s];
            }
        }
    } else {
        NSLog(@"BLE: Service discovery was unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error) {
        
        for (int i = 0; i < service.characteristics.count; i++) {
            CBCharacteristic *ch = service.characteristics[i];
            
            if ([ch.UUID isEqual:self.rUUID]) {
                self.rxCharacteristic = ch;
                NSLog(@"BLE: Got rxChr");
            } else if ([ch.UUID isEqual:self.tUUID]) {
                self.txCharacteristic = ch;
                NSLog(@"BLE: Got txChr");
            }
        }
        if (nil != self.rxCharacteristic && nil != self.txCharacteristic) {
            [peripheral setNotifyValue:true forCharacteristic:self.rxCharacteristic];
            [peripheral discoverDescriptorsForCharacteristic:self.rxCharacteristic];
        }
    } else {
        NSLog(@"BLE: Characteristic discorvery unsuccessful!");
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
        NSLog(@"BLE: Descriptors discorvery unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    if (!error) {
        NSString *stringFromData = [[NSString alloc] initWithData:descriptor.value encoding:NSUTF8StringEncoding];
        NSLog(@"BLE: The String is %@", stringFromData);
        if (self.features) {
            [self.features removeAllObjects];
        } else {
            self.features = [[NSMutableArray alloc] init];
        }
        if (0 == [stringFromData length]) {
            [self.features addObject:kSimpleIdentifier];
        } else {
            [self.features addObjectsFromArray:[stringFromData componentsSeparatedByString:@","]];
        }
        [self postConnection];
    } else {
        NSLog(@"BLE: Descriptor update value unsuccessful!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (!error) {
        if (self.dataHandler) {
            [self.dataHandler onData:characteristic.value];
        }
    } else {
        NSLog(@"BLE: updateValueForCharacteristic failed!");
    }
}

- (void)sendData:(NSString *)data
{
    if (self.dataHandler) {
        [self.dataHandler writeString:data];
    }
}

- (void)preDisconnected
{
    if ([self.delegate respondsToSelector:@selector(onDisconnect)]) {
        [self.delegate onDisconnect];
    }
}

- (void)postConnection
{
    if (!self.dataHandler) {
        if ([self.features containsObject:kSimpleIdentifier]) {
            self.dataHandler = [[DataHandler alloc] initWith:self commDelegate:self.delegate packetSize:self.packetSize];
        } else if ([self.features containsObject:kProtocolIdentifier]) {
            self.dataHandler = [[ProtocolDataHandler alloc] initWith:self commDelegate:self.delegate packetSize:self.packetSize];
        } else {
            NSLog(@"BLE: Unsupported data handler");
        }
    }
    
    if (self.dataHandler) {
        [self.dataHandler onConnectionFinalized];
    }
}

- (void)writeRawData:(NSData *)data
{
    if (self.txCharacteristic) {
        [self.currentPeripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

@end

@implementation DataHandler

- (id)initWith:(id <BleComm>) bleComm commDelegate:(id<CommDelegate>) commDelegate packetSize:(NSInteger)packetSize
{
    if (self = [super init]) {
        self.bleComm = bleComm;
        self.commDelegate = commDelegate;
        self.packetSize = packetSize;
    }
    
    return self;
}

- (void)onConnectionFinalized
{
    if ([self.commDelegate respondsToSelector:@selector(onConnect)]) {
        [self.commDelegate onConnect];
    }
}

- (void)onData:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.commDelegate respondsToSelector:@selector(onData:)]) {
            [self.commDelegate onData:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        }
    });
}

- (void)writeRaw:(NSData *)data
{
    NSInteger dataLength = (int) data.length;
    NSInteger limit = self.packetSize;
    
    if (dataLength <= limit) {
        [self.bleComm writeRawData:data];
    } else {
        NSInteger len = limit;
        NSInteger loc = 0;
        NSInteger idx = 0;
        
        while (loc < dataLength) {
            NSInteger rmdr = dataLength - loc;
            
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

- (void)writeString:(NSString *)data
{
    [self writeRaw:[[NSData alloc] initWithBytes:data.UTF8String length:data.length]];
}

@end

@interface ProtocolDataHandler ()

@property (nonatomic, strong) NSData *pingOutData;
@property (nonatomic, assign) BOOL insync;
@property (nonatomic, strong) NSMutableData *chunkedData;
@property (nonatomic, assign) UInt8 dataLength;

@end

@implementation ProtocolDataHandler

static UInt8 const PingIn = 0xCC;
static UInt8 const PingOut = 0xDD;
static UInt8 const Data =  0xEE;
static UInt8 const ChunkedDataStart = 0xEB;
static UInt8 const ChunkedData = 0xEC;
static UInt8 const ChunkedDataEnd = 0xED;
static UInt8 const EOMFirst = 0xFE;
static UInt8 const EOMSecond = 0xFF;
static UInt8 const cmdLength = 3;

- (instancetype)initWith:(id <BleComm>)bleComm commDelegate:(id <CommDelegate>)commDelegate packetSize:(NSInteger)packetSize
{
    if (self = [super initWith:bleComm commDelegate:commDelegate packetSize:packetSize]) {
        self.pingOutData = [[NSData alloc] initWithBytes:(unsigned char[]){PingOut, EOMFirst, EOMSecond} length:3];
        self.insync = false;
        self.dataLength = packetSize - cmdLength;
    }
    
    return self;
}

- (void)onConnectionFinalized
{
    self.insync = false;
}

- (void)pingIn
{
    [self writeRaw:self.pingOutData];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.commDelegate respondsToSelector:@selector(onConnect)]) {
            [self.commDelegate onConnect];
        }
    });
    
}

- (void)pingOut
{
    //NOOP
}

-(void)onDataPacket:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.commDelegate respondsToSelector:@selector(onData:)]) {
            [self.commDelegate onData:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        }
    });
}

- (void)onData:(NSData *)newData
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
            self.chunkedData = [[NSMutableData alloc] init];
            [self.chunkedData appendData:msgData];
        } else if (data[0] == ChunkedData) {
            [self.chunkedData appendData:msgData];
        } else if (data[0] == ChunkedDataEnd) {
            [self.chunkedData appendData:msgData];
            [self onDataPacket:self.chunkedData];
        } else {
            //Unknown
        }
    }
}

- (void)writeString:(NSString *)string
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    if (self.dataLength < string.length) {
        int toIndex = 0;
        UInt8 dataMarker = ChunkedData;
        
        for (int index = 0; index < string.length; index = index + self.dataLength) {
            [data setLength:0];
            toIndex = (int)MIN(index + _dataLength, string.length);
            NSString *chunk = [string substringWithRange:NSMakeRange(index, toIndex - index)];
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