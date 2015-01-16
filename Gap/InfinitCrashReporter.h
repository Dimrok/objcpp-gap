//
//  InfinitCrashReporter.h
//  Gap
//
//  Created by Christopher Crone on 16/01/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitCrashReporter : NSObject

+ (instancetype)sharedInstance;

- (void)sendExistingCrashReport;

@end
