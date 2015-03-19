//
//  InfinitDevice.m
//  Gap
//
//  Created by Christopher Crone on 09/03/15.
//
//

#import "InfinitDevice.h"

#import "InfinitStateManager.h"

@implementation InfinitDevice

#pragma mark - Init

- (instancetype)initWithId:(NSString*)id_
                      name:(NSString*)name
                        os:(NSString*)os
{
  if (self = [super init])
  {
    _id_ = id_;
    _name = name;
    _type = [self _typeFromOSString:os];
  }
  return self;
}

- (InfinitDeviceType)_typeFromOSString:(NSString*)os
{
  InfinitDeviceType res;
  if ([os isEqualToString:@"Android"])
    res = InfinitDeviceTypeAndroid;
  else if ([os isEqualToString:@"iOS"])
    res = InfinitDeviceTypeiPhone;
  else if ([os isEqualToString:@"MacOSX"])
    res = InfinitDeviceTypeMacLaptop;
  else if ([os isEqualToString:@"Linux"])
    res = InfinitDeviceTypePCLinux;
  else if ([os isEqualToString:@"Windows"])
    res = InfinitDeviceTypePCWindows;
  else
    res = InfinitDeviceTypeUnknown;
  return res;
}

#pragma mark - General

- (NSString*)friendly_name
{
  switch (self.type)
  {
    case InfinitDeviceTypeAndroid:
      return NSLocalizedString(@"My Mobile", nil);
    case  InfinitDeviceTypeiPhone:
      return NSLocalizedString(@"My iPhone", nil);
    case InfinitDeviceTypeMacLaptop:
      return NSLocalizedString(@"My Mac", nil);
    case InfinitDeviceTypePCLinux:
    case InfinitDeviceTypePCWindows:
      return NSLocalizedString(@"My PC", nil);
    case InfinitDeviceTypeUnknown:
      return NSLocalizedString(@"Unknown", nil);
  }
}

- (BOOL)is_self
{
  return [[InfinitStateManager sharedInstance].self_device_id isEqualToString:self.id_];
}

- (NSString*)os_string
{
  switch (self.type)
  {
    case InfinitDeviceTypeAndroid:
      return @"Android";
    case InfinitDeviceTypeiPhone:
      return @"iPhone";
    case InfinitDeviceTypeMacLaptop:
      return @"Mac";
    case InfinitDeviceTypePCLinux:
      return @"Linux";
    case InfinitDeviceTypePCWindows:
      return @"Windows";
    case InfinitDeviceTypeUnknown:
      return @"Unknown";
  }
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:InfinitDevice.class])
    return NO;
  InfinitDevice* other = (InfinitDevice*)object;
  if ([self.id_ isEqual:other.id_])
    return YES;
  return NO;
}

- (NSUInteger)hash
{
  return self.id_.hash;
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%@ (%@): %@>", self.name, self.id_, self.os_string];
}

@end
