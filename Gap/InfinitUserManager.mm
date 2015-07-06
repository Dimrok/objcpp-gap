//
//  InfinitUserManager.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitUserManager.h"

#import "InfinitConnectionManager.h"
#import "InfinitStateManager.h"
#import "InfinitStateResult.h"
#import "InfinitPeerTransactionManager.h"
#import "InfinitThreadSafeDictionary.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.UserManager");

static InfinitUserManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@interface InfinitUserManager ()

@property (atomic, readwrite) BOOL filled_model;
@property (atomic, readonly) InfinitThreadSafeDictionary* user_map;

@end

@implementation InfinitUserManager
{
  NSArray* _favorites;
  InfinitUser* _me;
}

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _filled_model = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionStatusChanged:)
                                                 name:INFINIT_CONNECTION_STATUS_CHANGE 
                                               object:nil];
    _me = nil;
  }
  return self;
}

- (void)dealloc
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearModel
{
  _instance = nil;
  _instance_token = 0;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitUserManager alloc] init];
  });
  return _instance;
}

- (void)_fillMapWithSwaggers
{
  @synchronized(self.user_map)
  {
    _user_map = [InfinitThreadSafeDictionary initWithName:@"UserModel"];
    NSArray* swaggers = [[InfinitStateManager sharedInstance] swaggers];
    for (InfinitUser* swagger in swaggers)
    {
      swagger.favorite = NO;
      self.user_map[swagger.id_] = swagger;
    }
    [self _fetchFavorites];
    self.filled_model = YES;
  }
}

- (void)_fetchFavorites
{
  NSArray* favorites = [[InfinitStateManager sharedInstance] favorites];
  for (NSNumber* id_ in favorites)
  {
    InfinitUser* user = [self userWithId:id_];
    user.favorite = YES;
    [self updateUser:user];
  }
}

#pragma mark - Public

- (InfinitUser*)me
{
  if (_me == nil)
  {
    InfinitUser* fetched_me = [self userWithId:[[InfinitStateManager sharedInstance] self_id]];
    if (fetched_me.id_.unsignedIntValue == 0)
    {
      ELLE_ERR("%s: got invalid self user", self.description.UTF8String);
      return fetched_me;
    }
    _me = [self userWithId:[[InfinitStateManager sharedInstance] self_id]];
  }
  return _me;
}

- (NSArray*)alphabetical_swaggers
{
  NSSortDescriptor* sort = [[NSSortDescriptor alloc] initWithKey:@"fullname"
                                                       ascending:YES
                                                        selector:@selector(caseInsensitiveCompare:)];
  NSMutableArray* swaggers = [NSMutableArray array];
  for (InfinitUser* user in self.user_map.allValues)
  {
    if (user.swagger)
      [swaggers addObject:user];
  }
  [swaggers removeObject:[self me]];
  [swaggers removeObjectsInArray:[self favorites]];
  return [swaggers sortedArrayUsingDescriptors:@[sort]];
}

- (NSArray*)time_ordered_swaggers
{
  NSMutableOrderedSet* res = [NSMutableOrderedSet orderedSet];
  NSArray* reversed_transactions = [[InfinitPeerTransactionManager sharedInstance] transactions];
  for (InfinitPeerTransaction* transaction in reversed_transactions)
  {
    if (!transaction.other_user.is_self)
      [res addObject:transaction.other_user];
  }
  NSSortDescriptor* sort = [[NSSortDescriptor alloc] initWithKey:@"fullname"
                                                       ascending:YES
                                                        selector:@selector(caseInsensitiveCompare:)];
  for (InfinitUser* user in [self.user_map.allValues sortedArrayUsingDescriptors:@[sort]])
  {
    if (user.swagger)
      [res addObject:user];
  }
  [res removeObject:[self me]];
  [res removeObjectsInArray:[self favorites]];
  return res.array;
}

- (NSArray*)favorites
{
  NSMutableArray* res = [NSMutableArray array];
  for (InfinitUser* user in self.user_map.allValues)
  {
    if (user.favorite)
      [res addObject:user];
  }
  [res removeObject:[self me]];
  NSSortDescriptor* sort = [[NSSortDescriptor alloc] initWithKey:@"fullname"
                                                       ascending:YES
                                                        selector:@selector(caseInsensitiveCompare:)];
  return [res sortedArrayUsingDescriptors:@[sort]];
}

- (void)addFavorite:(InfinitUser*)user
{
  user.favorite = YES;
  [[InfinitStateManager sharedInstance] addFavorite:user];
}

- (void)removeFavorite:(InfinitUser*)user
{
  user.favorite = NO;
  [[InfinitStateManager sharedInstance] removeFavorite:user];
}

+ (InfinitUser*)userWithId:(NSNumber*)id_
{
  return [[InfinitUserManager sharedInstance] userWithId:id_];
}

- (InfinitUser*)userWithId:(NSNumber*)id_
{
  @synchronized(self.user_map)
  {
    if (id_.unsignedIntegerValue == 0)
      return [InfinitUser initNullUser];
    InfinitUser* res = [self.user_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] userById:id_];
      if (res != nil)
        [self.user_map setObject:res forKey:res.id_];
    }
    return res;
  }
}

#pragma mark - Search

