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
    }
    return res;
  }
}

@end
