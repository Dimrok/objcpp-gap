//
//  InfinitThreadSafeDictionary.m
//  Gap
//
//  Created by Christopher Crone on 20/04/15.
//
//

#import "InfinitThreadSafeDictionary.h"

@interface InfinitThreadSafeDictionary ()

@property (nonatomic, readonly) NSMutableDictionary* dictionary;
@property (atomic, readonly) BOOL finalize;
#if OS_OBJECT_HAVE_OBJC_SUPPORT
@property (nonatomic, readonly) dispatch_queue_t queue;
#else
@property (nonatomic, assign) dispatch_queue_t queue;
#endif
@property (nonatomic, readonly) NSString* queue_name;

@end

@implementation InfinitThreadSafeDictionary

- (instancetype)initWithName:(NSString*)name
{
  NSCAssert(name.length, @"Ensure name has length.");
  if (self = [super init])
  {
    _finalize = NO;
    _queue_name = [NSString stringWithFormat:@"io.Infinit.ThreadSafeDictionary-%@", name];
    _queue = dispatch_queue_create(self.queue_name.UTF8String, DISPATCH_QUEUE_SERIAL);
    _dictionary = [[NSMutableDictionary alloc] init];
  }
  return self;
}

+ (instancetype)initWithName:(NSString*)name
{
  return [[InfinitThreadSafeDictionary alloc] initWithName:name];
}

- (void)dealloc
{
  _finalize = YES;
  dispatch_barrier_sync(self.queue, ^{ /* wait */ });
}

#pragma mark - Getters

- (NSArray*)allKeys
{
  __block NSArray* res = nil;
  if (self.finalize)
    return res;
  dispatch_barrier_sync(self.queue, ^
  {
    res = self.dictionary.allKeys;
  });
  return res;
}

- (NSArray*)allValues
{
  __block NSArray* res = nil;
  if (self.finalize)
    return res;
  dispatch_barrier_sync(self.queue, ^
  {
    res = self.dictionary.allValues;
  });
  return res;
}

- (id)objectForKey:(id)key
{
  __block id res = nil;
  if (self.finalize)
    return res;
  dispatch_barrier_sync(self.queue, ^
  {
    res = [self.dictionary objectForKey:key];
  });
  return res;
}

- (id)objectForKeyedSubscript:(id)key
{
  __block id res = nil;
  if (self.finalize)
    return res;
  dispatch_barrier_sync(self.queue, ^
  {
    res = self.dictionary[key];
  });
  return res;
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL* stop))block
{
  if (self.finalize)
    return;
  dispatch_sync(self.queue, ^
  {
    [self.dictionary enumerateKeysAndObjectsUsingBlock:block];
  });
}

#pragma mark - Setters

- (void)setObject:(id)obj
           forKey:(id<NSCopying>)key
{
  if (self.finalize)
    return;
  dispatch_barrier_async(self.queue, ^
  {
    [self.dictionary setObject:obj forKey:key];
  });
}

- (void)setObject:(id)obj
forKeyedSubscript:(id <NSCopying>)key
{
  if (self.finalize)
    return;
  dispatch_barrier_async(self.queue, ^
  {
    self.dictionary[key] = obj;
  });
}

- (void)removeObjectForKey:(id)key
{
  if (self.finalize)
    return;
  dispatch_barrier_async(self.queue, ^
  {
    [self.dictionary removeObjectForKey:key];
  });
}

- (void)removeAllObjects
{
  if (self.finalize)
    return;
  dispatch_barrier_sync(self.queue, ^
  {
    [self.dictionary removeAllObjects];
  });
}

#pragma mark - NSObject

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%p %@: %@>", self, self.queue_name, self.dictionary];
}

@end
