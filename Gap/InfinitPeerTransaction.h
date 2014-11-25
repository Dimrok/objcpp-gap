//
//  InfinitPeerTransaction.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <surface/gap/enums.hh>

#import "InfinitUser.h"

@interface InfinitPeerTransaction : NSObject

@property (nonatomic, readonly) BOOL directory;
@property (nonatomic, readonly) NSArray* files;
@property (nonatomic, readonly) NSNumber* id_;
@property (nonatomic, readonly) NSString* message;
@property (nonatomic, readonly) NSTimeInterval mtime;
@property (nonatomic, readonly) InfinitUser* recipient;
@property (nonatomic, readonly) BOOL receivable;
@property (nonatomic, readonly) InfinitUser* other_user;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) gap_TransactionStatus status;
@property (nonatomic, readonly) InfinitUser* sender;
@property (nonatomic, readonly) NSNumber* size;

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
          sender:(NSNumber*)sender_id
   sender_device:(NSString*)sender_device_id
       recipient:(NSNumber*)recipient_id
           files:(NSArray*)files
           mtime:(NSTimeInterval)mtime
         message:(NSString*)message
            size:(NSNumber*)size
       directory:(BOOL)directory;

- (void)updateWithTransaction:(InfinitPeerTransaction*)transaction;

@end
