//
//  InfinitPeerTransaction.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitPeerTransaction.h"

@implementation InfinitPeerTransaction

- (id)initWithId:(NSNumber*)id_
          status:(gap_TransactionStatus)status
          sender:(InfinitUser*)sender
       recipient:(InfinitUser*)recipient
           files:(NSArray*)files
           mtime:(NSTimeInterval)mtime
         message:(NSString*)message
            size:(NSNumber*)size
       directory:(BOOL)directory
{
  if (self = [super init])
  {
    _id_ = [id_ copy];
    _sender = sender;
    _recipient = recipient;
    _files = files;
    _mtime = mtime;
    _message = [message copy];
    _size = [size copy];
    _directory = directory;
  }
  return self;
}

@end
