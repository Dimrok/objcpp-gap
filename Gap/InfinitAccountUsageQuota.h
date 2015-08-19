//
//  InfinitAccountUsageQuota.h
//  Gap
//
//  Created by Christopher Crone on 18/08/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitAccountUsageQuota : NSObject

@property (nonatomic, readonly) NSNumber* remaining;
@property (nonatomic, readonly) NSNumber* proportion_remaining;
@property (nonatomic, readonly) NSNumber* proportion_used;
@property (nonatomic, readonly) NSNumber* quota;
@property (nonatomic, readonly) NSNumber* usage;

+ (instancetype)accountUsage:(uint64_t)usage
                       quota:(uint64_t)quota;

+ (instancetype)accountUsage:(uint64_t)usage;

@end
