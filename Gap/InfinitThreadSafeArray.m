//
//  InfinitThreadSafeArray.m
//  Gap
//
//  Created by Christopher Crone on 22/06/15.
//
//

#import "InfinitThreadSafeArray.h"

@interface InfinitThreadSafeArray ()

@property (nonatomic, readonly) NSMutableArray* array;
#if OS_OBJECT_HAVE_OBJC_SUPPORT
@property (nonatomic, readonly) dispatch_queue_t queue;
#else
@property (nonatomic, assign) dispatch_queue_t queue;
#endif
@property (nonatomic, readonly) BOOL nil_support;
@property (nonatomic, readonly) NSString* queue_name;

@end

@implementation InfinitThreadSafeArray

#pragma mark - Init

- (instancetype)initWithName:(NSString*)name
             withNilSupport:(BOOL)nil_support
{
  NSCAssert(name.length, @"Ensure name has length.");
  if (self = [super init])
  {
    _nil_support = nil_support;
    _queue_name = [NSString stringWithFormat:@"io.Infinit.ThreadSafeArray-%@", name];
    _queue = dispatch_queue_create(self.queue_name.UTF8String, DISPATCH_QUEUE_SERIAL);
    _array = [NSMutableArray array];
  }
  return self;
}

+ (instancetype)arrayWithName:(NSString*)name
               withNilSupport:(BOOL)nil_support
{
  return [[self alloc] initWithName:name withNilSupport:nil_support];
}

+ (instancetype)initWithName:(NSString*)name
{
  return [self arrayWithName:name withNilSupport:NO];
}

#pragma mark - Read

- (NSUInteger)count
{
  __block NSUInteger res = 0;
  dispatch_sync(self.queue, ^
  {
    res = self.array.count;
  });
  return res;
}

- (NSUInteger)indexOfObject:(id)anObject
{
  __block NSUInteger res = NSNotFound;
  dispatch_sync(self.queue, ^
  {
    res = [self.array indexOfObject:anObject];
  });
  return res;
}

- (id)objectAtIndex:(NSUInteger)index
{
  __block id res = nil;
  dispatch_sync(self.queue, ^
  {
    res = [self.array objectAtIndex:index];
  });
  return res;
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
  __block id res = nil;
  dispatch_sync(self.queue, ^
  {
    res = [self.array objectAtIndex:idx];
  });
  return res;
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL* stop))block
{
  dispatch_sync(self.queue, ^
  {
    [self.array enumerateObjectsUsingBlock:block];
  });
}

- (NSArray*)underlying_array
{
  __block NSArray* res = nil;
  dispatch_sync(self.queue, ^
  {
    res = [self.array copy];
  });
  return res;
}

#pragma mark - Write

- (void)addObject:(id)anObject
{
  dispatch_async(self.queue, ^
  {
    [self.array addObject:anObject];
  });
}

- (void)insertObject:(id)anObject
             atIndex:(NSUInteger)index
{
  dispatch_async(self.queue, ^
  {
    [self.array insertObject:anObject atIndex:index];
  });
}

- (void)removeAllObjects
{
  dispatch_async(self.queue, ^
  {
    [self.array removeAllObjects];
  });
}

- (void)removeObject:(id)anObject
{
  dispatch_async(self.queue, ^
  {
    [self.array removeObject:anObject];
  });
}

- (void)removeObjectAtIndex:(NSUInteger)index
{
  dispatch_async(self.queue, ^
  {
    [self.array removeObjectAtIndex:index];
  });
}

- (void)replaceObjectAtIndex:(NSUInteger)index
                  withObject:(id)anObject
{
  dispatch_async(self.queue, ^
  {
    [self.array replaceObjectAtIndex:index withObject:anObject];
  });
}

#pragma mark - NSObject

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%p %@: %@>", self, self.queue_name, self.array];
}

@end
