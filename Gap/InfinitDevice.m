//
//  InfinitDevice.m
//  Gap
//
//  Created by Christopher Crone on 09/03/15.
//
//

#import "InfinitDevice.h"

#import "InfinitStateManager.h"

#import "NSString+UUID.h"

@implementation InfinitDevice

#pragma mark - Init

- (instancetype)initWithId:(NSString*)id_
                      name:(NSString*)name
                        os:(NSString*)os
                     model:(NSString*)model
{
  if (self = [super init])
  {
    _id_ = id_;
    _model = model;
    _os = os;
    _type = [self _typeFromOSString:os model:model];
    if (name.infinit_isUUID)
      _name = [self _nameFromType:self.type];
    else
      _name = name;
  }
  return self;
}

- (InfinitDeviceType)_typeFromOSString:(NSString*)os
                                 model:(NSString*)model
{
  InfinitDeviceType res;
  if ([os isEqualToString:@"Android"])
    res = InfinitDeviceTypeAndroid;
  else if ([os isEqualToString:@"iOS"])
  {
    if ([model rangeOfString:@"iPad"].location != NSNotFound)
      res = InfinitDeviceTypeiPad;
    else if ([model rangeOfString:@"iPod"].location != NSNotFound)
      res = InfinitDeviceTypeiPod;
    else
      res = InfinitDeviceTypeiPhone;
  }
  else if ([os isEqualToString:@"MacOSX"])
  {
    if ([model rangeOfString:@"MacBook"].location != NSNotFound)
      res = InfinitDeviceTypeMacLaptop;
    else
      res = InfinitDeviceTypeMacDesktop;
  }
  else if ([os isEqualToString:@"Linux"])
    res = InfinitDeviceTypePCLinux;
  else if ([os isEqualToString:@"Windows"])
    res = InfinitDeviceTypePCWindows;
  else
    res = InfinitDeviceTypeUnknown;
  return res;
}

- (NSString*)_nameFromType:(InfinitDeviceType)type
{
  switch (type)
  {
    case InfinitDeviceTypeAndroid:
      return NSLocalizedString(@"My Mobile", nil);
    case InfinitDeviceTypeiPad:
      return NSLocalizedString(@"My iPad", nil);
    case  InfinitDeviceTypeiPhone:
      return NSLocalizedString(@"My iPhone", nil);
    case InfinitDeviceTypeiPod:
      return NSLocalizedString(@"My iPod", nil);
    case InfinitDeviceTypeMacDesktop:
      return NSLocalizedString(@"My Mac", nil);
    case InfinitDeviceTypeMacLaptop:
      return NSLocalizedString(@"My MacBook", nil);
    case InfinitDeviceTypePCLinux:
    case InfinitDeviceTypePCWindows:
      return NSLocalizedString(@"My Computer", nil);

    case InfinitDeviceTypeUnknown:
    default:
      return NSLocalizedString(@"Unknown", nil);
  }
}

#pragma mark - General

- (BOOL)is_self
{
  return [[InfinitStateManager sharedInstance].self_device_id isEqualToString:self.id_];
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
  return [NSString stringWithFormat:@"<%@ (%@): %@ (%@)>", self.name, self.id_, self.os, self.model];
}

@end
