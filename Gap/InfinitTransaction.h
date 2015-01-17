//
//  InfinitTransaction.h
//  Gap
//
//  Created by Christopher Crone on 17/01/15.
//
//

#import <Foundation/Foundation.h>

#import <surface/gap/enums.hh>

@interface InfinitTransaction : NSObject

@property (nonatomic, readonly) BOOL done;
@property (nonatomic, readonly) BOOL from_device;
@property (nonatomic, readonly) NSNumber* id_;
@property (nonatomic, readonly) NSString* message;
@property (nonatomic, readonly) NSTimeInterval mtime;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) NSString* sender_device_id;
@property (nonatomic, readonly) NSNumber* size; // Currently empty for link transactions.
@property (nonatomic, readonly) gap_TransactionStatus status;
@property (nonatomic, readonly) NSTimeInterval time_remaining;

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
           mtime:(NSTimeInterval)mtime
         message:(NSString*)message
            size:(NSNumber*)size
sender_device_id:(NSString*)sender_device_id;

- (void)updateWithTransaction:(InfinitTransaction*)transaction;

- (NSString*)statusText;

@end
