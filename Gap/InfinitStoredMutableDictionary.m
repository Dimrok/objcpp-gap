//
//  InfinitStoredMutableDictionary.m
//  Gap
//
//  Created by Christopher Crone on 27/03/15.
//
//

#import "InfinitStoredMutableDictionary.h"

@interface InfinitStoredMutableDictionary () <NSKeyedUnarchiverDelegate>

@property (atomic, readonly) BOOL deallocing;
@property (atomic, readonly) NSMutableDictionary* dictionary;
@property (nonatomic, readonly) NSString* path;

@property (nonatomic, readonly) dispatch_queue_t disk_queue;

@end

@implementation InfinitStoredMutableDictionary

#pragma mark - Init

- (instancetype)initWithContentsOfFile:(NSString*)file
{
  if (self = [super init])
  {
    _path = file;
    if ([[NSFileManager defaultManager] fileExistsAtPath:file])
      _dictionary = [NSKeyedUnarchiver unarchiveObjectWithFile:self.path];

    if (self.dictionary == nil)
      _dictionary = [NSMutableDictionary dictionary];

    _deallocing = NO;
    NSString* queue_name =
      [NSString stringWithFormat:@"io.Infinit.StoredMutableDictionary-%@", self.path.lastPathComponent];
    _disk_queue = dispatch_queue_create(queue_name.UTF8String, DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)dealloc
{
  _deallocing = YES;
  dispatch_sync(self.disk_queue, ^{ /* Wait for all disk writes */ });
}

+ (instancetype)dictionaryWithContentsOfFile:(NSString*)file
{
  return [[InfinitStoredMutableDictionary alloc] initWithContentsOfFile:file];
}

#pragma mark - Read

- (NSArray*)allKeys
{
  return self.dictionary.allKeys;
}

- (NSArray*)allKeysForObject:(id<NSCoding>)object
{
  return [self.dictionary allKeysForObject:object];
}

- (NSArray*)allValues
{
  return self.dictionary.allValues;
}

- (id)objectForKey:(id<NSCoding>)aKey
{
  return [self.dictionary objectForKey:aKey];
}

#pragma mark - Write

- (void)setObject:(id<NSCoding>)anObject
           forKey:(id<NSCoding, NSCopying>)aKey
{
  if (self.deallocing)
    return;
  [self.dictionary setObject:anObject forKey:aKey];
  dispatch_async(self.disk_queue, ^
  {
    [self storeDictionary];
  });
}

- (void)removeObjectForKey:(id<NSCoding>)aKey
{
  if (self.deallocing)
    return;
  [self.dictionary removeObjectForKey:aKey];
  dispatch_async(self.disk_queue, ^
  {
    [self storeDictionary];
  });
}

#pragma mark - NSObject

- (NSString*)description
{
  return self.dictionary.description;
}

#pragma mark - Helpers

- (void)storeDictionary
{
  [NSKeyedArchiver archiveRootObject:self.dictionary toFile:self.path];
}

@end
