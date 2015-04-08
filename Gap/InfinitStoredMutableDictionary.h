//
//  InfinitStoredMutableDictionary.h
//  Gap
//
//  Created by Christopher Crone on 27/03/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitStoredMutableDictionary : NSObject

+ (instancetype)dictionaryWithContentsOfFile:(NSString*)file;

- (NSArray*)allKeys;
- (NSArray*)allKeysForObject:(id<NSCoding>)object;

- (NSArray*)allValues;

- (id)objectForKey:(id<NSCoding>)aKey;

- (void)removeObjectForKey:(id<NSCoding>)aKey;
- (void)setObject:(id<NSCoding>)anObject
           forKey:(id<NSCoding, NSCopying>)aKey;

- (void)finalize;

@end
