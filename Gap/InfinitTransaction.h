//
//  InfinitTransaction.h
//  Gap
//
//  Created by Christopher Crone on 17/01/15.
//
//

#import <Foundation/Foundation.h>

#import <surface/gap/enums.hh>

/// Constant used as key for transaction ID in dictionaries.
#define kInfinitTransactionId @"id"
/// Constant used as key for transaction status in dictionaries. Status is stored as NSNumber.
#define kInfinitTransactionStatus @"status"

@interface InfinitTransaction : NSObject

@property (nonatomic, readwrite) BOOL archived;
@property (nonatomic, readonly) BOOL buffered;
@property (nonatomic, readonly) BOOL concerns_device;
@property (nonatomic, readonly) BOOL done;
@property (nonatomic, readonly) BOOL from_device;
@property (nonatomic, readonly) NSNumber* id_;
@property (nonatomic, readonly) NSString* message;
@property (nonatomic, readonly) NSString* meta_id;
@property (nonatomic, readonly) NSTimeInterval mtime;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) NSString* sender_device_id;
@property (nonatomic, readonly) NSNumber* size;
@property (nonatomic, readwrite) gap_TransactionStatus status; // Written to in order to fake updates.
@property (nonatomic, readonly) gap_Status status_info;
@property (nonatomic, readonly) NSString* status_text;
@property (nonatomic, readonly) NSTimeInterval time_remaining;

- (instancetype)initWithId:(NSNumber*)id_
                   meta_id:(NSString*)meta_id
                    status:(gap_TransactionStatus)status
                     mtime:(NSTimeInterval)mtime
                   message:(NSString*)message
                      size:(NSNumber*)size
          sender_device_id:(NSString*)sender_device_id
               status_info:(gap_Status)status_info;

- (void)updateWithTransaction:(InfinitTransaction*)transaction;

@end
