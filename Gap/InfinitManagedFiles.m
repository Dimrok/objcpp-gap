//
//  InfinitManagedFiles.m
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import "InfinitManagedFiles.h"

@implementation InfinitManagedFiles

- (id)init
{
  if (self = [super init])
  {
    _uuid = [NSUUID UUID].UUIDString;
    _managed_paths = [NSMutableOrderedSet orderedSet];
  }
  return self;
}

@end
