//
//  InfinitUser.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitUser.h"

@implementation InfinitUser

- (id)initWithId:(NSNumber*)id_
          status:(BOOL)status
        fullname:(NSString*)fullname
          handle:(NSString*)handle
         deleted:(BOOL)deleted
           ghost:(BOOL)ghost
{
  if (self = [super init])
  {
    _id_ = [id_ copy];
    _status = status;
    _fullname = [fullname copy];
    _handle = [handle copy];
    _deleted = deleted;
    _ghost = ghost;
  }
  return self;
}

@end
