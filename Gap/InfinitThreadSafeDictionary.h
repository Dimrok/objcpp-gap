//
//  InfinitThreadSafeDictionary.h
//  Gap
//
//  Created by Christopher Crone on 20/04/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitThreadSafeDictionary : NSObject

+ (instancetype)initWithName:(NSString*)name;

- (NSArray*)allKeys;
- (NSArray*)allValues;

- (id)objectForKey:(id)key;
- (id)objectForKeyedSubscript:(id)key;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL* stop))block;

- (void)setObject:(id)obj forKey:(id<NSCopying>)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

- (void)removeObjectForKey:(id)key;
- (void)removeAllObjects;

@end
