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
            linkFormat:(NSString*)link_format
             linkQuota:(InfinitAccountUsageQuota*)link_quota
       sendToSelfQuota:(InfinitAccountUsageQuota*)send_to_self_quota
         transferLimit:(uint64_t)transfer_limit
{
  _plan = plan;
  _custom_domain = custom_domain;
  if (link_format.length && [link_format componentsSeparatedByString:@"%@"].count == 3)
    _link_format = link_format;
  else
    _link_format = nil;
  _link_quota = link_quota;
  _send_to_self_quota = send_to_self_quota;
  _transfer_size_limit = transfer_limit;
}

@end
