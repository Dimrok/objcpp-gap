//
//  InfinitPeerTransactionManager.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitPeerTransactionManager.h"

#import "InfinitDirectoryManager.h"
#import "InfinitStateManager.h"

#import "NSString+email.h"

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel:)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    [self _fillTransactionMap];
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
      if (!string.isEmail)
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
    // Only notify UI when it's an Infinit User. When sending to an email address, the user doesn't
    // have an ID until Meta has replied.
    if (transaction_id.unsignedIntValue != 0 && [recipient isKindOfClass:InfinitUser.class])
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
  NSString* path =
    [[InfinitDirectoryManager sharedInstance] downloadDirectoryForTransaction:transaction];
  if (path == nil)
  {
    ELLE_ERR("%s: unable to accept transaction, invalid download path",
             self.description.UTF8String);
    return;
  }
  NSDictionary* meta_data = @{@"sender": transaction.sender.meta_id,
                              @"sender_device": transaction.sender_device_id,
                              @"ctime": @(transaction.mtime)};
  NSString* meta_file = [path stringByAppendingPathComponent:@".sender"];
  if (![meta_data writeToFile:meta_file atomically:YES])
  {
    ELLE_ERR("%s: unable to write transaction sender data: %s",
             self.description.UTF8String, transaction.sender.meta_id.UTF8String);
  }
  [[InfinitStateManager sharedInstance] acceptTransactionWithId:transaction.id_
                                                    toDirectory:path];
}

- (void)rejectTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] rejectTransactionWithId:transaction.id_];
}

- (void)pauseTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] pauseTransactionWithId:transaction.id_];
}

- (void)resumeTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] resumeTransactionWithId:transaction.id_];
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
      if (existing.status != transaction.status)
      {
        [existing updateWithTransaction:transaction];
        [self sendTransactionStatusNotification:existing];
      }
      else
      {
        [existing updateWithTransaction:transaction];
      }
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
