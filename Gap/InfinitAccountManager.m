//
//  InfinitAccountManager.m
//  Gap
//
//  Created by Christopher Crone on 25/06/15.
//
//

#import "InfinitAccountManager.h"

static InfinitAccountManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitAccountManager

#pragma mark - Init

- (instancetype)init
{
  NSCAssert(_instance == nil, @"Use sharedInstance.");
  if (self = [super init])
  {
  }
  return self;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[self alloc] init];
  });
  return _instance;
}

#pragma mark - State Manager Callback

- (void)accountUpdated:(InfinitAccountPlanType)plan
          customDomain:(NSString*)custom_domain
         linkSpaceUsed:(uint64_t)used
        linkSpaceQuota:(uint64_t)quota
{
  _plan = plan;
  _custom_domain = custom_domain;
  _link_space_used = used;
  _link_space_quota = quota;
}

@end
