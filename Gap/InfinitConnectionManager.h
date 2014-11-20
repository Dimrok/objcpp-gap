//
//  InfinitConnectionManager.h
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import <Foundation/Foundation.h>

typedef enum : NSInteger
{
  NotReachable = 0,
  ReachableViaLAN,
  ReachableViaWWAN
} InfinitNetworkStatus;

@interface InfinitConnectionManager : NSObject

@property (readonly) InfinitNetworkStatus network_status;
@property (readonly) BOOL connected;

+ (instancetype)sharedInstance;

#pragma mark - State Manager Callback
- (void)setConnectedStatus:(BOOL)status;

@end
