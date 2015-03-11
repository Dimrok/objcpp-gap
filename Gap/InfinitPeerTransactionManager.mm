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
#import "NSString+PhoneNumber.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.PeerTransactionManager");

static InfinitPeerTransactionManager* _instance = nil;

@interface InfinitPeerTransactionManager ()

@property (atomic, readonly) NSMutableArray* archived_transaction_ids;

@end

@implementation InfinitPeerTransactionManager
{
@private
  NSMutableDictionary* _transaction_map;
  NSString* _archived_transactions_file;
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
    NSString* dir = [InfinitDirectoryManager sharedInstance].persistent_directory;
    _archived_transactions_file = [dir stringByAppendingPathComponent:@"archived_transactions"];
    [self _fetchArchivedTransactions];
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
  _transaction_map = [NSMutableDictionary dictionary];
  NSArray* transactions = [[InfinitStateManager sharedInstance] peerTransactions];
  for (InfinitPeerTransaction* transaction in transactions)
  {
    if ([self.archived_transaction_ids containsObject:transaction.meta_id])
      transaction.archived = YES;
    [_transaction_map setObject:transaction forKey:transaction.id_];
  }
}

#pragma mark - Access Transactions

- (NSArray*)archived_transaction_meta_ids
{
  return [self.archived_transaction_ids copy];
}

- (BOOL)running_transactions
{
  for (InfinitPeerTransaction* transaction in _transaction_map.allValues)
  {
    if (transaction.status == gap_transaction_transferring)
      return YES;
  }
  return NO;
}

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

- (InfinitPeerTransaction*)transactionWithMetaId:(NSString*)meta_id
{
  @synchronized(_transaction_map)
  {
    for (InfinitPeerTransaction* transaction in _transaction_map.allValues)
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
      if (!string.isEmail && !string.isPhoneNumber)
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
                withError:(NSError**)error;
{
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
  NSString* path =
    [[InfinitDirectoryManager sharedInstance] downloadDirectoryForTransaction:transaction];
  if (path == nil)
  {
    if (error != NULL)
    {
      *error = [NSError errorWithDomain:INFINIT_FILE_SYSTEM_ERROR_DOMAIN
                                   code:InfinitFileSystemErrorPathDoesntExist
                               userInfo:nil];
    }
    ELLE_ERR("%s: unable to accept transaction, invalid download path",
             self.description.UTF8String);
    return NO;
  }
  NSDictionary* meta_data = @{@"sender": transaction.sender.meta_id,
                              @"sender_device": transaction.sender_device_id,
                              @"sender_fullname": transaction.sender.fullname,
                              @"ctime": @(transaction.mtime)};
  NSString* meta_file = [path stringByAppendingPathComponent:@".meta"];
  if (![meta_data writeToFile:meta_file atomically:YES])
  {
    if (error != NULL)
    {
      *error = [NSError errorWithDomain:INFINIT_FILE_SYSTEM_ERROR_DOMAIN
                                   code:InfinitFileSystemErrorUnableToWrite 
                               userInfo:nil];
    }
    ELLE_ERR("%s: unable to write transaction sender data: %s",
             self.description.UTF8String, transaction.sender.meta_id.UTF8String);
    return NO;
  }
  transaction.status = gap_transaction_connecting;
  [transaction locallyAccepted];
  [[InfinitStateManager sharedInstance] acceptTransactionWithId:transaction.id_
                                            toRelativeDirectory:transaction.meta_id];
  [self sendTransactionStatusNotification:transaction];
  return YES;
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
  NSMutableArray* to_archive = [NSMutableArray array];
  for (InfinitPeerTransaction* transaction in self.transactions)
  {
    if (!transaction.done)
      continue;
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

- (void)archiveTransaction:(InfinitPeerTransaction*)transaction
{
  if (!transaction.done)
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

#pragma mark - Transaction Updated

- (void)handlePhoneTransaction:(InfinitPeerTransaction*)transaction
{
  if (transaction.status == gap_transaction_transferring &&
      transaction.recipient.ghost_code.length > 0)
  {
    [self sendPhoneTransactionNotification:transaction];
  }
}

- (void)transactionUpdated:(InfinitPeerTransaction*)transaction
{
  @synchronized(_transaction_map)
  {
    InfinitPeerTransaction* existing = [_transaction_map objectForKey:transaction.id_];
    if (existing == nil)
    {
      [_transaction_map setObject:transaction forKey:transaction.id_];
      [self sendNewTransactionNotification:transaction];
      [self handlePhoneTransaction:transaction];
    }
    else
    {
      if (existing.status != transaction.status)
      {
        [existing updateWithTransaction:transaction];
        [self sendTransactionStatusNotification:existing];
        [self handlePhoneTransaction:existing];
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

- (void)sendPhoneTransactionNotification:(InfinitPeerTransaction*)transaction
{
  NSDictionary* user_info = @{@"id": transaction.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_PEER_PHONE_TRANSACTION_NOTIFICATION
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
