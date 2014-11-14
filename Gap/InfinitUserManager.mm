//
//  InfinitUserManager.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitUserManager.h"

#import "InfinitStateManager.h"
#import "InfinitStateResult.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("iOS.UserManager");

static InfinitUserManager* _instance = nil;

@implementation InfinitUserManager
{
  NSMutableDictionary* _user_map;
}

#pragma mark - Init

- (id)init
{
  if (self = [super init])
  {
    [self _fillMapWithSwaggers];
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitUserManager alloc] init];
  return _instance;
}

- (void)_fillMapWithSwaggers
{
  _user_map = [NSMutableDictionary dictionary];
  NSArray* swaggers = [[InfinitStateManager sharedInstance] swaggers];
  for (InfinitUser* swagger in swaggers)
    [_user_map setObject:swagger forKey:swagger.id_];
}

#pragma mark - Public

- (InfinitUser*)userWithId:(NSNumber*)id_
{
  @synchronized(_user_map)
  {
    InfinitUser* res = [_user_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] userById:id_];
      [_user_map setObject:res forKey:res.id_];
    }
    return res;
  }
}

- (void)userWithHandle:(NSString*)handle
       performSelector:(SEL)selector
              onObject:(id)object
{
  for (InfinitUser* user in _user_map.allValues)
  {
    if ([user.handle isEqualToString:handle])
    {
      [object performSelector:selector withObject:user afterDelay:0];
      return;
    }
  }
  NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:@{
    @"selector": [NSString stringWithUTF8String:sel_getName(selector)],
    @"object": object
  }];
  [[InfinitStateManager sharedInstance] userByHandle:handle
                                     performSelector:@selector(userWithHandleCallback:)
                                            onObject:self
                                            withData:dict];
}

- (void)userWithHandleCallback:(InfinitStateResult*)result
{
  NSDictionary* dict = result.data;
  id object = dict[@"object"];
  SEL selector = NSSelectorFromString(dict[@"selector"]);
  if (![object respondsToSelector:selector])
  {
    ELLE_ERR("%s: invalid selector", self.description.UTF8String);
    return;
  }
  if (result.success)
  {
    InfinitUser* user = dict[@"user"];
    @synchronized(_user_map)
    {
      if (_user_map[user.id_] == nil)
        [_user_map setObject:user forKey:user.id_];
    }
    [object performSelector:selector
                 withObject:user
                 afterDelay:0];
  }
  else
  {
    ELLE_TRACE("%s: user not found by handle", self.description.UTF8String);
    [object performSelector:selector
                 withObject:nil
                 afterDelay:0];
  }
}

#pragma mark - State Manager Callbacks

- (void)newUser:(InfinitUser*)user
{
  @synchronized(_user_map)
  {
    if ([_user_map objectForKey:user.id_] != nil)
      return;
    [_user_map setObject:user forKey:user.id_];
    [self sendNewUserNotification:user];
  }
}

- (void)userWithId:(NSNumber*)id_
     statusUpdated:(BOOL)status
{
  InfinitUser* user = [self userWithId:id_];
  if (user == nil)
    return;
  user.status = status;
  [self sendUserStatusNotification:user];
}

- (void)userDeletedWithId:(NSNumber*)id_
{
  InfinitUser* user = [self userWithId:id_];
  if (user == nil)
    return;
  user.deleted = YES;
  [self sendUserDeletedNotification:user];
}

#pragma mark - User Notifications

- (void)sendNewUserNotification:(InfinitUser*)user
{
  NSDictionary* user_info = @{@"id": user.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_NEW_USER_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

- (void)sendUserStatusNotification:(InfinitUser*)user
{
  NSDictionary* user_info = @{@"id": user.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_USER_STATUS_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
  
}

- (void)sendUserDeletedNotification:(InfinitUser*)user
{
  NSDictionary* user_info = @{@"id": user.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_USER_DELETED_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

@end
