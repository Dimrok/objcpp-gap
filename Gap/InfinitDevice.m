//
//  InfinitDevice.m
//  Gap
//
//  Created by Christopher Crone on 09/03/15.
//
//

#import "InfinitDevice.h"

#import "InfinitGapLocalizedString.h"
#import "InfinitStateManager.h"

#import "NSString+UUID.h"

@implementation InfinitDevice

#pragma mark - Init

- (instancetype)_initWithId:(NSString*)id_
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
    _meta_name = name;
    if (name.infinit_isUUID)
      _name = [self _nameFromType:self.type];
    else
      _name = name;
  }
  return self;
}

+ (instancetype)deviceWithId:(NSString*)id_
                        name:(NSString*)name
                          os:(NSString*)os
                       model:(NSString*)model
{
  return [[self alloc] _initWithId:id_ name:name os:os model:model];
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
      return GapLocalizedString(@"My Mobile", nil);
    case InfinitDeviceTypeiPad:
      return GapLocalizedString(@"My iPad", nil);
    case  InfinitDeviceTypeiPhone:
      return GapLocalizedString(@"My iPhone", nil);
    case InfinitDeviceTypeiPod:
      return GapLocalizedString(@"My iPod", nil);
    case InfinitDeviceTypeMacDesktop:
      return GapLocalizedString(@"My Mac", nil);
    case InfinitDeviceTypeMacLaptop:
      return GapLocalizedString(@"My MacBook", nil);
    case InfinitDeviceTypePCLinux:
    case InfinitDeviceTypePCWindows:
      return GapLocalizedString(@"My Computer", nil);

    case InfinitDeviceTypeUnknown:
    default:
      return GapLocalizedString(@"Unknown", nil);
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
