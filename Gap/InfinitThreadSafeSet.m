//
//  InfinitThreadSafeSet.m
//  Gap
//
//  Created by Christopher Crone on 01/05/15.
//
//

#import "InfinitThreadSafeSet.h"

@interface InfinitThreadSafeSet ()

@property (atomic, readonly) BOOL finalize;
@property (nonatomic, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly) NSString* queue_name;
@property (nonatomic, readonly) NSMutableSet* set;

@end

@implementation InfinitThreadSafeSet

#pragma mark - Init

- (instancetype)initWithName:(NSString*)name
{
  NSCAssert(name.length, @"Ensure name has length.");
  if (self = [super init])
  {
    _queue_name = [NSString stringWithFormat:@"io.Infinit.ThreadSafeSet-%@", name];
    _queue = dispatch_queue_create(self.queue_name.UTF8String, DISPATCH_QUEUE_SERIAL);
    _set = [NSMutableSet set];
    _finalize = nil;
  }
  return self;
}

+ (instancetype)initWithName:(NSString*)name
{
  return [[InfinitThreadSafeSet alloc] initWithName:name];
}

- (void)dealloc
{
  _finalize = YES;
  dispatch_barrier_sync(self.queue, ^{ /* wait */ });
}

#pragma mark - Read

- (BOOL)containsObject:(id)object;
{
  __block BOOL res = NO;
  if (self.finalize)
    return res;
  dispatch_sync(self.queue, ^
  {
    res = [self.set containsObject:object];
  });
  return res;
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL* stop))block
{
  if (self.finalize)
    return;
  dispatch_sync(self.queue, ^
  {
    [self.set enumerateObjectsUsingBlock:block];
  });
}

- (NSArray*)allObjects
{
  __block NSArray* res = nil;

  dispatch_sync(self.queue, ^
  {
    res = self.set.allObjects;
  });
  return res;
}

#pragma mark - Write

- (void)addObject:(id)object
{
  if (self.finalize)
    return;
  dispatch_async(self.queue, ^
  {
    [self.set addObject:object];
  });
}

- (void)removeObject:(id)object
{
  if (self.finalize)
    return;
  dispatch_async(self.queue, ^
  {
    [self.set removeObject:object];
  });
}

- (void)removeAllObjects
{
  if (self.finalize)
    return;
  dispatch_async(self.queue, ^
  {
    [self.set removeAllObjects];
  });
}

#pragma mark - NSObject

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%p %@: %@>", self, self.queue_name, self.set.description];
}

@end
