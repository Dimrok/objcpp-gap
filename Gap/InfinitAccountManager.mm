//
//  InfinitAccountManager.m
//  Gap
//
//  Created by Christopher Crone on 25/06/15.
//
//

#import "InfinitAccountManager.h"

#import "InfinitGapLocalizedString.h"
#import "InfinitStateManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.StateManager");

static InfinitAccountManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitAccountManager

#pragma mark - Init

- (instancetype)init
{
  NSCAssert(_instance == nil, @"Use sharedInstance.");
  if (self = [super init])
  {
    _link_quota = nil;
    _plan = InfinitAccountPlanTypeUninitialized;
    _send_to_self_quota = nil;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willLogout) 
                                                 name:INFINIT_WILL_LOGOUT_NOTIFICATION 
                                               object:nil];
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

#pragma mark - External

- (NSString*)plan_string
{
  return [self _stringPlanName:self.plan];
}

#pragma mark - State Manager Callback

- (void)accountUpdated:(InfinitAccountPlanType)plan
          customDomain:(NSString*)custom_domain
            linkFormat:(NSString*)link_format
             linkQuota:(InfinitAccountUsageQuota*)link_quota
       sendToSelfQuota:(InfinitAccountUsageQuota*)send_to_self_quota
         transferLimit:(uint64_t)transfer_limit
{
  BOOL plan_changed = NO;
  if (self.plan != InfinitAccountPlanTypeUninitialized && self.plan != plan)
    plan_changed = YES;
  BOOL quota_changed = NO;
  if ((self.link_quota != nil && ![self.link_quota isEqual:link_quota]) ||
      (self.send_to_self_quota != nil && ![self.send_to_self_quota isEqual:send_to_self_quota]))
  {
    quota_changed = YES;
  }
  _plan = plan;
  _custom_domain = custom_domain;
  if (link_format.length && [link_format componentsSeparatedByString:@"%@"].count == 3)
    _link_format = link_format;
  else
    _link_format = nil;
  _link_quota = link_quota;
  _send_to_self_quota = send_to_self_quota;
  _transfer_size_limit = transfer_limit;
  // Send notifications once model has been updated.
  if (plan_changed)
  {
    NSDictionary* user_info = @{kInfinitAccountPlanName: self.plan_string};
    [self sendNotificationOnMainThread:INFINIT_ACCOUNT_PLAN_CHANGED withUserInfo:user_info];
  }
  if (quota_changed)
    [self sendNotificationOnMainThread:INFINIT_ACCOUNT_QUOTA_UPDATED withUserInfo:nil];
}

#pragma mark - Helpers

- (void)sendNotificationOnMainThread:(NSString*)notification
                        withUserInfo:(NSDictionary*)user_info
{
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:notification
                                                        object:nil
                                                      userInfo:user_info];
  });
}

- (NSString*)_stringPlanName:(InfinitAccountPlanType)plan
{
  switch (plan)
  {
    case InfinitAccountPlanTypeBasic:
      return GapLocalizedString(@"Basic Plan", nil);
    case InfinitAccountPlanTypePlus:
      return GapLocalizedString(@"Plus Plan", nil);
    case InfinitAccountPlanTypePremium:
      return GapLocalizedString(@"Professional Plan", nil);
    case InfinitAccountPlanTypeTeam:
      return GapLocalizedString(@"Team Plan", nil);
    case InfinitAccountPlanTypeUninitialized:
      return GapLocalizedString(@"Unknown Plan", nil);
  }
}

#pragma - On Logout

- (void)willLogout
{
  _plan = InfinitAccountPlanTypeUninitialized;
}

@end
