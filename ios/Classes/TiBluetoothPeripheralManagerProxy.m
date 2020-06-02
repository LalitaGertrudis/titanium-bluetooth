/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2016 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiBluetoothPeripheralManagerProxy.h"
#import "TiBluetoothBeaconRegionProxy.h"
#import "TiBluetoothCentralProxy.h"
#import "TiBluetoothCharacteristicProvider.h"
#import "TiBluetoothCharacteristicProxy.h"
#import "TiBluetoothDescriptorProxy.h"
#import "TiBluetoothRequestProxy.h"
#import "TiBluetoothServiceProxy.h"
#import "TiBluetoothUtils.h"
#import "TiUtils.h"
#import "TiBlob.h"
#import "TiBluetoothL2CAPChannelProxy.h"

@implementation TiBluetoothPeripheralManagerProxy

- (id)_initWithPageContext:(id<TiEvaluator>)context andProperties:(id)args
{
  if (self = [super _initWithPageContext:context]) {
    NSString *bluetoothPermissions = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSBluetoothPeripheralUsageDescription"];
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    NSNumber *showPowerAlert;
    NSString *restoreIdentifier;

    if (!bluetoothPermissions) {
      [self throwException:@"The NSBluetoothPeripheralUsageDescription key is required to interact with Bluetooth on iOS. Please add it to your plist and try it again." subreason:nil location:CODELOCATION];
      return nil;
    }

    ENSURE_ARG_OR_NIL_FOR_KEY(showPowerAlert, args, @"showPowerAlert", NSNumber);
    ENSURE_ARG_OR_NIL_FOR_KEY(restoreIdentifier, args, @"restoreIdentifier", NSString);

    if (showPowerAlert) {
      [options setObject:showPowerAlert forKey:CBPeripheralManagerOptionShowPowerAlertKey];
    }

    if (restoreIdentifier) {
      [options setObject:restoreIdentifier forKey:CBPeripheralManagerOptionRestoreIdentifierKey];
    }

    peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                                queue:dispatch_get_main_queue()
                                                              options:options.count > 0 ? options : nil];
  }

  return self;
}

#pragma mark Public APIs

- (NSNumber *)state
{
  return NUMINTEGER([peripheralManager state]);
}

- (NSNumber *)isAdvertising
{
  return NUMBOOL([peripheralManager isAdvertising]);
}

- (void)startAdvertising:(id)args
{
  args = [args objectAtIndex:0];

  if ([args isKindOfClass:[NSDictionary class]]) {
    NSMutableDictionary *advertisementData = [NSMutableDictionary dictionary];
    NSString *localName;
    NSArray *serviceUUIDs;

    ENSURE_ARG_OR_NIL_FOR_KEY(localName, args, @"localName", NSString);
    ENSURE_ARG_OR_NIL_FOR_KEY(serviceUUIDs, args, @"serviceUUIDs", NSArray);

    if (localName != nil) {
      [advertisementData setObject:localName forKey:CBAdvertisementDataLocalNameKey];
    }

    if (serviceUUIDs != nil) {
      [advertisementData setObject:[TiBluetoothUtils CBUUIDArrayFromStringArray:serviceUUIDs] forKey:CBAdvertisementDataServiceUUIDsKey];
    }

    [peripheralManager startAdvertising:advertisementData];
  } else if ([args isKindOfClass:[TiBluetoothBeaconRegionProxy class]]) {
    [peripheralManager startAdvertising:[[args beaconRegion] peripheralDataWithMeasuredPower:[args measuredPower]]];
  } else {
    [peripheralManager startAdvertising:nil];
  }
}

- (void)stopAdvertising:(id)unused
{
  [peripheralManager stopAdvertising];
}

- (void)setDesiredConnectionLatencyForCentral:(id)args
{
  ENSURE_TYPE(args, NSArray);
  ENSURE_ARG_COUNT(args, 2);

  id latency = [args objectAtIndex:0];
  id central = [args objectAtIndex:1];

  ENSURE_TYPE(latency, NSNumber);
  ENSURE_TYPE(central, TiBluetoothCentralProxy);

  [peripheralManager setDesiredConnectionLatency:[TiUtils intValue:latency]
                                      forCentral:[(TiBluetoothCentralProxy *)central central]];
}

- (void)addService:(id)value
{
  ENSURE_SINGLE_ARG(value, TiBluetoothServiceProxy);

  [peripheralManager addService:(CBMutableService *)[(TiBluetoothServiceProxy *)value service]];
}

- (void)removeService:(id)value
{
  ENSURE_SINGLE_ARG(value, TiBluetoothServiceProxy);

  [peripheralManager removeService:(CBMutableService *)[(TiBluetoothServiceProxy *)value service]];
}

- (void)removeAllServices:(id)unused
{
  [peripheralManager removeAllServices];
}

- (void)respondToRequestWithResult:(id)args
{
  ENSURE_ARG_COUNT(args, 2);

  id request = [args objectAtIndex:0];
  id result = [args objectAtIndex:1];

  [peripheralManager respondToRequest:[(TiBluetoothRequestProxy *)request request]
                           withResult:[TiUtils intValue:result]];
}

