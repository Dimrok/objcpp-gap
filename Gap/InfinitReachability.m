/*
 File: Reachability.m
 Abstract: Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 Version: 3.5

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.

 */

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>

#import <CoreFoundation/CoreFoundation.h>

#import "InfinitReachability.h"

NSString *kReachabilityChangedNotification = @"kNetworkReachabilityChangedNotification";

#pragma mark - Supporting functions

static
void ReachabilityCallback(SCNetworkReachabilityRef target,
                          SCNetworkReachabilityFlags flags,
                          void* info)
{
#pragma unused (target, flags)
  NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
  NSCAssert([(__bridge NSObject*) info isKindOfClass: [InfinitReachability class]],
            @"info was wrong class in ReachabilityCallback");

  InfinitReachability* note_object = (__bridge InfinitReachability*)info;
  // Post a notification to notify the client that the network reachability changed.
  [[NSNotificationCenter defaultCenter] postNotificationName:kReachabilityChangedNotification
                                                      object:note_object];
}


#pragma mark - Reachability implementation

@implementation InfinitReachability
{
  BOOL _always_return_local_wifi_status; //default is NO
  SCNetworkReachabilityRef _reachability_ref;
}

+ (instancetype)reachabilityWithHostName:(NSString*)host_name
{
  InfinitReachability* res = NULL;
  SCNetworkReachabilityRef reachability =
    SCNetworkReachabilityCreateWithName(NULL, [host_name UTF8String]);
  if (reachability != NULL)
  {
    res = [[self alloc] init];
    if (res != NULL)
    {
      res->_reachability_ref = reachability;
      res->_always_return_local_wifi_status = NO;
    }
  }
  return res;
}


+ (instancetype)reachabilityWithAddress:(const struct sockaddr_in*)host_addr
{
  SCNetworkReachabilityRef reachability =
    SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault,
                                           (const struct sockaddr*)host_addr);

  InfinitReachability* res = NULL;

  if (reachability != NULL)
  {
    res = [[self alloc] init];
    if (res != NULL)
    {
      res->_reachability_ref = reachability;
      res->_always_return_local_wifi_status = NO;
    }
  }
  return res;
}



+ (instancetype)reachabilityForInternetConnection
{
  struct sockaddr_in zero_addr;
  bzero(&zero_addr, sizeof(zero_addr));
  zero_addr.sin_len = sizeof(zero_addr);
  zero_addr.sin_family = AF_INET;

  return [self reachabilityWithAddress:&zero_addr];
}


+ (instancetype)reachabilityForLocalWiFi
{
  struct sockaddr_in local_wifi_addr;
  bzero(&local_wifi_addr, sizeof(local_wifi_addr));
  local_wifi_addr.sin_len = sizeof(local_wifi_addr);
  local_wifi_addr.sin_family = AF_INET;

  // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0.
  local_wifi_addr.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);

  InfinitReachability* res = [self reachabilityWithAddress:&local_wifi_addr];
  if (res != NULL)
  {
    res->_always_return_local_wifi_status = YES;
  }

  return res;
}


#pragma mark - Start and stop notifier

- (BOOL)startNotifier
{
  BOOL res = NO;
  SCNetworkReachabilityContext context = {0, (__bridge void*)(self), NULL, NULL, NULL};

  if (SCNetworkReachabilitySetCallback(_reachability_ref, ReachabilityCallback, &context))
  {
    if (SCNetworkReachabilityScheduleWithRunLoop(_reachability_ref,
                                                 CFRunLoopGetCurrent(),
                                                 kCFRunLoopDefaultMode))
    {
      res = YES;
    }
  }

  return res;
}


- (void)stopNotifier
{
  if (_reachability_ref != NULL)
  {
    SCNetworkReachabilityUnscheduleFromRunLoop(_reachability_ref,
                                               CFRunLoopGetCurrent(),
                                               kCFRunLoopDefaultMode);
  }
}


- (void)dealloc
{
  [self stopNotifier];
  if (_reachability_ref != NULL)
  {
    CFRelease(_reachability_ref);
  }
}


#pragma mark - Network Flag Handling

- (__NetworkStatus)localWiFiStatusForFlags:(SCNetworkReachabilityFlags)flags
{
  __NetworkStatus res = __NotReachable;
  if ((flags & kSCNetworkReachabilityFlagsReachable) &&
      (flags & kSCNetworkReachabilityFlagsIsDirect))
  {
    res = __ReachableViaWiFi;
  }
  return res;
}


- (__NetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
  if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
  {
    // The target host is not reachable.
    return __NotReachable;
  }

  __NetworkStatus res = __NotReachable;

  if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
  {
    /*
     If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
     */
    res = __ReachableViaWiFi;
  }

  if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
       (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
  {
    /*
     ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
     */

    if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
    {
      /*
       ... and no [user] intervention is needed...
       */
      res = __ReachableViaWiFi;
    }
  }
#if TARGET_OS_IPHONE
  if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
  {
    /*
     ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
     */
    res = __ReachableViaWWAN;
  }
#endif

  return res;
}


- (BOOL)connectionRequired
{
  NSAssert(_reachability_ref != NULL, @"connectionRequired called with NULL reachabilityRef");
  SCNetworkReachabilityFlags flags;

  if (SCNetworkReachabilityGetFlags(_reachability_ref, &flags))
  {
    return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
  }
  return NO;
}


- (__NetworkStatus)currentReachabilityStatus
{
  NSAssert(_reachability_ref != NULL,
           @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
  __NetworkStatus res = __NotReachable;
  SCNetworkReachabilityFlags flags;

  if (SCNetworkReachabilityGetFlags(_reachability_ref, &flags))
  {
    if (_always_return_local_wifi_status)
    {
      res = [self localWiFiStatusForFlags:flags];
    }
    else
    {
      res = [self networkStatusForFlags:flags];
    }
  }
  return res;
}


@end
