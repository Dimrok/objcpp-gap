//
//  InfinitTransaction.m
//  Gap
//
//  Created by Christopher Crone on 17/01/15.
//
//

#import "InfinitTransaction.h"

#import "InfinitStateManager.h"

@implementation InfinitTransaction
{
@private
  // Progress calculation.
  NSMutableArray* _data_points;
  double _last_progress;
  NSTimeInterval _last_time;
}

@synthesize time_remaining = _time_remaining;

#pragma mark - Init

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
           mtime:(NSTimeInterval)mtime
         message:(NSString*)message
            size:(NSNumber*)size
sender_device_id:(NSString *)sender_device_id
{
  if (self = [super init])
  {
    _id_ = id_;
    _status = status;
    _mtime = mtime;
    _message = message;
    _size = size;
    _sender_device_id = sender_device_id;
  }
  return self;
}

#pragma mark - Properties

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

- (BOOL)from_device
{
  NSString* self_device_id = [[InfinitStateManager sharedInstance] self_device_id];
  if ([self.sender_device_id isEqualToString:self_device_id])
    return YES;
  return NO;
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

- (NSTimeInterval)time_remaining
{
  if (!gap_transaction_transferring)
    return 0.0f;
  return _time_remaining;
}

#pragma mark - Update

- (void)updateWithTransaction:(InfinitTransaction*)transaction
{
  _status = transaction.status;
  _mtime = transaction.mtime;
}

- (void)updateTimeRemainingWithCurrentProgress:(CGFloat)current_progress
{
  NSTimeInterval current_time = [NSDate timeIntervalSinceReferenceDate];
  NSTimeInterval time_interval = current_time - _last_time;
  double rate = (current_progress - _last_progress) / time_interval;
  if (_data_points.count < 30)
  {
    [_data_points addObject:[NSNumber numberWithDouble:rate]];
  }
  else
  {
    [_data_points removeObjectAtIndex:0];
    [_data_points addObject:[NSNumber numberWithDouble:rate]];
  }
  _last_time = current_time;

  double avg_rate = 0.0f;
  for (NSNumber* rate in _data_points)
  {
    avg_rate += rate.doubleValue / _data_points.count;
  }
  double progress_remaining = (1.0f - current_progress);
  if (avg_rate > 0.0f)
    _time_remaining = (progress_remaining / avg_rate);
  else
    _time_remaining = 0.0f;
}

#pragma mark - Comparison

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:InfinitTransaction.class])
    return NO;
  InfinitTransaction* other = object;
  if ([self.id_ isEqualToNumber:other.id_])
    return YES;
  return NO;
}

- (NSComparisonResult)compare:(id)object
{
  if (![object isKindOfClass:InfinitTransaction.class])
    return NSOrderedAscending;
  InfinitTransaction* other = object;
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

@end