- (NSArray*)searchLocalUsers:(NSString*)text
{
  NSMutableArray* handle_matches = [NSMutableArray array];
  NSMutableArray* fullname_matches = [NSMutableArray array];
  @synchronized(self.user_map)
  {
    NSUInteger handle_search_mask = (NSCaseInsensitiveSearch|
                                     NSAnchoredSearch|
                                     NSWidthInsensitiveSearch);
    NSUInteger name_search_mask = (NSCaseInsensitiveSearch|NSWidthInsensitiveSearch);
    for (InfinitUser* user in self.user_map.allValues)
    {
      if (!user.deleted)
      {
        if ([user.handle rangeOfString:text options:handle_search_mask].location != NSNotFound)
          [handle_matches addObject:user];
        else if ([user.fullname rangeOfString:text options:name_search_mask].location != NSNotFound)
          [fullname_matches addObject:user];
      }
    }
  }
  NSMutableArray* combined_results = [NSMutableArray arrayWithArray:handle_matches];
  [combined_results addObjectsFromArray:fullname_matches];
  NSArray* res = [self _sortedSearchResults:combined_results forText:text];
  return res;
}

- (NSArray*)_sortedSearchResults:(NSArray*)unsorted
                         forText:(NSString*)text
{
  NSUInteger sort_mask = (NSCaseInsensitiveSearch|NSWidthInsensitiveSearch|NSForcedOrderingSearch);
  NSArray* alpha_name_sorted =
    [unsorted sortedArrayUsingComparator:^NSComparisonResult(InfinitUser* obj1, InfinitUser* obj2)
    {
      return [obj1.fullname compare:obj2.fullname options:sort_mask];
    }];
  NSMutableOrderedSet* res = [NSMutableOrderedSet orderedSet];
  NSUInteger handle_search_mask = (NSCaseInsensitiveSearch|
                                   NSAnchoredSearch|
                                   NSWidthInsensitiveSearch);
  NSMutableArray* favorites = [NSMutableArray array];
  NSMutableArray* swaggers = [NSMutableArray array];
  NSMutableArray* handle_swaggers = [NSMutableArray array];
  for (InfinitUser* user in alpha_name_sorted)
  {
    if (user.favorite)
      [favorites addObject:user];
    if (user.swagger)
      [swaggers addObject:user];
    if ([user.handle rangeOfString:text options:handle_search_mask].location != NSNotFound)
    {
      if (user.swagger)
        [handle_swaggers addObject:user];
    }
  }
  [res addObjectsFromArray:favorites];
  [res addObjectsFromArray:handle_swaggers];
  [res addObjectsFromArray:swaggers];
  [res addObjectsFromArray:alpha_name_sorted];
  return res.array;
}

#pragma mark - Helpers

- (void)_upsertUsersToModel:(NSArray*)users
{
  for (InfinitUser* user in users)
    [self updateUser:user];
}

#pragma mark - State Manager Callbacks

- (void)updateUser:(InfinitUser*)user
{
  @synchronized(self.user_map)
  {
    InfinitUser* existing = [self.user_map objectForKey:user.id_];
    if (existing == nil)
    {
      if (user == nil)
        return;
      [self.user_map setObject:user forKey:user.id_];
      [self sendNewUserNotification:user];
      return;
    }
    [existing updateWithUser:user];
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

- (InfinitUser*)localUserWithMetaId:(NSString*)meta_id
{
  for (InfinitUser* user in self.user_map.allValues)
  {
    if ([user.meta_id isEqualToString:meta_id])
      return user;
  }
  return nil;
}

- (void)userDeletedWithId:(NSNumber*)id_
{
  InfinitUser* user = [self userWithId:id_];
  if (user == nil)
    return;
  user.deleted = YES;
  [self sendUserDeletedNotification:user];
}

- (void)contactJoined:(NSNumber*)id_
              contact:(NSString*)contact
{
  NSDictionary* user_info = @{kInfinitUserId: id_,
                              kInfinitUserContact: contact};
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_CONTACT_JOINED_NOTIFICATION
                                                        object:nil
                                                      userInfo:user_info];
  });
}

#pragma mark - User Notifications

- (NSDictionary*)userInfoForUser:(InfinitUser*)user
{
  return @{kInfinitUserId: user.id_};
}

- (void)postNotificationOnMainThreadName:(NSString*)name
                                    user:(InfinitUser*)user
{
  NSDictionary* user_info = nil;
  if (user)
    user_info = [self userInfoForUser:user];
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self
                                                      userInfo:user_info];
  });
}

- (void)sendNewUserNotification:(InfinitUser*)user
{
  [self postNotificationOnMainThreadName:INFINIT_NEW_USER_NOTIFICATION user:user];
}

- (void)sendUserStatusNotification:(InfinitUser*)user
{
  [self postNotificationOnMainThreadName:INFINIT_USER_STATUS_NOTIFICATION user:user];
  
}

- (void)sendUserDeletedNotification:(InfinitUser*)user
{
  [self postNotificationOnMainThreadName:INFINIT_USER_DELETED_NOTIFICATION user:user];
}

#pragma mark - Connection Status Changed

- (void)connectionStatusChanged:(NSNotification*)notification
{
  InfinitConnectionStatus* connection_status = notification.object;
  if (!self.filled_model && connection_status.status)
  {
    [self _fillMapWithSwaggers];
  }
}

@end
