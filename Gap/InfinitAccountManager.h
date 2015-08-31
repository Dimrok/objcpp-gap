//
//  InfinitAccountManager.h
//  Gap
//
//  Created by Christopher Crone on 25/06/15.
//
//

#import <Foundation/Foundation.h>

#import "InfinitAccountUsageQuota.h"

/** Notification sent when the user's plan changes.
 Contains a dictionary with the plan name.
 */
#define INFINIT_ACCOUNT_PLAN_CHANGED @"INFINIT_ACCOUNT_PLAN_CHANGED"

/** Notification sent when one of the user's quotas or usage has been updated.
 */
#define INFINIT_ACCOUNT_QUOTA_UPDATED @"INFINIT_ACCOUNT_QUOTA_UPDATED"

/// Constant used as key for transaction ID in dictionaries.
#define kInfinitAccountPlanName @"name"

typedef NS_ENUM(NSUInteger, InfinitAccountPlanType)
{
  InfinitAccountPlanTypeBasic = 0,
  InfinitAccountPlanTypePlus,
  InfinitAccountPlanTypePremium,
  InfinitAccountPlanTypeTeam,

  InfinitAccountPlanTypeUninitialized,
};

@interface InfinitAccountManager : NSObject

@property (nonatomic, readonly) NSString* custom_domain;
@property (nonatomic, readonly) NSString* link_format;
@property (nonatomic, readonly) InfinitAccountUsageQuota* link_quota;
@property (nonatomic, readonly) InfinitAccountPlanType plan;
@property (nonatomic, readonly) NSString* plan_string;
@property (nonatomic, readonly) InfinitAccountUsageQuota* send_to_self_quota;
@property (nonatomic, readonly) uint64_t transfer_size_limit;

+ (instancetype)sharedInstance;

#pragma mark - State Manager Callback
- (void)accountUpdated:(InfinitAccountPlanType)plan
          customDomain:(NSString*)custom_domain
            linkFormat:(NSString*)link_format
             linkQuota:(InfinitAccountUsageQuota*)link_quota
       sendToSelfQuota:(InfinitAccountUsageQuota*)send_to_self_quota
         transferLimit:(uint64_t)transfer_limit;

@end
