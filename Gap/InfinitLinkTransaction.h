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

@property (readonly) NSNumber* click_count;
@property (strong, readonly) NSNumber* id_;
@property (readonly) NSString* link;
@property (readonly) NSTimeInterval mtime;
@property (readonly) NSString* name;
@property (readonly) float progress;
@property (readonly) gap_TransactionStatus status;

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
   sender_device:(NSString*)sender_device
            name:(NSString*)name
           mtime:(NSTimeInterval)mtime
            link:(NSString*)link
     click_count:(NSNumber*)click_count;

- (void)updateWithTransaction:(InfinitLinkTransaction*)transaction;

@end
