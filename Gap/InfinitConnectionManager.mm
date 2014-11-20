//
//  InfinitConnectionManager.m
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import "InfinitConnectionManager.h"
#import "InfinitReachability.h"
#import "InfinitStateManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("iOS.ConnectionManager");

static InfinitConnectionManager* _instance = nil;

@implementation InfinitConnectionManager
{
  InfinitReachability* _reachability;
}

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    _reachability = [InfinitReachability reachabilityForInternetConnection];
    _network_status = [self networkStatusFromApple:[_reachability currentReachabilityStatus]];
    [_reachability startNotifier];
  }
  return self;
}

- (void)dealloc
{
  [_reachability stopNotifier];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  _reachability = nil;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitConnectionManager alloc] init];
  return _instance;
}

#pragma mark - Reachability

- (NSString*)statusString:(InfinitNetworkStatus)status
{
  switch (status)
  {
    case NotReachable:
      return @"NotReachable";
    case ReachableViaLAN:
      return @"ReachableViaLAN";
    case ReachableViaWWAN:
      return @"ReachableViaWWAN";
    default:
      return @"Unknown";
  }
}

- (InfinitNetworkStatus)networkStatusFromApple:(__NetworkStatus)status
{
  switch (status)
  {
    case __NotReachable:
      return NotReachable;
    case __ReachableViaWiFi:
      return ReachableViaLAN;
    case __ReachableViaWWAN:
      return ReachableViaWWAN;

    default:
      return NotReachable;
  }
}

- (void)setNetworkStatus:(InfinitNetworkStatus)status
{
  _network_status = status;
  [[InfinitStateManager sharedInstance] setNetworkConnectionStatus:self.network_status];
}

- (void)reachabilityChanged:(NSNotification*)notification
{
  [self setNetworkStatus:[self networkStatusFromApple:_reachability.currentReachabilityStatus]];
}

#pragma mark - State Manager Callback
- (void)setConnectedStatus:(BOOL)status
{
  _connected = status;
}

@end
