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

@property BOOL directory;
@property (strong, readonly) NSArray* files;
@property (strong, readonly) NSNumber* id_;
@property (strong, readonly) NSString* message;
@property (readonly) NSTimeInterval mtime;
@property (readonly) InfinitUser* recipient;
@property (readonly) BOOL receivable;
@property (readonly) InfinitUser* other_user;
@property (readonly) float progress;
@property (readonly) gap_TransactionStatus status;
@property (readonly) InfinitUser* sender;
@property (strong, readonly) NSNumber* size;

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
