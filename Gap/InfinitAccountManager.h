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

@property (nonatomic, readonly) NSString* custom_domain;
@property (nonatomic, readonly) NSString* link_format;
@property (nonatomic, readonly) uint64_t link_space_used;
@property (nonatomic, readonly) uint64_t link_space_quota;
@property (nonatomic, readonly) InfinitAccountPlanType plan;

+ (instancetype)sharedInstance;

#pragma mark - State Manager Callback
- (void)accountUpdated:(InfinitAccountPlanType)plan
          customDomain:(NSString*)custom_domain
            linkFormat:(NSString*)link_format
         linkSpaceUsed:(uint64_t)used
        linkSpaceQuota:(uint64_t)quota;

@end
