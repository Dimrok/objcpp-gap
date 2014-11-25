//
//  InfinitPeerTransactionManager.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitPeerTransactionManager.h"

#import "InfinitStateManager.h"
#import "InfinitUtilities.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.PeerTransactionManager");

static InfinitPeerTransactionManager* _instance = nil;

@implementation InfinitPeerTransactionManager
{
@private
  NSMutableDictionary* _transaction_map;
}

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    [self _fillTransactionMap];
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitPeerTransactionManager alloc] init];
  return _instance;
}

- (void)_fillTransactionMap
{
  _transaction_map = [NSMutableDictionary dictionary];
  NSArray* transactions = [[InfinitStateManager sharedInstance] peerTransactions];
  for (InfinitPeerTransaction* transaction in transactions)
    [_transaction_map setObject:transaction forKey:transaction.id_];
}

#pragma mark - Access Transactions

- (NSArray*)transactions
{
  return [[_transaction_map allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (InfinitPeerTransaction*)transactionWithId:(NSNumber*)id_
{
  @synchronized(_transaction_map)
  {
    InfinitPeerTransaction* res = [_transaction_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] peerTransactionById:id_];
    }
    return res;
  }
}

#pragma mark - User Interaction

- (NSArray*)sendFiles:(NSArray*)files
         toRecipients:(NSArray*)recipients
          withMessage:(NSString*)message
{
  NSMutableArray* res = [NSMutableArray array];
  for (id recipient in recipients)
  {
    if (![recipient isKindOfClass:InfinitUser.class] && ![recipient isKindOfClass:NSString.class])
    {
      ELLE_ERR("%s: unable to send, recipient is not user or email", self.description.UTF8String);
      [res addObject:@0];
      continue;
    }
    if ([recipient isKindOfClass:NSString.class])
    {
      NSString* string = recipient;
      if (![InfinitUtilities stringIsEmail:string])
      {
        ELLE_ERR("%s: unable to send, string is not valid email: %s",
                 self.description.UTF8String, string.UTF8String);
        [res addObject:@0];
        continue;
      }
    }
    NSNumber* transaction_id = [[InfinitStateManager sharedInstance] sendFiles:files
                                                                   toRecipient:recipient
                                                                   withMessage:message];
    [res addObject:transaction_id];
    if (transaction_id.unsignedIntValue != 0)
    {
      InfinitPeerTransaction* transaction =
        [[InfinitStateManager sharedInstance] peerTransactionById:transaction_id];
      [self transactionUpdated:transaction];
    }
  }
  return res;
}

- (void)acceptTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] acceptTransactionWithId:transaction.id_];
}

- (void)rejectTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] rejectTransactionWithId:transaction.id_];
}

- (void)cancelTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] cancelTransactionWithId:transaction.id_];
}

#pragma mark - Transaction Updated

- (void)transactionUpdated:(InfinitPeerTransaction*)transaction
{
  @synchronized(_transaction_map)
  {
    InfinitPeerTransaction* existing = [_transaction_map objectForKey:transaction.id_];
    if (existing == nil)
    {
      [_transaction_map setObject:transaction forKey:transaction.id_];
      [self sendNewTransactionNotification:transaction];
    }
    else
    {
      [existing updateWithTransaction:transaction];
      [self sendTransactionStatusNotification:existing];
    }
  }
}

#pragma mark - Transaction Notifications

- (void)sendTransactionStatusNotification:(InfinitPeerTransaction*)transaction
{
  NSDictionary* user_info = @{@"id": transaction.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

- (void)sendNewTransactionNotification:(InfinitPeerTransaction*)transaction
{
  NSDictionary* user_info = @{@"id": transaction.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

@end
