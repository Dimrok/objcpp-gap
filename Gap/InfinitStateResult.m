//
//  InfinitStateResult.m
//  Infinit
//
//  Created by Christopher Crone on 29/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitStateResult.h"

@implementation InfinitStateResult

- (id)initWithStatus:(gap_Status)status
{
  if (self = [super init])
  {
    _status = status;
    _data = nil;
  }
  return self;
}

- (id)initWithStatus:(gap_Status)status
             andData:(id)data
{
  if (self = [super init])
  {
    _status = status;
    _data = data;
  }
  return self;
}

- (BOOL)success
{
  return (self.status == gap_ok);
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"status: %d \rdata:%@", self.status, self.data];
}

@end