- (NSNumber *)updateValueForCharacteristicOnSubscribedCentrals:(id)args
{
  ENSURE_ARG_COUNT(args, 3);

  id value = [args objectAtIndex:0];
  id characteristic = [args objectAtIndex:1];
  id subscribedCentrals = [args objectAtIndex:2];

  ENSURE_TYPE(value, TiBlob);
  ENSURE_TYPE(characteristic, TiBluetoothCharacteristicProxy);
  ENSURE_TYPE(subscribedCentrals, NSArray);

  NSMutableArray *result = [NSMutableArray array];

  for (id subscribedCentral in subscribedCentrals) {
    ENSURE_TYPE(subscribedCentral, TiBluetoothCentralProxy)
        [result addObject:[(TiBluetoothCentralProxy *)subscribedCentral central]];
  }

  return NUMBOOL([peripheralManager updateValue:[(TiBlob *)value data]
                              forCharacteristic:(CBMutableCharacteristic *)[(TiBluetoothCharacteristicProxy *)characteristic characteristic]
                           onSubscribedCentrals:result]);
}

#pragma mark Delegates

- (void)peripheralManager:(CBPeripheralManager *)peripheral didPublishL2CAPChannel:(CBL2CAPPSM)PSM error:(NSError *)error
{
  if ([self _hasListeners:@"didPublishL2CAPChannel"]) {
    [self fireEvent:@"didPublishL2CAPChannel"
         withObject:@{
           @"channel" : NUMUINT(PSM)
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didUnpublishL2CAPChannel:(CBL2CAPPSM)PSM error:(NSError *)error
{
  if ([self _hasListeners:@"didUnpublishL2CAPChannel"]) {
    [self fireEvent:@"didUnpublishL2CAPChannel"
         withObject:@{
           @"channel" : NUMUINT(PSM)
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didOpenL2CAPChannel:(CBL2CAPChannel *)channel error:(NSError *)error
{
  if ([self _hasListeners:@"didOpenL2CAPChannel"]) {
    [self fireEvent:@"didOpenL2CAPChannel"
         withObject:@{
           @"channel" : [[TiBluetoothL2CAPChannelProxy alloc] _initWithPageContext:[self pageContext] andChannel:channel]
         }];
  }
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
  if ([self _hasListeners:@"didUpdateState"]) {
    [self fireEvent:@"didUpdateState"
         withObject:@{
           @"state" : @(peripheral.state)
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary<NSString *, id> *)dict
{
  if ([self _hasListeners:@"willRestoreState"]) {
    [self fireEvent:@"willRestoreState"
         withObject:@{
           @"state" : @(peripheral.state)
         }];
  }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(nullable NSError *)error
{
  if ([self _hasListeners:@"didStartAdvertising"]) {
    [self fireEvent:@"didStartAdvertising"
         withObject:@{
           @"success" : NUMBOOL(error == nil),
           @"error" : NULL_IF_NIL([error localizedDescription])
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(nullable NSError *)error
{
  if ([self _hasListeners:@"didAddService"]) {
    [self fireEvent:@"didAddService"
         withObject:@{
           @"service" : [[TiBluetoothServiceProxy alloc] _initWithPageContext:[self pageContext] andService:service],
           @"error" : NULL_IF_NIL([error localizedDescription])
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
  if ([self _hasListeners:@"didSubscribeToCharacteristic"]) {
    [self fireEvent:@"didSubscribeToCharacteristic"
         withObject:@{
           @"central" : [[TiBluetoothCentralProxy alloc] _initWithPageContext:[self pageContext] andCentral:central],
           @"characteristic" : [self characteristicProxyFromCharacteristic:characteristic]
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
  if ([self _hasListeners:@"didUnsubscribeFromCharacteristic"]) {
    [self fireEvent:@"didUnsubscribeFromCharacteristic"
         withObject:@{
           @"central" : [[TiBluetoothCentralProxy alloc] _initWithPageContext:[self pageContext] andCentral:central],
           @"characteristic" : [self characteristicProxyFromCharacteristic:characteristic]
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request;
{
  if ([self _hasListeners:@"didReceiveReadRequest"]) {
    [self fireEvent:@"didReceiveReadRequest"
         withObject:@{
           @"request" : [[TiBluetoothRequestProxy alloc] _initWithPageContext:[self pageContext] andRequest:request]
         }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
  if ([self _hasListeners:@"didReceiveWriteRequests"]) {
    [self fireEvent:@"didReceiveWriteRequests"
         withObject:@{
           @"requests" : [self arrayFromReadWriteRequests:requests]
         }];
  }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
  if ([self _hasListeners:@"readyToUpdateSubscribers"]) {
    [self fireEvent:@"readyToUpdateSubscribers" withObject:nil];
  }
}

#pragma mark Utilities

- (NSArray *)arrayFromReadWriteRequests:(NSArray<CBATTRequest *> *)requests
{
  NSMutableArray *result = [NSMutableArray array];

  for (CBATTRequest *request in requests) {
    [result addObject:[[TiBluetoothRequestProxy alloc] _initWithPageContext:[self pageContext] andRequest:request]];
  }

  return result;
}

- (TiBluetoothCharacteristicProxy *)characteristicProxyFromCharacteristic:(CBCharacteristic *)characteristic
{
  __block TiBluetoothCharacteristicProxy *result = [[TiBluetoothCharacteristicProvider sharedInstance] characteristicProxyFromCharacteristic:characteristic];

  if (!result) {
    NSLog(@"[DEBUG] Could not find cached instance of Ti.Bluetooth.Characteristic proxy. Adding and returning it now.");

    result = [[TiBluetoothCharacteristicProxy alloc] _initWithPageContext:[self pageContext] andCharacteristic:characteristic];
    [[TiBluetoothCharacteristicProvider sharedInstance] addCharacteristic:result];
  }

  return result;
}

@end
