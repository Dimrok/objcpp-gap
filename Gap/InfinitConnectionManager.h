//
//  InfinitConnectionManager.h
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import <Foundation/Foundation.h>

#import "InfinitConnectionStatus.h"

/** Notification sent when connection to the notification server's state changes.
 Contains a connection status object.
 */
#define INFINIT_CONNECTION_STATUS_CHANGE @"INFINIT_CONNECTION_STATUS_CHANGE"

/** Notification sent when the type of connection changes.
 This does not mean that we are connected to the notification server.
 Contains a dictionary with the "connection_type" which is an NSNumber of InfinitNetworkStatus.
 */
#define INFINIT_CONNECTION_TYPE_CHANGE   @"INFINIT_CONNECTION_TYPE_CHANGE"

typedef NS_ENUM(NSUInteger, InfinitNetworkStatuses)
{
  InfinitNetworkStatusNotReachable = 0,
  InfinitNetworkStatusReachableViaLAN,
#if TARGET_OS_IPHONE
  InfinitNetworkStatusReachableViaWWAN,
#endif
};

@interface InfinitConnectionManager : NSObject

@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) InfinitNetworkStatuses network_status;
@property (nonatomic, readonly) BOOL was_logged_in;

+ (instancetype)sharedInstance;

#pragma mark - State Manager Callback
- (void)setConnectedStatus:(BOOL)status
               stillTrying:(BOOL)trying
                 lastError:(NSString*)error;

@end
