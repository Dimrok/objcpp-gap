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
    _asset_map = [NSMutableDictionary dictionary];
    _total_size = @0;
  }
  return self;
}

@end
