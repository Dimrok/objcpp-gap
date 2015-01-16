//
//  InfinitLogManager.h
//  Gap
//
//  Created by Christopher Crone on 16/01/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitLogManager : NSObject

+ (instancetype)sharedInstance;

- (NSString*)crashReportPath;
- (NSString*)currentLogPath;
- (NSString*)lastLogPath;

@end
