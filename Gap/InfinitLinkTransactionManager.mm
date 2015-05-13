//
//  InfinitLinkTransactionManager.m
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import "InfinitLinkTransactionManager.h"

#import "InfinitConnectionManager.h"
#import "InfinitStateManager.h"
#import "InfinitThreadSafeDictionary.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.LinkTransactionManager");

static InfinitLinkTransactionManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@interface InfinitLinkTransactionManager ()

@property (atomic, readonly) BOOL filled_model;
@property (atomic, readonly) InfinitThreadSafeDictionary* transaction_map;

@end

@implementation InfinitLinkTransactionManager

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
  }
  return self;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitLinkTransactionManager alloc] init];
  });
  return _instance;
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

- (void)_fillTransactionMap
{
  _transaction_map = [InfinitThreadSafeDictionary initWithName:@"LinkTransactionModel"];
  NSArray* transactions = [[InfinitStateManager sharedInstance] linkTransactions];
  for (InfinitLinkTransaction* transaction in transactions)
  {
    if (![self _ignoredStatus:transaction])
    {
      [self.transaction_map setObject:transaction forKey:transaction.id_];
    }
  }
  _filled_model = YES;
}

#pragma mark - Access Transactions

- (BOOL)running_transactions
{
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if (transaction.status == gap_transaction_transferring)
      return YES;
  }
  return NO;
}

- (NSArray*)transactions
{
  NSMutableArray* res = [NSMutableArray array];
  for (InfinitLinkTransaction* transaction in self.transaction_map.allValues)
  {
    if (![self _ignoredStatus:transaction])
      [res addObject: transaction];
  }
  return [res sortedArrayUsingSelector:@selector(compare:)];
}

- (InfinitLinkTransaction*)transactionWithId:(NSNumber*)id_
{
  @synchronized(self.transaction_map)
  {
    InfinitLinkTransaction* res = [self.transaction_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] linkTransactionById:id_];
    }
    return res;
  }
}

- (InfinitLinkTransaction*)transactionWithMetaId:(NSString*)meta_id
{
  @synchronized(self.transaction_map)
  {
    for (InfinitLinkTransaction* transaction in self.transaction_map.allValues)
    {
      if ([transaction.meta_id isEqualToString:meta_id])
        return transaction;
    }
  }
  return nil;
}

#pragma mark - User Interaction

- (NSNumber*)createLinkWithFiles:(NSArray*)files
                     withMessage:(NSString*)message
{
  return [self _createLinkWithFiles:files withMessage:message asScreenshot:NO];
}

- (NSNumber*)createScreenshotLink:(NSString*)file
{
  return [self _createLinkWithFiles:@[file] withMessage:nil asScreenshot:YES];
}

- (NSNumber*)_createLinkWithFiles:(NSArray*)files
                      withMessage:(NSString*)message
                     asScreenshot:(BOOL)screenshot
{
  NSNumber* res = [[InfinitStateManager sharedInstance] createLinkWithFiles:files
                                                                withMessage:message];
  if (res.unsignedIntValue != 0)
  {
    InfinitLinkTransaction* transaction =
      [[InfinitStateManager sharedInstance] linkTransactionById:res];
    if (screenshot)
      transaction.screenshot = YES;
    else
      transaction.screenshot = NO;
    [self transactionUpdated:transaction];
    [self sendTransactionCreatedNotification:transaction];
  }
  return res;
}

- (void)pauseTransaction:(InfinitLinkTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] pauseTransactionWithId:transaction.id_];
}

- (void)resumeTransaction:(InfinitLinkTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] resumeTransactionWithId:transaction.id_];
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
  if (transaction.status == gap_transaction_payment_required)
    [self postNotificationOnMainThreadName:INFINIT_LINK_QUOTA_EXCEEDED transaction:nil];
  @synchronized(self.transaction_map)
  {
    InfinitLinkTransaction* existing = [self.transaction_map objectForKey:transaction.id_];
    if (existing == nil)
    {
      if (![self _ignoredStatus:transaction])
      {
        [self.transaction_map setObject:transaction forKey:transaction.id_];
        [self sendNewTransactionNotification:transaction];
      }
    }
    else
    {
      gap_TransactionStatus old_status = existing.status;
      [existing updateWithTransaction:transaction];
      if (existing.status == old_status)
      {
        [self sendTransactionDataNotification:existing];
      }
      else if ([self _ignoredStatus:existing])
      {
        [self sendTransactionDeletedNotification:existing];
        [self.transaction_map removeObjectForKey:existing.id_];
      }
      else
      {
        [self sendTransactionStatusNotification:existing];
      }
    }
  }
}

#pragma mark - Helpers

- (BOOL)_ignoredStatus:(InfinitLinkTransaction*)transaction
{
  switch (transaction.status)
  {
    case gap_transaction_canceled:
    case gap_transaction_deleted:
    case gap_transaction_failed:
    case gap_transaction_payment_required:
      return YES;

    default:
      return NO;
  }
}

#pragma mark - Transaction Notifications

- (void)postNotificationOnMainThreadName:(NSString*)name
                             transaction:(InfinitLinkTransaction*)transaction
{
  NSDictionary* user_info = nil;
  if (transaction)
    user_info = @{kInfinitTransactionId: transaction.id_};
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self
                                                      userInfo:user_info];
  });
}

- (void)sendTransactionCreatedNotification:(InfinitLinkTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_LINK_TRANSACTION_CREATED_NOTIFICATION
                             transaction:transaction];
}

- (void)sendTransactionStatusNotification:(InfinitLinkTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION
                             transaction:transaction];
}

- (void)sendTransactionDataNotification:(InfinitLinkTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_LINK_TRANSACTION_DATA_NOTIFICATION
                             transaction:transaction];
}

- (void)sendNewTransactionNotification:(InfinitLinkTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_NEW_LINK_TRANSACTION_NOTIFICATION
                             transaction:transaction];
}

- (void)sendTransactionDeletedNotification:(InfinitLinkTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_LINK_TRANSACTION_DELETED_NOTIFICATION
                             transaction:transaction];
}

#pragma mark - Connection Status Changed

- (void)connectionStatusChanged:(NSNotification*)notification
{
  InfinitConnectionStatus* connection_status = notification.object;
  if (!self.filled_model && connection_status.status)
    [self _fillTransactionMap];
}

@end
