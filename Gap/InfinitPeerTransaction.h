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
@property (strong) NSArray* files;
@property (strong) NSNumber* id_;
@property (strong) NSString* message;
@property NSTimeInterval mtime;
@property (weak) InfinitUser* recipient;
@property gap_TransactionStatus status;
@property (weak) InfinitUser* sender;
@property (strong) NSNumber* size;

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
          sender:(InfinitUser*)sender
       recipient:(InfinitUser*)recipient
           files:(NSArray*)files
           mtime:(NSTimeInterval)mtime
         message:(NSString*)message
            size:(NSNumber*)size
       directory:(BOOL)directory;

@end
