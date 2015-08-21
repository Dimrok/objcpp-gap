//
//  InfinitAccountManager.m
//  Gap
//
//  Created by Christopher Crone on 25/06/15.
//
//

#import "InfinitAccountManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.StateManager");

@interface InfinitAccountManager ()

@property (nonatomic) InfinitAccountPlanType last_plan;

@end

static InfinitAccountManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitAccountManager

#pragma mark - Init

- (instancetype)init
{
  NSCAssert(_instance == nil, @"Use sharedInstance.");
  if (self = [super init])
  {
    _last_plan = InfinitAccountPlanTypeUninitialized;
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
            linkFormat:(NSString*)link_format
             linkQuota:(InfinitAccountUsageQuota*)link_quota
       sendToSelfQuota:(InfinitAccountUsageQuota*)send_to_self_quota
         transferLimit:(uint64_t)transfer_limit
{
  _plan = plan;
  if (self.last_plan != InfinitAccountPlanTypeUninitialized && self.plan != self.last_plan)
  {
    NSDictionary* user_info = @{kInfinitAccountPlanName: [self _stringPlanName:self.plan]};
    dispatch_async(dispatch_get_main_queue(), ^
    {
      [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_ACCOUNT_PLAN_CHANGED
                                                          object:nil
                                                        userInfo:user_info];
    });
  }
  _last_plan = self.plan;
  _custom_domain = custom_domain;
  if (link_format.length && [link_format componentsSeparatedByString:@"%@"].count == 3)
    _link_format = link_format;
  else
    _link_format = nil;
  _link_quota = link_quota;
  _send_to_self_quota = send_to_self_quota;
  _transfer_size_limit = transfer_limit;
}

#pragma mark - Helpers

- (NSString*)_stringPlanName:(InfinitAccountPlanType)plan
{
  switch (plan)
  {
    case InfinitAccountPlanTypeBasic:
      return @"Basic";
    case InfinitAccountPlanTypePlus:
      return @"Plus";
    case InfinitAccountPlanTypePremium:
      return @"Professional";
    case InfinitAccountPlanTypeUninitialized:
      return @"Unknown";
  }
}

@end
