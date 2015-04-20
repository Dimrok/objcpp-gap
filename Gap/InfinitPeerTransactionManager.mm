//
//  InfinitPeerTransactionManager.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitPeerTransactionManager.h"

#import "InfinitConnectionManager.h"
#import "InfinitDeviceManager.h"
#import "InfinitDirectoryManager.h"
#import "InfinitStateManager.h"
#import "InfinitThreadSafeDictionary.h"
#ifdef TARGET_OS_IPHONE
# import "InfinitTemporaryFileManager.h"
#endif

#import "NSString+email.h"
#import "NSString+PhoneNumber.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.PeerTransactionManager");

static InfinitPeerTransactionManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@interface InfinitPeerTransactionManager ()

@property (atomic, readonly) NSMutableArray* archived_transaction_ids;
@property (atomic, readonly) BOOL filled_model;
@property (atomic, readonly) InfinitThreadSafeDictionary* transaction_map;

@end

@implementation InfinitPeerTransactionManager
{
@private
  NSString* _archived_transactions_file;
}

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _filled_model = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel:)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionStatusChanged:)
                                                 name:INFINIT_CONNECTION_STATUS_CHANGE
                                               object:nil];
    NSString* dir = [InfinitDirectoryManager sharedInstance].persistent_directory;
    _archived_transactions_file = [dir stringByAppendingPathComponent:@"archived_transactions"];
    [self _fetchArchivedTransactions];
  }
  return self;
}

- (void)dealloc
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearModel:(NSNotification*)notification
{
  _instance = nil;
  _instance_token = 0;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitPeerTransactionManager alloc] init];
  });
  return _instance;
}

- (void)_fetchArchivedTransactions
{
  if ([[NSFileManager defaultManager] fileExistsAtPath:_archived_transactions_file isDirectory:NULL])
  {
    _archived_transaction_ids = [NSMutableArray arrayWithContentsOfFile:_archived_transactions_file];
    if (self.archived_transaction_ids == nil)
    {
      ELLE_ERR("%s: unable to read archived transactions file, removing",
               self.description.UTF8String);
      [[NSFileManager defaultManager] removeItemAtPath:_archived_transactions_file error:nil];
    }
  }
  if (self.archived_transaction_ids == nil)
    _archived_transaction_ids = [NSMutableArray array];
}

- (void)_fillTransactionMap
{
  _transaction_map = [[InfinitThreadSafeDictionary alloc] initWithName:@"PeerTransactionModel"];
  NSArray* transactions = [[InfinitStateManager sharedInstance] peerTransactions];
  for (InfinitPeerTransaction* transaction in transactions)
  {
    if ([self.archived_transaction_ids containsObject:transaction.meta_id])
      transaction.archived = YES;
    [self.transaction_map setObject:transaction forKey:transaction.id_];
  }
  _filled_model = YES;
}

#pragma mark - Access Transactions

- (NSArray*)archived_transaction_meta_ids
{
  return [self.archived_transaction_ids copy];
}

- (NSUInteger)receivable_transaction_count
{
  NSUInteger res = 0;
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if (transaction.receivable)
      res++;
  }
  return res;
}

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
  return [[self.transaction_map allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (InfinitPeerTransaction*)transactionWithId:(NSNumber*)id_
{
  @synchronized(self.transaction_map)
  {
    InfinitPeerTransaction* res = [self.transaction_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] peerTransactionById:id_];
    }
    return res;
  }
}

- (BOOL)unread_transactions
{
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if (transaction.unread)
      return YES;
  }
  return NO;
}

- (InfinitPeerTransaction*)transactionWithMetaId:(NSString*)meta_id
{
  @synchronized(self.transaction_map)
  {
    for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
    {
      if ([transaction.meta_id isEqualToString:meta_id])
        return transaction;
    }
  }
  return nil;
}

- (NSArray*)transactionsIncludingArchived:(BOOL)archived
                           thisDeviceOnly:(BOOL)device_only
{
  if (archived && !device_only)
  {
    return self.transactions;
  }
  else
  {
    NSMutableArray* res = [NSMutableArray array];
    for (InfinitPeerTransaction* transaction in self.transactions)
    {
      if (!archived && [self.archived_transaction_ids containsObject:transaction.meta_id])
        continue;
      if (device_only && !transaction.concerns_device)
        continue;
      [res addObject:transaction];
    }
    return res;
  }
}

#pragma mark - User Interaction

