//
//  InfinitThreadSafeDictionary.h
//  Gap
//
//  Created by Christopher Crone on 20/04/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitThreadSafeDictionary : NSObject

/// Init defaults to no nil support.
+ (instancetype)initWithName:(NSString*)name;
+ (instancetype)dictionaryWithName:(NSString*)name
                    withNilSupport:(BOOL)nil_support;

/// Reading is synchronous.
- (NSArray*)allKeys;
- (NSArray*)allValues;

- (id)objectForKey:(id)key;
- (id)objectForKeyedSubscript:(id)key;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL* stop))block;

/// Setting is asynchronous.
- (void)setObject:(id)obj forKey:(id<NSCopying>)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

/// Removing is asynchronous.
- (void)removeObjectForKey:(id)key;
- (void)removeAllObjects;

@end
