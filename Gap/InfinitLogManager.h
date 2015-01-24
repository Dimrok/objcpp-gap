//
//  InfinitLogManager.h
//  Gap
//
//  Created by Christopher Crone on 16/01/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitLogManager : NSObject

@property (nonatomic, readonly) NSString* crash_report_path;
@property (nonatomic, readonly) NSString* current_log_path;
@property (nonatomic, readonly) NSString* last_log_path;

+ (instancetype)sharedInstance;

@end
