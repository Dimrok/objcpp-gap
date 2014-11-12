//
//  InfinitUserManager.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitUserManager.h"

#import "InfinitStateManager.h"

static InfinitUserManager* _instance = nil;

@implementation InfinitUserManager
{
  NSMutableDictionary* _user_map;
}

- (id)init
{
  if (self = [super init])
  {
    _user_map = [NSMutableDictionary dictionary];
    [self fillMapWithSwaggers];
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitUserManager alloc] init];
  return _instance;
}

- (void)fillMapWithSwaggers
{
  NSArray* swaggers = [[InfinitStateManager sharedInstance] swaggers];
  for (InfinitUser* swagger in swaggers)
    [_user_map setObject:swagger forKey:swagger.id_];
}

- (InfinitUser*)userWithId:(NSNumber*)user_id
{
  @synchronized(_user_map)
  {
    InfinitUser* res = [_user_map objectForKey:user_id];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] userById:user_id];
    }
    return res;
  }
}

@end
