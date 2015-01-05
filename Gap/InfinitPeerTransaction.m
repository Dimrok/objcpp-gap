//
//  InfinitPeerTransaction.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitPeerTransaction.h"

#import "InfinitStateManager.h"
#import "InfinitUserManager.h"

@implementation InfinitPeerTransaction
{
@private
  NSNumber* _sender_id;
  NSNumber* _recipient_id;
  NSString* _sender_device_id;
}

#pragma mark - Init

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
          sender:(NSNumber*)sender_id
   sender_device:(NSString*)sender_device_id
       recipient:(NSNumber*)recipient_id
           files:(NSArray*)files
           mtime:(NSTimeInterval)mtime
         message:(NSString*)message
            size:(NSNumber*)size
       directory:(BOOL)directory
{
  if (self = [super init])
  {
    _id_ = id_;
    _sender_id = sender_id;
    _sender_device_id = sender_device_id;
    _recipient_id = recipient_id;
    _files = files;
    _mtime = mtime;
    _message = message;
    _size = size;
    _status = status;
    _directory = directory;
  }
  return self;
}

#pragma mark - Update Transaction

- (void)updateWithTransaction:(InfinitPeerTransaction*)transaction
{
  _recipient_id = [transaction.recipient.id_ copy];
  _mtime = transaction.mtime;
  _status = transaction.status;
}

#pragma mark - Public

- (InfinitUser*)other_user
{
  if (self.sender.is_self)
    return self.recipient;
  else
    return self.sender;
}

- (InfinitUser*)sender
{
  return [[InfinitUserManager sharedInstance] userWithId:_sender_id];
}

- (InfinitUser*)recipient
{
  return [[InfinitUserManager sharedInstance] userWithId:_recipient_id];
}

- (BOOL)receivable
{
  NSString* self_device_id = [[InfinitStateManager sharedInstance] self_device_id];
  if (self.status == gap_transaction_waiting_accept &&
      self.recipient.is_self && ![_sender_device_id isEqualToString:self_device_id])
  {
    return YES;
  }
  else
  {
    return NO;
  }
}

- (BOOL)done
{
  switch (self.status)
  {
    case gap_transaction_cloud_buffered:
    case gap_transaction_finished:
    case gap_transaction_failed:
    case gap_transaction_canceled:
    case gap_transaction_rejected:
    case gap_transaction_deleted:
      return YES;

    default:
      return NO;
  }
}

- (float)progress
{
  if (self.status == gap_transaction_transferring)
    return [[InfinitStateManager sharedInstance] transactionProgressForId:self.id_];
  else if (self.done)
    return 1.0f;
  else
    return 0.0f;
}

#pragma mark - Comparison

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:InfinitPeerTransaction.class])
    return NO;
  InfinitPeerTransaction* other = object;
  if ([self.id_ isEqualToNumber:other.id_])
    return YES;
  return NO;
}

- (NSComparisonResult)compare:(id)object
{
  if (![object isKindOfClass:InfinitPeerTransaction.class])
    return NSOrderedAscending;
  InfinitPeerTransaction* other = object;
  if (self.mtime < other.mtime)
    return NSOrderedDescending;
  else if (self.mtime > other.mtime)
    return NSOrderedAscending;

  return NSOrderedSame;
}

#pragma mark - Description

- (NSString*)statusText
{
  switch (self.status)
  {
    case gap_transaction_new:
      return @"new";
    case gap_transaction_on_other_device:
      return @"on_other_device";
    case gap_transaction_waiting_accept:
      return @"waiting_accept";
    case gap_transaction_waiting_data:
      return @"waiting_data";
    case gap_transaction_connecting:
      return @"connecting";
    case gap_transaction_transferring:
      return @"transferring";
    case gap_transaction_cloud_buffered:
      return @"cloud_buffered";
    case gap_transaction_finished:
      return @"finished";
    case gap_transaction_failed:
      return @"failed";
    case gap_transaction_canceled:
      return @"canceled";
    case gap_transaction_rejected:
      return @"rejected";
    case gap_transaction_deleted:
      return @"deleted";
    case gap_transaction_paused:
      return @"paused";
    default:
      return @"unknown";
  }
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"%@: %@", self.id_, [self statusText]];
}

@end
