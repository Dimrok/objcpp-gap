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

ELLE_LOG_COMPONENT("Gap-ObjC++.ConnectionManager");

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
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

- (void)clearModel
{
  _was_logged_in = NO;
}

#pragma mark - Reachability

- (NSString*)statusString:(InfinitNetworkStatuses)status
{
  switch (status)
  {
    case InfinitNetworkStatusNotReachable:
      return @"NotReachable";
    case InfinitNetworkStatusReachableViaLAN:
      return @"ReachableViaLAN";
    case InfinitNetworkStatusReachableViaWWAN:
      return @"ReachableViaWWAN";
    default:
      return @"Unknown";
  }
}

- (InfinitNetworkStatuses)networkStatusFromApple:(__NetworkStatus)status
{
  switch (status)
  {
    case __NotReachable:
      return InfinitNetworkStatusNotReachable;
    case __ReachableViaWiFi:
      return InfinitNetworkStatusReachableViaLAN;
    case __ReachableViaWWAN:
      return InfinitNetworkStatusReachableViaWWAN;

    default:
      return InfinitNetworkStatusNotReachable;
  }
}

- (void)setNetworkStatus:(InfinitNetworkStatuses)status
{
  if (_network_status != status)
  {
    _network_status = status;
    [[InfinitStateManager sharedInstance] setNetworkConnectionStatus:self.network_status];
    NSDictionary* user_info =
      @{@"connection_type": [NSNumber numberWithInteger:self.network_status]};
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_CONNECTION_TYPE_CHANGE
                                                        object:self
                                                      userInfo:user_info];
  }
}

- (void)reachabilityChanged:(NSNotification*)notification
{
  [self setNetworkStatus:[self networkStatusFromApple:_reachability.currentReachabilityStatus]];
}

#pragma mark - State Manager Callback

- (void)setConnectedStatus:(BOOL)status
               stillTrying:(BOOL)trying
                 lastError:(NSString*)error
{
  if (!self.was_logged_in && status)
    _was_logged_in = YES;
  if (self.connected != status || trying)
  {
    _connected = status;
    InfinitConnectionStatus* res = [InfinitConnectionStatus connectionStatus:status
                                                                 stillTrying:trying
                                                                   lastError:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_CONNECTION_STATUS_CHANGE
                                                        object:res
                                                      userInfo:nil];
  }
}

@end
