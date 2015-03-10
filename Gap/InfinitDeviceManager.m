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
#import "InfinitStateManager.h"

@implementation InfinitDeviceManager
{
@private
  NSArray* _all_devices;
}

static InfinitDeviceManager* _instance = nil;

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
    [self updateDevices];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitDeviceManager alloc] init];
  return _instance;
}

#pragma mark - General

- (NSArray*)all_devices
{
  if (_all_devices == nil || _all_devices.count == 0)
    [self updateDevices];
  return _all_devices;
}

- (NSArray*)other_devices
{
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

#pragma mark - Connection Status

- (void)updateDevices
{
  _all_devices = [[InfinitStateManager sharedInstance].devices copy];
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
}

@end