- (NSArray*)sendFiles:(NSArray*)files
         toRecipients:(NSArray*)recipients
          withMessage:(NSString*)message
{
  ELLE_TRACE("%s: send %lu files to %lu recipients",
             self.description.UTF8String, files.count, recipients.count);
  NSMutableArray* res = [NSMutableArray array];
  for (id recipient in recipients)
  {
    if (![recipient isKindOfClass:InfinitUser.class] &&
        ![recipient isKindOfClass:InfinitDevice.class] &&
        ![recipient isKindOfClass:NSString.class])
    {
      ELLE_ERR("%s: unable to send, recipient is not user, device or email",
               self.description.UTF8String);
      [res addObject:@0];
      continue;
    }
    if ([recipient isKindOfClass:NSString.class])
    {
      NSString* string = recipient;
      if (!string.isEmail && !string.isPhoneNumber)
      {
        ELLE_ERR("%s: unable to send, string is not valid email or phone number: %s",
                 self.description.UTF8String, string.UTF8String);
        [res addObject:@0];
        continue;
      }
    }
    else if ([recipient isKindOfClass:InfinitUser.class])
    {
      InfinitUser* user = recipient;
      if (user.id_.unsignedIntValue == 0)
      {
        ELLE_ERR("%s: unable to send, invalid user id: %s",
                 self.description.UTF8String, user.description.UTF8String);
        [res addObject:@0];
        continue;
      }
    }
    else if ([recipient isKindOfClass:InfinitDevice.class])
    {
      InfinitDevice* device = recipient;
      if ([[InfinitDeviceManager sharedInstance] deviceWithId:device.id_] == nil)
      {
        ELLE_ERR("%s: unable to send, unknown user device: %s",
                 self.description.UTF8String, device.description.UTF8String);
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
    if (transaction_id.unsignedIntValue != 0 &&
        ([recipient isKindOfClass:InfinitUser.class] || [recipient isKindOfClass:InfinitDevice.class]))
    {
      InfinitPeerTransaction* transaction =
        [[InfinitStateManager sharedInstance] peerTransactionById:transaction_id];
      [self transactionUpdated:transaction];
    }
  }
  [self sendTransactionCreatedNotification];
  return res;
}

- (NSNumber*)sendFiles:(NSArray*)files
           toRecipient:(InfinitUser*)recipient
              onDevice:(InfinitDevice*)device
           withMessage:(NSString*)message
{
  NSNumber* transaction_id = [[InfinitStateManager sharedInstance] sendFiles:files
                                                                 toRecipient:recipient
                                                                    onDevice:device.id_
                                                                 withMessage:message];
  if (transaction_id.unsignedIntValue != 0)
  {
    InfinitPeerTransaction* transaction =
      [[InfinitStateManager sharedInstance] peerTransactionById:transaction_id];
    [self transactionUpdated:transaction];
  }
  return transaction_id;
}

- (BOOL)acceptTransaction:(InfinitPeerTransaction*)transaction
                withError:(NSError**)error
{
  if (transaction.status != gap_transaction_waiting_accept)
  {
    ELLE_WARN("%s: ignoring accept for status: %s",
              self.description.UTF8String, transaction.status_text.UTF8String);
    return YES;
  }
  if ([InfinitDirectoryManager sharedInstance].free_space < transaction.size.unsignedIntegerValue)
  {
    if (error != NULL)
    {
      *error = [NSError errorWithDomain:INFINIT_FILE_SYSTEM_ERROR_DOMAIN
                                   code:InfinitFileSystemErrorNoFreeSpace
                               userInfo:nil];
    }
    return NO;
  }

  [[InfinitStateManager sharedInstance] acceptTransactionWithId:transaction.id_];
  transaction.status = gap_transaction_connecting;
  [transaction locallyAccepted];
  [self sendTransactionStatusNotification:transaction];
  [self onReceiveStarted:transaction];
  return YES;
}

- (void)onReceiveStarted:(InfinitPeerTransaction*)transaction
{
#if TARGET_OS_IPHONE
  NSString* path =
    [[InfinitDirectoryManager sharedInstance] downloadDirectoryForTransaction:transaction];
  if (path == nil)
  {
    ELLE_ERR("%s: unable to accept transaction, invalid download path",
             self.description.UTF8String);
  }
  NSDictionary* meta_data = @{@"sender": transaction.sender.meta_id,
                              @"sender_device": transaction.sender_device_id,
                              @"sender_fullname": transaction.sender.fullname,
                              @"ctime": @(transaction.mtime)};
  NSString* meta_file = [path stringByAppendingPathComponent:@".meta"];
  if (![meta_data writeToFile:meta_file atomically:YES])
  {
    ELLE_ERR("%s: unable to write transaction sender data: %s",
             self.description.UTF8String, transaction.sender.meta_id.UTF8String);
  }
#endif
}

- (void)rejectTransaction:(InfinitPeerTransaction*)transaction
{
  transaction.status = gap_transaction_rejected;
  [[InfinitStateManager sharedInstance] rejectTransactionWithId:transaction.id_];
  [self sendTransactionStatusNotification:transaction];
}

- (void)pauseTransaction:(InfinitPeerTransaction*)transaction
{
  transaction.status = gap_transaction_paused;
  [[InfinitStateManager sharedInstance] pauseTransactionWithId:transaction.id_];
  [self sendTransactionStatusNotification:transaction];
}

- (void)resumeTransaction:(InfinitPeerTransaction*)transaction
{
  transaction.status = gap_transaction_connecting;
  [[InfinitStateManager sharedInstance] resumeTransactionWithId:transaction.id_];
  [self sendTransactionStatusNotification:transaction];
}

- (void)cancelTransaction:(InfinitPeerTransaction*)transaction
{
  transaction.status = gap_transaction_canceled;
  [transaction locallyCanceled];
  [[InfinitStateManager sharedInstance] cancelTransactionWithId:transaction.id_];
  [self sendTransactionStatusNotification:transaction];
}

- (void)archiveIrrelevantTransactions
{
  if ([InfinitDeviceManager sharedInstance].other_devices.count == 0)
    return;
  NSMutableArray* to_archive = [NSMutableArray array];
  for (InfinitPeerTransaction* transaction in self.transactions)
  {
    if (!transaction.done ||
        (transaction.status == gap_transaction_cloud_buffered && transaction.recipient.is_self))
    {
      continue;
    }
    transaction.archived = YES;
    [to_archive addObject:transaction.meta_id];
  }
  if (self.archived_transaction_ids == nil)
    _archived_transaction_ids = [NSMutableArray array];
  [self.archived_transaction_ids addObjectsFromArray:to_archive];
  if (![self.archived_transaction_ids writeToFile:_archived_transactions_file atomically:YES])
  {
    ELLE_ERR("%s: unable to write archived transactions to disk", self.description.UTF8String);
  }
}

- (BOOL)canArchiveTransaction:(InfinitPeerTransaction*)transaction
{
  if (!transaction.done)
    return NO;
  return YES;
}

- (void)archiveTransaction:(InfinitPeerTransaction*)transaction
{
  if (![self canArchiveTransaction:transaction])
    return;
  transaction.archived = YES;
  if (transaction.meta_id.length == 0)
    return;
  if (self.archived_transaction_ids == nil)
    _archived_transaction_ids = [NSMutableArray array];

  [self.archived_transaction_ids addObject:transaction.meta_id];
  if (![self.archived_transaction_ids writeToFile:_archived_transactions_file atomically:YES])
  {
    ELLE_ERR("%s: unable to write archived transactions to disk", self.description.UTF8String);
  }
}

- (void)unarchiveTransaction:(InfinitPeerTransaction*)transaction
{
  if (!transaction.archived)
    return;
  transaction.archived = NO;
  [self.archived_transaction_ids removeObject:transaction.meta_id];
  if (![self.archived_transaction_ids writeToFile:_archived_transactions_file atomically:YES])
  {
    ELLE_ERR("%s: unable to write archived transactions to disk", self.description.UTF8String);
  }
}

- (void)markTransactionRead:(InfinitPeerTransaction*)transaction
{
  InfinitPeerTransaction* existing = [self transactionWithId:transaction.id_];
  existing.unread = NO;
}

#pragma mark - Per User

- (NSArray*)transactionsInvolvingUser:(InfinitUser*)user
{
  NSMutableArray* res = [NSMutableArray array];
  for (InfinitPeerTransaction* transaction in self.transactions)
  {
    if ([transaction.other_user isEqual:user])
      [res addObject:transaction];
  }
  return res;
}

- (NSUInteger)unreadTransactionsWithUser:(InfinitUser*)user
{
  NSUInteger res = 0;
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if ([transaction.other_user isEqual:user] && transaction.unread)
      res++;
  }
  return res;
}

- (void)markTransactionsWithUserRead:(InfinitUser*)user
{
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if ([transaction.other_user isEqual:user])
      transaction.unread = NO;
  }
}

