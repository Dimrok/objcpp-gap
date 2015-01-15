//
//  InfinitUser.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitUser.h"

#import "InfinitStateManager.h"
#import "InfinitAvatarManager.h"

@implementation InfinitUser

#pragma mark - Init

- (id)initWithId:(NSNumber*)id_
          status:(BOOL)status
        fullname:(NSString*)fullname
          handle:(NSString*)handle
         swagger:(BOOL)swagger
         deleted:(BOOL)deleted
           ghost:(BOOL)ghost
{
  if (self = [super init])
  {
    _id_ = id_;
    _status = status;
    _fullname = fullname;
    _handle = handle;
    _swagger = swagger;
    _deleted = deleted;
    _ghost = ghost;
  }
  return self;
}

#pragma mark - Public

#if TARGET_OS_IPHONE
- (UIImage*)avatar
#else
- (NSImage*)avatar
#endif
{
  return [[InfinitAvatarManager sharedInstance] avatarForUser:self];
}

- (BOOL)is_self
{
  if ([[[InfinitStateManager sharedInstance] self_id] isEqualToNumber:self.id_])
    return YES;
  else
    return NO;
}

#pragma mark - Description

- (NSString*)description
{
  return [NSString stringWithFormat:@"%@: %@ %@%@: %@%@",
          self.id_,
          self.deleted ? @"deleted" : self.ghost ? @"ghost" : @"normal",
          self.fullname,
          self.handle.length > 0 ? [NSString stringWithFormat:@" (%@)", self.handle] : @"",
          self.swagger ? @"is swagger, " : @"",
          self.status ? @"online" : @"offline"];
}

#pragma mark - Comparison

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:self.class])
    return NO;
  if ([self.id_ isEqualToNumber:[object id_]])
    return YES;
  return NO;
}

@end
