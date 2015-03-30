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

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder*)decoder
{
  if (self = [super init])
  {
    _uuid = [decoder decodeObjectForKey:@"uuid"];
    _managed_paths =
      [NSMutableOrderedSet orderedSetWithArray:[decoder decodeObjectForKey:@"managed_paths"]];
    _root_dir = [decoder decodeObjectForKey:@"root_dir"];
    _total_size = [decoder decodeObjectForKey:@"total_size"];
    _asset_map = [decoder decodeObjectForKey:@"asset_map"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:self.uuid forKey:@"uuid"];
  [encoder encodeObject:self.managed_paths.array forKey:@"managed_paths"];
  [encoder encodeObject:self.root_dir forKey:@"root_dir"];
  [encoder encodeObject:self.total_size forKey:@"total_size"];
  [encoder encodeObject:self.asset_map forKey:@"asset_map"];
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
  return [NSString stringWithFormat:@"<InfinitManagedFiles %p: %@>", self, self.uuid];
}

@end
