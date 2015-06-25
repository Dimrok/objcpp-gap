//
//  InfinitAccountManager.h
//  Gap
//
//  Created by Christopher Crone on 25/06/15.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, InfinitAccountPlanType)
{
  InfinitAccountPlanTypeBasic = 0,
  InfinitAccountPlanTypePremium,
};

@interface InfinitAccountManager : NSObject

@property (nonatomic, readonly) InfinitAccountPlanType plan;
@property (nonatomic, readonly) uint64_t link_space_used;
@property (nonatomic, readonly) uint64_t link_space_quota;

+ (instancetype)sharedInstance;

#pragma mark - State Manager Callback
- (void)accountUpdated:(InfinitAccountPlanType)plan
         linkSpaceUsed:(uint64_t)used
        linkSpaceQuota:(uint64_t)quota;

@end
