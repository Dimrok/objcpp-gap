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
         deleted:(BOOL)deleted
           ghost:(BOOL)ghost
{
  if (self = [super init])
  {
    _id_ = [id_ copy];
    _status = status;
    _fullname = [fullname copy];
    _handle = [handle copy];
    _deleted = deleted;
    _ghost = ghost;
  }
  return self;
}

#pragma mark - Public

- (UIImage*)avatar
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
  return [NSString stringWithFormat:@"%@: %@", self.fullname, self.status ? @"online" : @"offline"];
}

@end
