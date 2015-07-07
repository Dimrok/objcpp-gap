//
//  InfinitManagedFiles.m
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import "InfinitManagedFiles.h"

@implementation InfinitManagedFiles

@synthesize copying = _copying;

#pragma mark - Init

- (id)init
{
  if (self = [super init])
  {
    _uuid = [NSUUID UUID].UUIDString;
    _managed_paths = [NSMutableOrderedSet orderedSet];
    _asset_map = [NSMutableDictionary dictionary];
    _remove_assets = [NSMutableSet set];
  }
  return self;
}

#pragma mark - Public

- (NSUInteger)file_count
{
  return self.managed_paths.count;
}

- (BOOL)copying
{
  @synchronized(self)
  {
    return _copying;
  }
}

- (void)setCopying:(BOOL)copying
{
  @synchronized(self)
  {
    _copying = copying;
    if (!copying)
    {
      for (id asset_ref in self.remove_assets)
      {
        NSString* path = [self.asset_map objectForKey:asset_ref];
        [self.asset_map removeObjectForKey:asset_ref];
        if (path)
        {
          [self.managed_paths removeObject:path];
          [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }
      }
      if (self.done_copying_block)
      {
        dispatch_sync(dispatch_get_main_queue(), ^
        {
          self.done_copying_block();
        });
      }
    }
  }
}

- (NSArray*)sorted_paths
{
  return [self.managed_paths.array sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder*)decoder
{
  if (self = [super init])
  {
    _uuid = [decoder decodeObjectForKey:@"uuid"];
    _managed_paths =
      [NSMutableOrderedSet orderedSetWithArray:[decoder decodeObjectForKey:@"managed_paths"]];
    _root_dir = [decoder decodeObjectForKey:@"root_dir"];
    _total_size = [[decoder decodeObjectForKey:@"total_size"] unsignedIntegerValue];
    _asset_map = [decoder decodeObjectForKey:@"asset_map"];
    _remove_assets = [decoder decodeObjectForKey:@"remove_assets"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:self.uuid forKey:@"uuid"];
  [encoder encodeObject:self.managed_paths.array forKey:@"managed_paths"];
  [encoder encodeObject:self.root_dir forKey:@"root_dir"];
  [encoder encodeObject:@(self.total_size) forKey:@"total_size"];
  [encoder encodeObject:self.asset_map forKey:@"asset_map"];
  [encoder encodeObject:self.remove_assets forKey:@"remove_assets"];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:InfinitManagedFiles.class])
    return NO;
  InfinitManagedFiles* other = (InfinitManagedFiles*)object;
  if ([self.uuid isEqualToString:other.uuid])
    return YES;
  return NO;
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<InfinitManagedFiles %p (%@): %@>",
          self, self.uuid, self.managed_paths];
}

@end
