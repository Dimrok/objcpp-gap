//
//  InfinitLinkTransaction.m
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import "InfinitLinkTransaction.h"

#import "InfinitStateManager.h"

@implementation InfinitLinkTransaction
{
@private
  NSString* _sender_device_id;
}

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
   sender_device:(NSString*)sender_device
            name:(NSString*)name
           mtime:(NSTimeInterval)mtime
            link:(NSString*)link
     click_count:(NSNumber*)click_count
{
  if (self = [super init])
  {
    _id_ = id_;
    _status = status;
    _sender_device_id = sender_device;
    _name = name;
    _mtime = mtime;
    _link = link;
    _click_count = click_count;
  }
  return self;
}

- (void)updateWithTransaction:(InfinitLinkTransaction*)transaction
{
  _status = transaction.status;
  _mtime = transaction.mtime;
  _link = [transaction.link copy];
  _click_count = [transaction.click_count copy];
}

#pragma mark - Public

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
  if (![object isKindOfClass:InfinitLinkTransaction.class])
    return NO;
  InfinitLinkTransaction* other = object;
  if ([self.id_ isEqualToNumber:other.id_])
    return YES;
  return NO;
}

- (NSComparisonResult)compare:(id)object
{
  if (![object isKindOfClass:InfinitPeerTransaction.class])
    return NSOrderedAscending;
  InfinitLinkTransaction* other = object;
  if (self.mtime < other.mtime)
    return NSOrderedDescending;
  else if (self.mtime > other.mtime)
    return NSOrderedAscending;

  return NSOrderedSame;
}

@end
