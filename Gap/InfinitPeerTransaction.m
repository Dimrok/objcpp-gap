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
}

#pragma mark - Init

- (id)initWithId:(NSNumber*)id_
         meta_id:(NSString*)meta_id
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
  if (self = [super initWithId:id_
                       meta_id:meta_id
                        status:status
                         mtime:mtime
                       message:message
                          size:size
              sender_device_id:sender_device_id])
  {
    _sender_id = sender_id;
    _recipient_id = recipient_id;
    _files = files;
    _directory = directory;
  }
  return self;
}

#pragma mark - Update Transaction

- (void)updateWithTransaction:(InfinitPeerTransaction*)transaction
{
  [super updateWithTransaction:transaction];
  _recipient_id = transaction.recipient.id_;
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
      self.recipient.is_self && ![self.sender_device_id isEqualToString:self_device_id])
  {
    return YES;
  }
  else
  {
    return NO;
  }
}

#pragma mark - Description

- (NSString*)description
{
  return [NSString stringWithFormat:@"%@: %@", self.id_, [self statusText]];
}

@end