- (NSUInteger)incompleteTransactionsWithUser:(InfinitUser*)user
{
  NSUInteger res = 0;
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if ([transaction.other_user isEqual:user] && !transaction.done)
      res++;
  }
  return res;
}

- (NSUInteger)transferringTransactionsWithUser:(InfinitUser*)user
{
  NSUInteger res = 0;
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if ([transaction.other_user isEqual:user] && transaction.status == gap_transaction_transferring)
      res++;
  }
  return res;
}

- (double)progressWithUser:(InfinitUser*)user
{
  double res = 0.0f;
  double total = 0.0f;
  for (InfinitPeerTransaction* transaction in self.transaction_map.allValues)
  {
    if ([transaction.other_user isEqual:user] && transaction.status == gap_transaction_transferring)
    {
      total += 1.0f;
      res += transaction.progress;
    }
  }
  return (res / total);
}

- (NSArray*)latestTransactionPerSwagger
{
  NSMutableSet* transaction_swaggers = [NSMutableSet set];
  NSMutableArray* res = [NSMutableArray array];
  NSArray* all_transactions = [self transactionsIncludingArchived:YES thisDeviceOnly:NO];
  for (InfinitPeerTransaction* transaction in all_transactions)
  {
    if (![transaction_swaggers containsObject:transaction.other_user])
    {
      [transaction_swaggers addObject:transaction.other_user];
      [res addObject:transaction];
    }
  }
  return res;
}

