//
//  InfinitLinkTransactionManager.m
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import "InfinitLinkTransactionManager.h"
#import "InfinitStateManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("iOS.LinkTransactionManager");

static InfinitLinkTransactionManager* _instance = nil;

@implementation InfinitLinkTransactionManager
{
  NSMutableDictionary* _transaction_map;
}

#pragma mark - Init

- (id)init
{
  if (self = [super init])
  {
    [self _fillTransactionMap];
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitLinkTransactionManager alloc] init];
  return _instance;
}

- (void)_fillTransactionMap
{
  _transaction_map = [NSMutableDictionary dictionary];
  NSArray* transactions = [[InfinitStateManager sharedInstance] linkTransactions];
  for (InfinitLinkTransaction* transaction in transactions)
  {
    if (transaction.status != gap_transaction_canceled &&
        transaction.status != gap_transaction_deleted &&
        transaction.status != gap_transaction_failed)
    {
      [_transaction_map setObject:transaction forKey:transaction.id_];
    }
  }
}

#pragma mark - Access Transactions

- (NSArray*)transactions
{
  return [[_transaction_map allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (InfinitLinkTransaction*)transactionWithId:(NSNumber*)id_
{
  @synchronized(_transaction_map)
  {
    InfinitLinkTransaction* res = [_transaction_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] linkTransactionById:id_];
    }
    return res;
  }
}

#pragma mark - User Interaction

- (NSNumber*)createLinkWithFiles:(NSArray*)files
                     withMessage:(NSString*)message
{
  NSNumber* res = [[InfinitStateManager sharedInstance] createLinkWithFiles:files
                                                                withMessage:message];
  if (res.unsignedIntValue != 0)
  {
    InfinitLinkTransaction* transaction =
      [[InfinitStateManager sharedInstance] linkTransactionById:res];
    [self transactionUpdated:transaction];
  }
  return res;
}

- (void)cancelTransaction:(InfinitLinkTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] cancelTransactionWithId:transaction.id_];
}

- (void)deleteTransaction:(InfinitLinkTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] deleteTransactionWithId:transaction.id_];
}

#pragma mark - Transaction Updated

- (void)transactionUpdated:(InfinitLinkTransaction*)transaction
{
  @synchronized(_transaction_map)
  {
    InfinitLinkTransaction* existing = [_transaction_map objectForKey:transaction.id_];
    if (existing == nil)
    {
      [_transaction_map setObject:transaction forKey:transaction.id_];
      [self sendNewTransactionNotification:transaction];
    }
    else
    {
      [existing updateWithTransaction:transaction];
      if (existing.status == transaction.status)
      {
        [self sendTransactionDataNotification:existing];
      }
      else if (existing.status == gap_transaction_canceled ||
               existing.status == gap_transaction_deleted ||
               existing.status == gap_transaction_failed)
      {
        [self sendTransactionDeletedNotification:existing];
        [_transaction_map removeObjectForKey:existing.id_];
      }
      else
      {
        [self sendTransactionStatusNotification:existing];
      }
    }
  }
}

#pragma mark - Transaction Notifications

- (void)sendTransactionStatusNotification:(InfinitLinkTransaction*)transaction
{
  NSDictionary* user_info = @{@"id": transaction.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

- (void)sendTransactionDataNotification:(InfinitLinkTransaction*)transaction
{
  NSDictionary* user_info = @{@"id": transaction.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_LINK_TRANSACTION_DATA_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

- (void)sendNewTransactionNotification:(InfinitLinkTransaction*)transaction
{
  NSDictionary* user_info = @{@"id": transaction.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_NEW_LINK_TRANSACTION_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

- (void)sendTransactionDeletedNotification:(InfinitLinkTransaction*)transaction
{
  NSDictionary* user_info = @{@"id": transaction.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_LINK_TRANSACTION_DELETED_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

@end
