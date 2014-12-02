//
//  InfinitConnectionManager.h
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import <Foundation/Foundation.h>

/** Notification sent when connection to the notification server's state changes.
 Contains a dictionary with the current "status", if the backend is "still_trying" to reconnect
 automatically, and the "last_error" message.
 */
#define INFINIT_CONNECTION_STATUS_CHANGE @"INFINIT_CONNECTION_STATUS_CHANGE"

/** Notification sent when the type of connection changes.
 This does not mean that we are connected to the notification server.
 Contains a dictionary with the "connection_type" which is an NSNumber of InfinitNetworkStatus.
 */
#define INFINIT_CONNECTION_TYPE_CHANGE   @"INFINIT_CONNECTION_TYPE_CHANGE"

typedef enum : NSInteger
{
  NotReachable = 0,
  ReachableViaLAN,
#if TARGET_OS_IPHONE
  ReachableViaWWAN,
#endif
} InfinitNetworkStatus;

@interface InfinitConnectionManager : NSObject

@property (nonatomic, readonly) InfinitNetworkStatus network_status;
@property (nonatomic, readonly) BOOL connected;

+ (instancetype)sharedInstance;

#pragma mark - State Manager Callback
- (void)setConnectedStatus:(BOOL)status
               stillTrying:(BOOL)trying
                 lastError:(NSString*)error;

@end
