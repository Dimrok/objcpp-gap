//
//  InfinitDeviceManager.m
//  Gap
//
//  Created by Christopher Crone on 09/03/15.
//
//

#import "InfinitDeviceManager.h"

#import "InfinitConnectionManager.h"
#import "InfinitDevice.h"
#import "InfinitDeviceInformation.h"
#import "InfinitStateManager.h"
#import "InfinitThreadSafeDictionary.h"

#import "NSString+UUID.h"

@interface InfinitDeviceManager ()

@property (atomic, readonly) InfinitThreadSafeDictionary* device_map;

@end

@implementation InfinitDeviceManager

static InfinitDeviceManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

#pragma mark - Init

- (instancetype)init
{
  NSCAssert(_instance == nil, @"use sharedInstance.");
  if (self = [super init])
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionStatusChanged:)
                                                 name:INFINIT_CONNECTION_STATUS_CHANGE
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    _device_map = [InfinitThreadSafeDictionary initWithName:@"deviceModel"];
    [self updateDevices];
    [self updateDeviceIfNeeded];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitDeviceManager alloc] init];
  });
  return _instance;
}

- (void)updateDeviceIfNeeded
{
  NSString* name = nil;
  if (self.this_device.meta_name.infinit_isUUID)
    name = [InfinitDeviceInformation deviceName];
  NSString* model = nil;
  if (!self.this_device.model.length)
    model = [InfinitDeviceInformation deviceModel];
  if (name.length || model.length)
  {
    [[InfinitStateManager sharedInstance] updateDeviceName:name
                                                     model:model
                                                        os:nil 
                                           completionBlock:^(InfinitStateResult* result)
    {
      if (result.success)
        [[InfinitDeviceManager sharedInstance] updateDevices];
    }];
  }
}

#pragma mark - General

- (NSArray*)all_devices
{
  if (self.device_map == nil)
    [self updateDevices];
  return self.device_map.allValues;
}

- (InfinitDevice*)deviceWithId:(NSString*)id_
{
  return [self.device_map objectForKey:id_];
}

- (NSArray*)other_devices
{
  if (self.all_devices.count <= 1)
    return @[];
  NSMutableArray* res = [NSMutableArray arrayWithArray:self.all_devices];
  NSUInteger index = 0;
  for (InfinitDevice* device in res)
  {
    if (device.is_self)
      break;
    index++;
  }
  [res removeObjectAtIndex:index];
  return res;
}

- (InfinitDevice*)this_device
{
  NSString* device_id = [InfinitStateManager sharedInstance].self_device_id;
  InfinitDevice* res = self.device_map[device_id];
  if (res == nil)
  {
    [self updateDevices];
    res = self.device_map[device_id];
  }
  return res;
}

#pragma mark - Connection Status

- (void)updateDevices
{
  [self.device_map removeAllObjects];
  for (InfinitDevice* device in [InfinitStateManager sharedInstance].devices)
  {
    if (device.id_)
      [self.device_map setObject:device forKey:device.id_];
  }
}

- (void)connectionStatusChanged:(NSNotification*)notification
{
  InfinitConnectionStatus* connection_status = notification.object;
  if (connection_status.status)
    [self updateDevices];
}

#pragma mark - Clear Model

- (void)clearModel
{
  _instance = nil;
  _instance_token = 0;
}

@end
