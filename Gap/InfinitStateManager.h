//
//  InfinitStateManager.h
//  Infinit
//
//  Created by Christopher Crone on 23/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
# import <UIKit/UIImage.h>
#else
# import <AppKit/NSImage.h>
#endif

#import "InfinitConnectionManager.h"
#import "InfinitLinkTransaction.h"
#import "InfinitPeerTransaction.h"
#import "InfinitUser.h"

/** Notification sent when the model needs to be cleared. 
 This is generally sent when a new user logs in.
 */
#define INFINIT_CLEAR_MODEL_NOTIFICATION     @"INFINIT_CLEAR_MODEL_NOTIFICATION"

/** Notification sent when we will perform a logout.
 Used to alert the frontend so that tokens can be cleared.
 */
#define INFINIT_WILL_LOGOUT_NOTIFICATION     @"INFINIT_WILL_LOGOUT_NOTIFICATION"

@interface InfinitStateManager : NSObject

@property (nonatomic, readwrite) BOOL logged_in;
@property (nonatomic, readonly) uint64_t max_mirror_size;
@property (nonatomic, readwrite) NSString* push_token;

+ (instancetype)sharedInstance;

+ (void)startState;
+ (void)stopState;

#pragma mark - Register/Login/Logout
/** Register a new user.
 @param fullname
  The user's fullname.
 @param email
  The user's email address.
 @param password
  The user's email password.
 @param selector
  Function to call when complete.
 @param object
  Calling object.
 */
- (void)registerFullname:(NSString*)fullname
                   email:(NSString*)email
                password:(NSString*)password
         performSelector:(SEL)selector
                onObject:(id)object;

/** Use a ghost code.
 @param code
  Code to activate.
 @param selector
  Function to call when complete.
 @param object
  Calling object.
 */
- (void)useGhostCode:(NSString*)code
     performSelector:(SEL)selector
            onObject:(id)object;

/** Log a user in.
 @param email
  The user's email address.
 @param password
  The user's email password.
 @param selector
  Function to call when complete.
 @param object
  Calling object.
 */
- (void)login:(NSString*)email
     password:(NSString*)password
performSelector:(SEL)selector
     onObject:(id)object;

/** Connect user using Facebook.
  Will either register and login the user or just log the user in using Facebook.
 @param token
  Facebook client token.
 */
- (void)facebookConnect:(NSString*)facebook_token
           emailAddress:(NSString*)email
        performSelector:(SEL)selector
               onObject:(id)object;

/** Log the current user out.
 @param selector
  Function to call when complete.
 @param object
  Calling object.
 */
- (void)logoutPerformSelector:(SEL)selector
                     onObject:(id)object;

#pragma mark - User
/// Users should be accessed using the User Manager.
- (NSArray*)swaggers;
- (NSArray*)favorites;
- (void)addFavorite:(InfinitUser*)user;
- (void)removeFavorite:(InfinitUser*)user;
- (InfinitUser*)userById:(NSNumber*)id_;

- (NSNumber*)self_id;
- (NSString*)self_device_id;

#if TARGET_OS_IPHONE
- (UIImage*)avatarForUserWithId:(NSNumber*)id_;
#else
- (NSImage*)avatarForUserWithId:(NSNumber*)id_;
#endif

#pragma mark - All Transactions
- (void)pauseTransactionWithId:(NSNumber*)id_;
- (void)resumeTransactionWithId:(NSNumber*)id_;
- (void)cancelTransactionWithId:(NSNumber*)id_;
- (float)transactionProgressForId:(NSNumber*)id_;

#pragma mark - Link Transactions
/// Link Transactions should be accessed using the Link Transaction Manager.
- (NSArray*)linkTransactions;
- (InfinitLinkTransaction*)linkTransactionById:(NSNumber*)id_;

- (NSNumber*)createLinkWithFiles:(NSArray*)files
                     withMessage:(NSString*)message;
- (void)deleteTransactionWithId:(NSNumber*)id_;

#pragma mark - Peer Transactions
/// Peer Transactions should be accessed using the Peer Transaction Manager.
- (NSArray*)peerTransactions;
- (InfinitPeerTransaction*)peerTransactionById:(NSNumber*)id_;


- (NSNumber*)sendFiles:(NSArray*)files
           toRecipient:(id)recipient
           withMessage:(NSString*)message;
- (NSNumber*)sendFiles:(NSArray*)files
           toRecipient:(InfinitUser*)recipient
              onDevice:(NSString*)device_id 
           withMessage:(NSString*)message;
- (void)acceptTransactionWithId:(NSNumber*)id_
            toRelativeDirectory:(NSString*)directory;
- (void)rejectTransactionWithId:(NSNumber*)id_;

#pragma mark - Connection Status
- (void)setNetworkConnectionStatus:(InfinitNetworkStatuses)status;

#pragma mark - Devices
- (NSArray*)devices;

#pragma mark - Features
- (NSDictionary*)features;

#pragma mark - Self
- (NSString*)selfFullname;
- (void)setSelfFullname:(NSString*)fullname
        performSelector:(SEL)selector
               onObject:(id)object;

- (NSString*)selfHandle;
- (void)setSelfHandle:(NSString*)handle
      performSelector:(SEL)selector
             onObject:(id)object;

- (NSString*)selfEmail;
- (void)setSelfEmail:(NSString*)email
            password:(NSString*)password
     performSelector:(SEL)selector
            onObject:(id)object;

- (void)changeFromPassword:(NSString*)old_password
                toPassword:(NSString*)new_password
           performSelector:(SEL)selector
                  onObject:(id)object;


#if TARGET_OS_IPHONE
- (void)setSelfAvatar:(UIImage*)image
#else
- (void)setSelfAvatar:(NSImage*)image
#endif
      performSelector:(SEL)selector
             onObject:(id)object;

#pragma mark - Search
- (void)userByMetaId:(NSString*)meta_id
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(NSMutableDictionary*)data;

- (void)userByHandle:(NSString*)handle
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(NSMutableDictionary*)data;

- (void)textSearch:(NSString*)text
   performSelector:(SEL)selector
          onObject:(id)object
          withData:(NSMutableDictionary*)data;

- (void)searchEmails:(NSArray*)emails
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(NSMutableDictionary*)data;

#pragma mark - Crash Reporting

- (void)sendLastCrashLog:(NSString*)crash_log
            withStateLog:(NSString*)state_log
         performSelector:(SEL)selector
                onObject:(id)object;

- (void)reportAProblem:(NSString*)problem
               andFile:(NSString*)file
       performSelector:(SEL)selector
              onObject:(id)object;

#pragma mark - Metrics Reporting

- (void)sendMetricEvent:(NSString*)event
             withMethod:(NSString*)method
      andAdditionalData:(NSDictionary*)additional;

@end
