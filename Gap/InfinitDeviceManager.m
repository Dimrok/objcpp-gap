//
//  InfinitDeviceManager.m
//  Gap
//
//  Created by Christopher Crone on 09/03/15.
//
//

#import "InfinitDeviceManager.h"

#import "InfinitDevice.h"
#import "InfinitStateManager.h"

@implementation InfinitDeviceManager

static InfinitDeviceManager* _instance = nil;

#pragma mark - Init

- (instancetype)init
{
  NSCAssert(_instance == nil, @"use sharedInstance.");
  if (self = [super init])
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
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
  return [[InfinitStateManager sharedInstance] devices];
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

#pragma mark - Clear Model

- (void)clearModel
{
  _instance = nil;
}

@end
