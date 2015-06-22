//
//  InfinitThreadSafeArray.h
//  Gap
//
//  Created by Christopher Crone on 22/06/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitThreadSafeArray : NSObject

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSArray* underlying_array;

/// Init defaults to no nil support.
+ (instancetype)initWithName:(NSString*)name;

+ (instancetype)arrayWithName:(NSString*)name
               withNilSupport:(BOOL)nil_support;

- (NSUInteger)indexOfObject:(id)anObject;
- (id)objectAtIndex:(NSUInteger)index;
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL* stop))block;

- (void)addObject:(id)anObject;
- (void)insertObject:(id)anObject
             atIndex:(NSUInteger)index;

- (void)removeAllObjects;
- (void)removeObject:(id)anObject;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)replaceObjectAtIndex:(NSUInteger)index
                  withObject:(id)anObject;

@end
