//
//  InfinitTime.h
//  Gap
//
//  Created by Christopher Crone on 17/01/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitTime : NSObject

+ (NSString*)relativeDateOf:(NSTimeInterval)timestamp
               longerFormat:(BOOL)longer;

+ (NSString*)timeRemainingFrom:(NSTimeInterval)seconds_left;

@end
