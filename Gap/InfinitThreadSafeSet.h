//
//  InfinitThreadSafeSet.h
//  Gap
//
//  Created by Christopher Crone on 01/05/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitThreadSafeSet : NSObject

+ (instancetype)initWithName:(NSString*)name;

- (BOOL)containsObject:(id)object;
- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL* stop))block;
- (NSArray*)allObjects;

- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (void)removeAllObjects;

@end
