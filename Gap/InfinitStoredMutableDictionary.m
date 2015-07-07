//
//  InfinitStoredMutableDictionary.m
//  Gap
//
//  Created by Christopher Crone on 27/03/15.
//
//

#import "InfinitStoredMutableDictionary.h"

@interface InfinitStoredMutableDictionary () <NSKeyedUnarchiverDelegate>

@property (atomic, readonly) BOOL finalizing;
@property (atomic, readonly) NSMutableDictionary* dictionary;
@property (nonatomic, readonly) NSString* path;

@property (nonatomic, readonly) dispatch_queue_t dict_queue;
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
    _finalizing = NO;
    NSString* general_name = @"io.Infinit.StoredMutableDictionary";
    NSString* dict_queue_name =
      [NSString stringWithFormat:@"%@(dictionary)-%@", general_name, self.path.lastPathComponent];
    _dict_queue = dispatch_queue_create(dict_queue_name.UTF8String, DISPATCH_QUEUE_SERIAL);
    NSString* disk_queue_name =
      [NSString stringWithFormat:@"%@(disk)-%@", general_name, self.path.lastPathComponent];
    _disk_queue = dispatch_queue_create(disk_queue_name.UTF8String, DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)finalize
{
  _finalizing = YES;
  dispatch_sync(self.disk_queue, ^{ /* Wait for all disk writes */ });
}

+ (instancetype)dictionaryWithContentsOfFile:(NSString*)file
{
  return [[InfinitStoredMutableDictionary alloc] initWithContentsOfFile:file];
}

#pragma mark - Read

- (NSArray*)allKeys
{
  __block NSArray* res = nil;
  dispatch_sync(self.dict_queue, ^
  {
    res = self.dictionary.allKeys;
  });
  return res;
}

- (NSArray*)allKeysForObject:(id<NSCoding>)object
{
  __block NSArray* res = nil;
  dispatch_sync(self.dict_queue, ^
  {
    res = [self.dictionary allKeysForObject:object];
  });
  return res;
}

- (NSArray*)allValues
{
  __block NSArray* res = nil;
  dispatch_sync(self.dict_queue, ^
  {
    res = self.dictionary.allValues;
  });
  return res;
}

- (id)objectForKey:(id<NSCoding>)aKey
{
  __block id res = nil;
  dispatch_sync(self.dict_queue, ^
  {
    res = [self.dictionary objectForKey:aKey];
  });
  return res;
}

#pragma mark - Write

- (void)setObject:(id<NSCoding>)anObject
           forKey:(id<NSCoding, NSCopying>)aKey
{
  if (self.finalizing)
    return;
  dispatch_async(self.dict_queue, ^
  {
    [self.dictionary setObject:anObject forKey:aKey];
    [self storeDictionary];
  });
}

- (void)removeObjectForKey:(id<NSCoding>)aKey
{
  if (self.finalizing)
    return;
  dispatch_async(self.dict_queue, ^
  {
    [self.dictionary removeObjectForKey:aKey];
    [self storeDictionary];
  });
}

#pragma mark - NSObject

- (NSString*)description
{
  __block NSString* res = nil;
  dispatch_sync(self.dict_queue, ^
  {
    res = self.dictionary.description;
  });
  return res;
}

#pragma mark - Helpers

- (void)storeDictionary
{
  dispatch_async(self.disk_queue, ^
  {
    [NSKeyedArchiver archiveRootObject:self.dictionary toFile:self.path];
  });
}

@end
