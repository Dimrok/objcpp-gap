//
//  InfinitLinkTransaction.h
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import <Foundation/Foundation.h>

#import <surface/gap/enums.hh>

@interface InfinitLinkTransaction : NSObject

@property (nonatomic, readonly) NSNumber* click_count;
@property (nonatomic, readonly) NSNumber* id_;
@property (nonatomic, readonly) NSString* link;
@property (nonatomic, readonly) NSTimeInterval mtime;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) gap_TransactionStatus status;

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
   sender_device:(NSString*)sender_device
            name:(NSString*)name
           mtime:(NSTimeInterval)mtime
            link:(NSString*)link
     click_count:(NSNumber*)click_count;

- (void)updateWithTransaction:(InfinitLinkTransaction*)transaction;

@end
