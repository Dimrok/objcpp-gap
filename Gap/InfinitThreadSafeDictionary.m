//
//  InfinitThreadSafeDictionary.m
//  Gap
//
//  Created by Christopher Crone on 20/04/15.
//
//

#import "InfinitThreadSafeDictionary.h"

@interface InfinitThreadSafeDictionary ()

@property (readonly, strong) NSMutableDictionary* dictionary;
#if OS_OBJECT_HAVE_OBJC_SUPPORT
@property (readonly, strong) dispatch_queue_t queue;
#else
@property (readonly, assign) dispatch_queue_t queue;
#endif
@property (atomic, readonly) BOOL finalize;

@end

@implementation InfinitThreadSafeDictionary

- (instancetype)initWithName:(NSString*)name
{
  if (self = [super init])
  {
    _finalize = NO;
    NSString* queue_name = [NSString stringWithFormat:@"io.Infinit.ThreadSafeDictionary-%@", name];
    _queue = dispatch_queue_create(queue_name.UTF8String, DISPATCH_QUEUE_SERIAL);
    _dictionary = [[NSMutableDictionary alloc] init];
  }
  return self;
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
  dispatch_barrier_sync(self.queue, ^
  {
    if (self.finalize)
      return;
    res = self.dictionary.allKeys;
  });
  return res;
}

- (NSArray*)allValues
{
  __block NSArray* res = nil;
  dispatch_barrier_sync(self.queue, ^
  {
    if (self.finalize)
      return;
    res = self.dictionary.allValues;
  });
  return res;
}

- (id)objectForKey:(id)key
{
  __block id res = nil;
  dispatch_barrier_sync(self.queue, ^
  {
    if (self.finalize)
      return;
    res = [self.dictionary objectForKey:key];
  });
  return res;
}

- (id)objectForKeyedSubscript:(id)key
{
  __block id res = nil;
  dispatch_barrier_sync(self.queue, ^
  {
    if (self.finalize)
      return;
    res = self.dictionary[key];
  });
  return res;
}

#pragma mark - Setters

- (void)setObject:(id)obj
           forKey:(id<NSCopying>)key
{
  dispatch_barrier_async(self.queue, ^
  {
    if (self.finalize)
      return;
    [self.dictionary setObject:obj forKey:key];
  });
}

- (void)setObject:(id)obj
forKeyedSubscript:(id <NSCopying>)key
{
  dispatch_barrier_async(self.queue, ^
  {
    if (self.finalize)
      return;
    self.dictionary[key] = obj;
  });
}

- (void)removeObjectForKey:(id)key
{
  dispatch_barrier_async(self.queue, ^
  {
    if (self.finalize)
      return;
    [self.dictionary removeObjectForKey:key];
  });
}

- (void)removeAllObjects
{
  dispatch_barrier_sync(self.queue, ^
  {
    if (self.finalize)
      return;
    [self.dictionary removeAllObjects];
  });
}

@end
