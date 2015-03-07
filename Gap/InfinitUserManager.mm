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
#import "InfinitPeerTransactionManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.UserManager");

static InfinitUserManager* _instance = nil;

@implementation InfinitUserManager
{
  NSMutableDictionary* _user_map;
  NSArray* _favorites;
  InfinitUser* _me;
}

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel:)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    _me = nil;
    [self _fillMapWithSwaggers];
    [self _fetchFavorites];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearModel:(NSNotification*)notification
{
  _instance = nil;
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
  {
    swagger.favorite = NO;
    [_user_map setObject:swagger forKey:swagger.id_];
  }
}

- (void)_fetchFavorites
{
  _favorites = [[InfinitStateManager sharedInstance] favorites];
  for (NSNumber* id_ in _favorites)
  {
    InfinitUser* user = [self userWithId:id_];
    user.favorite = YES;
    if ([_user_map objectForKey:id_] == nil)
    {
      [_user_map setObject:user forKeyedSubscript:id_];
    }
  }
}

#pragma mark - Public

- (InfinitUser*)me
{
  if (_me == nil)
    _me = [self userWithId:[[InfinitStateManager sharedInstance] self_id]];
  return _me;
}

- (NSArray*)alphabetical_swaggers
{
  NSSortDescriptor* sort = [[NSSortDescriptor alloc] initWithKey:@"fullname"
                                                       ascending:YES
                                                        selector:@selector(caseInsensitiveCompare:)];
  return [[self time_ordered_swaggers] sortedArrayUsingDescriptors:@[sort]];
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
  for (InfinitUser* user in [_user_map.allValues sortedArrayUsingDescriptors:@[sort]])
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
  for (InfinitUser* user in _user_map.allValues)
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

- (InfinitUser*)userWithId:(NSNumber*)id_
{
  @synchronized(_user_map)
  {
    InfinitUser* res = [_user_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] userById:id_];
      if (res != nil)
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
      [object performSelector:selector withObject:user afterDelay:0.0f];
      return;
    }
  }
  NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:@{
    @"selector": NSStringFromSelector(selector),
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
                 afterDelay:0.0f];
  }
  else
  {
    ELLE_TRACE("%s: user not found by handle", self.description.UTF8String);
    [object performSelector:selector
                 withObject:nil
                 afterDelay:0.0f];
  }
}

- (NSArray*)_localResultsForText:(NSString*)text
{
  NSMutableArray* handle_matches = [NSMutableArray array];
  NSMutableArray* fullname_matches = [NSMutableArray array];
  @synchronized(_user_map)
  {
    NSUInteger handle_search_mask = (NSCaseInsensitiveSearch|
                                     NSAnchoredSearch|
                                     NSWidthInsensitiveSearch);
    NSUInteger name_search_mask = (NSCaseInsensitiveSearch|NSWidthInsensitiveSearch);
    for (InfinitUser* user in _user_map.allValues)
    {
      if (user.deleted)
        continue;

      if ([user.handle rangeOfString:text options:handle_search_mask].location != NSNotFound)
        [handle_matches addObject:user];
      else if ([user.fullname rangeOfString:text options:name_search_mask].location != NSNotFound)
        [fullname_matches addObject:user];
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

- (void)searchUsers:(NSString*)text
    performSelector:(SEL)selector
           onObject:(id)object
{
  NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:@{
    @"selector": NSStringFromSelector(selector),
    @"object": object
    }];
  NSArray* local_results = [self _localResultsForText:text];
  if (local_results.count > 0)
    [object performSelector:selector withObject:local_results afterDelay:0.0f];
  [[InfinitStateManager sharedInstance] textSearch:text
                                   performSelector:@selector(searchUsersCallback:)
                                          onObject:self
                                          withData:dict];
}

- (void)searchUsersCallback:(InfinitStateResult*)result
{
  NSDictionary* dict = result.data;
  id object = dict[@"object"];
  SEL selector = NSSelectorFromString(dict[@"selector"]);
  if (![object respondsToSelector:selector])
  {
    ELLE_ERR("%s: invalid selector", self.description.UTF8String);
    return;
  }
  NSArray* users = dict[@"users"];
  if (result.success)
  {
    [self _upsertUsersToModel:users];
  }
  else
  {
    ELLE_TRACE("%s: unable to search: %d", self.description.UTF8String, result.status);
  }
  [object performSelector:selector
               withObject:users
               afterDelay:0.0f];
}

- (void)searchEmails:(NSArray*)emails
     performSelector:(SEL)selector
            onObject:(id)object
{
  NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:@{
    @"selector": NSStringFromSelector(selector),
    @"object": object
    }];
  [[InfinitStateManager sharedInstance] searchEmails:emails
                                     performSelector:@selector(searchEmailsCallback:) 
                                            onObject:self
                                            withData:dict];
}

- (void)searchEmailsCallback:(InfinitStateResult*)result
{
  NSDictionary* dict = result.data;
  id object = dict[@"object"];
  SEL selector = NSSelectorFromString(dict[@"selector"]);
  if (![object respondsToSelector:selector])
  {
    ELLE_ERR("%s: invalid selector", self.description.UTF8String);
    return;
  }
  NSDictionary* results = dict[@"results"];
  if (result.success)
  {
    [self _upsertUsersToModel:results.allValues];
  }
  else
  {
    ELLE_TRACE("%s: unable to search by emails: %d", self.description.UTF8String, result.status);
  }
  [object performSelector:selector withObject:results afterDelay:0.0f];
}

#pragma mark - Helpers

- (void)_upsertUsersToModel:(NSArray*)users
{
  @synchronized(_user_map)
  {
    for (InfinitUser* user in users)
    {
      [_user_map setObject:user forKey:user.id_];
    }
  }
}

#pragma mark - State Manager Callbacks

- (void)updateUser:(InfinitUser*)user
{
  @synchronized(_user_map)
  {
    InfinitUser* existing = [_user_map objectForKey:user.id_];
    if (existing == nil)
    {
      [_user_map setObject:user forKey:user.id_];
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

- (void)userWithMetaId:(NSString*)meta_id
       performSelector:(SEL)selector
              onObject:(id)object
{
  for (InfinitUser* user in _user_map.allValues)
  {
    if ([user.meta_id isEqualToString:meta_id] && [object respondsToSelector:selector])
    {
      [object performSelector:selector withObject:user afterDelay:0.0f];
      return;
    }
  }
  NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:@{
    @"selector": NSStringFromSelector(selector),
    @"object": object}];
  [[InfinitStateManager sharedInstance] userByMetaId:meta_id
                                     performSelector:@selector(userWithMetaIdCallback:)
                                            onObject:self
                                            withData:dict];
}

- (InfinitUser*)localUserWithMetaId:(NSString*)meta_id
{
  for (InfinitUser* user in _user_map.allValues)
  {
    if ([user.meta_id isEqualToString:meta_id])
      return user;
  }
  return nil;
}

- (void)userWithMetaIdCallback:(InfinitStateResult*)result
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
                 afterDelay:0.0f];
  }
  else
  {
    ELLE_TRACE("%s: user not found by meta ID", self.description.UTF8String);
    [object performSelector:selector
                 withObject:nil
                 afterDelay:0.0f];
  }
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
