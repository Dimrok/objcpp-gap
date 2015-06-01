//
//  NSNotificationCenter+Debug.h
//  Gap
//
//  Created by Christopher Crone on 01/06/15.
//
//

#ifdef DEBUG

# import <Foundation/Foundation.h>

@interface NSNotificationCenter (Debug)

- (NSArray*)observersForNotificationWithName:(NSString*)name;

@end

#endif