#pragma mark - Transaction Updated

- (void)handlePhoneTransaction:(InfinitPeerTransaction*)transaction
{
  if (transaction.from_device &&
      transaction.status == gap_transaction_transferring &&
      transaction.recipient.ghost_code.length > 0)
  {
    [self sendPhoneTransactionNotification:transaction];
  }
}

- (void)transactionUpdated:(InfinitPeerTransaction*)transaction
{
  @synchronized(self.transaction_map)
  {
    InfinitPeerTransaction* existing = [self.transaction_map objectForKey:transaction.id_];
    if (existing == nil)
    {
      [self.transaction_map setObject:transaction forKey:transaction.id_];
      [self sendNewTransactionNotification:transaction];
      [self handlePhoneTransaction:transaction];
    }
    else
    {
      gap_TransactionStatus old_status = existing.status;
      [existing updateWithTransaction:transaction];
      // Check if the transaction has been auto-accepted.
      if (existing.to_device &&
          old_status == gap_transaction_waiting_accept &&
          existing.status == gap_transaction_connecting)
      {
        [self onReceiveStarted:existing];
      }
      if (existing.status != old_status)
      {
        if (existing.status == gap_transaction_waiting_accept && existing.recipient_device.length)
          return;
        [self sendTransactionStatusNotification:existing];
        if (old_status == gap_transaction_waiting_accept && !existing.done)
          [self sendTransactionAcceptedNotification:existing];
      }
    }
  }
}

#pragma mark - Transaction Notifications

- (NSDictionary*)userInfoForTransaction:(InfinitPeerTransaction*)transaction
{
  return @{kInfinitTransactionId: transaction.id_};
}

- (void)postNotificationOnMainThreadName:(NSString*)name
                             transaction:(InfinitPeerTransaction*)transaction
{
  NSDictionary* user_info = nil;
  if (transaction)
    user_info = [self userInfoForTransaction:transaction];
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self
                                                      userInfo:user_info];
  });
}

- (void)postNotificationOnMainThreadName:(NSString*)name
{
  [self postNotificationOnMainThreadName:name transaction:nil];
}

- (void)sendTransactionAcceptedNotification:(InfinitPeerTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_PEER_TRANSACTION_ACCEPTED_NOTIFICATION
                             transaction:transaction];
}

- (void)sendTransactionCreatedNotification
{
  [self postNotificationOnMainThreadName:INFINIT_PEER_TRANSACTION_CREATED_NOTIFICATION];
}

- (void)sendTransactionStatusNotification:(InfinitPeerTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION
                             transaction:transaction];
}

- (void)sendPhoneTransactionNotification:(InfinitPeerTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_PEER_PHONE_TRANSACTION_NOTIFICATION
                             transaction:transaction];
}

- (void)sendNewTransactionNotification:(InfinitPeerTransaction*)transaction
{
  [self postNotificationOnMainThreadName:INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION 
                             transaction:transaction];
}

#pragma mark - Connection Status Changed

- (void)connectionStatusChanged:(NSNotification*)notification
{
  InfinitConnectionStatus* connection_status = notification.object;
  if (!self.filled_model && connection_status.status)
  {
    [self _fillTransactionMap];
    [self postNotificationOnMainThreadName:INFINIT_PEER_TRANSACTION_MODEL_READY_NOTIFICATION];
#if TARGET_OS_IPHONE
    dispatch_async(dispatch_get_main_queue(), ^
    {
      [[InfinitTemporaryFileManager sharedInstance] start];
    });
#endif
  }
}

@end
