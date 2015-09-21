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
# define INFINIT_IMAGE UIImage
#else
# import <AppKit/NSImage.h>
# define INFINIT_IMAGE NSImage
#endif

#import "InfinitConnectionManager.h"
#import "InfinitLinkTransaction.h"
#import "InfinitPeerTransaction.h"
#import "InfinitStateResult.h"
#import "InfinitUser.h"

#import <surface/gap/enums.hh>

/** Notification sent when the model needs to be cleared. 
 This is generally sent when a new user logs in.
 */
#define INFINIT_CLEAR_MODEL_NOTIFICATION     @"INFINIT_CLEAR_MODEL_NOTIFICATION"

/** Notification sent when we will perform a logout.
 Used to alert the frontend so that tokens can be cleared.
 */
#define INFINIT_WILL_LOGOUT_NOTIFICATION     @"INFINIT_WILL_LOGOUT_NOTIFICATION"

// Generic block queue operation completion.
typedef void(^InfinitStateCompletionBlock)(InfinitStateResult* result);

@interface InfinitStateManager : NSObject

@property (nonatomic, readonly) NSString* encoded_meta_session_id;
@property (nonatomic, readonly) BOOL logged_in;
@property (nonatomic, readwrite) NSString* push_token;

+ (instancetype)sharedInstance;

+ (void)startState;
+ (void)startStateWithDownloadDir:(NSString*)download_dir;
+ (void)stopState;

#pragma mark - Register/Login/Logout
/** Check account type by email.
 @param email
  The user's email.
 @param completion_block
  Block to run on completion.
 */
typedef void(^InfinitEmailAccountStatusBlock)(InfinitStateResult* result,
                                              NSString* email,
                                              AccountStatus status);
- (void)accountStatusForEmail:(NSString*)email
              completionBlock:(InfinitEmailAccountStatusBlock)completion_block;

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

/** Register a new user.
 @param fullname
  The user's fullname.
 @param email
  The user's email address.
 @param password
  The user's email password.
 @param completion_block
  Block called on completion.
 */

- (void)registerFullname:(NSString*)fullname
                   email:(NSString*)email
                password:(NSString*)password
         completionBlock:(InfinitStateCompletionBlock)completion_block;

/** Plain invite contact.
 @param contact
  Email or phone number to invite.
 @param completion_block
  Block to run on completion.
 */
typedef void(^InfinitPlainInviteBlock)(InfinitStateResult* result,
                                       NSString* contact, 
                                       NSString* code, 
                                       NSString* url);
- (void)plainInviteContact:(NSString*)contact
           completionBlock:(InfinitPlainInviteBlock)completion_block;

/** Send invitation using Meta.
 This is used when the user refuses or fails to send an SMS to the recipient.
 @param destination
  Mobile number to send to.
 @param message
  Message for SMS.
 @param ghost_code
  Code associated with message.
 @param user_cance
  If the user canceled the sending of the message.
 @param type
  Type of invitation to be sent: 'ghost', 'plain' or 'reminder'.
 */
- (void)sendInvitation:(NSString*)destination
               message:(NSString*)message
             ghostCode:(NSString*)ghost_code
            userCancel:(BOOL)user_cancel
                  type:(NSString*)type;

/** Check a ghost code exists.
 @param code
  Code to check.
 @param completion_block
  Block to run on completion.
 */
typedef void(^InfinitGhostCodeExistsBlock)(InfinitStateResult* result, NSString* code, BOOL valid);
- (void)ghostCodeExists:(NSString*)code
        completionBlock:(InfinitGhostCodeExistsBlock)completion_block;

/** Use a ghost code.
 @param code
  Code to activate.
 @param link
  If the code was from a link.
 */
- (void)useGhostCode:(NSString*)code
             wasLink:(BOOL)link;

/** Add fingerprint.
 @param fingerprint
  Fingerprint to add.
 */
- (void)addFingerprint:(NSString*)fingerprint;

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

/** Log a user in.
 @param email
  The user's email address.
 @param password
  The user's email password.
 @param completion_block
  Block to run on completion.
 */
- (void)login:(NSString*)email
     password:(NSString*)password
completionBlock:(InfinitStateCompletionBlock)completion_block;

/** Fetch web login token.
 @param completion_block
  Block to run on completion.
 */
typedef void(^InfinitWebLoginTokenBlock)(InfinitStateResult* result,
                                         NSString* token,
                                         NSString* email);
- (void)webLoginTokenWithCompletionBlock:(InfinitWebLoginTokenBlock)completion_block;

/** User registered with Facebook id.
 @param facebook_id
  Facebook id of user.
 @param selector
  Function to call when complete.
 @param object
  Calling object.
 @param data
  Mutable dictionary for result.
 */
- (void)userRegisteredWithFacebookId:(NSString*)facebook_id
                     performSelector:(SEL)selector
                            onObject:(id)object
                            withData:(NSMutableDictionary*)data;

/** User registered with Facebook id.
 @param facebook_id
  Facebook id of user.
 @param completion_block
  Block run on completion.
 */
typedef void(^InfinitFacebookUserRegistered)(InfinitStateResult* result, BOOL registered);
- (void)userRegisteredWithFacebookId:(NSString*)facebook_id
                     completionBlock:(InfinitFacebookUserRegistered)completion_block;

/** Facebook application ID.
 return Facebook application ID as string.
 */
- (NSString*)facebookApplicationId;

/** Connect user using Facebook.
  Will either register and login the user or just log the user in using Facebook.
 @param token
  Facebook client token.
 @param selector
  Function to call when complete.
 @param object
  Calling object.
 */
- (void)facebookConnect:(NSString*)facebook_token
           emailAddress:(NSString*)email
        performSelector:(SEL)selector
               onObject:(id)object;

/** Connect user using Facebook.
 Will either register and login the user or just log the user in using Facebook.
 @param token
  Facebook client token.
 @param completion_block
  Block called on completion.
 */
- (void)facebookConnect:(NSString*)facebook_token
           emailAddress:(NSString*)email
        completionBlock:(InfinitStateCompletionBlock)completion_block;

/** Connect Facebook account to existing Infinit account.
 Will add their Facebook ID to their account information so that they can find friends.
 */
- (void)addFacebookAccount:(NSString*)facebook_token;

/** Log the current user out.
 @param selector
  Function to call when complete.
 @param object
  Calling object.
 */
- (void)logoutPerformSelector:(SEL)selector
                     onObject:(id)object;

/** Log the current user out.
 @param completion_block
  Block to call on completion.
 */
- (void)logoutWithCompletionBlock:(InfinitStateCompletionBlock)completion_block;

#pragma mark - Local Contacts
/** Upload contacts.
 @param contacts.
  Array with dictionary for each contact of the form:
  {"email_addresses": [...], "phone_numbers": [...]}
 */
- (void)uploadContacts:(NSArray*)contacts
       completionBlock:(InfinitStateCompletionBlock)completion_block;

#pragma mark - Device
/** Update current device name, model and OS.
 All variables are optional.
 @param name
  User friendly name of the device.
 @param model
  Model of device (e.g.: iPad4,1)
 @param os
  OS of device.
 @param completion_block
  Block to run on completion.
 */
- (void)updateDeviceName:(NSString*)name
                   model:(NSString*)model
                      os:(NSString*)os
         completionBlock:(InfinitStateCompletionBlock)completion_block;

/** Change the device ID to one that was stored.
 @param device_id
  Device ID to change to.
 */
- (void)changeDeviceId:(NSString*)device_id;

#pragma mark - User
/// Users should be accessed using the User Manager.
- (NSArray*)swaggers;
- (NSArray*)favorites;
- (void)addFavorite:(InfinitUser*)user;
- (void)removeFavorite:(InfinitUser*)user;
- (InfinitUser*)userById:(NSNumber*)id_;

- (NSNumber*)self_id;
- (NSString*)self_device_id;

- (INFINIT_IMAGE*)avatarForUserWithId:(NSNumber*)id_;

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
                     withMessage:(NSString*)message_
                    isScreenshot:(BOOL)screenshot;
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
- (void)acceptTransactionWithId:(NSNumber*)id_;
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

- (void)userByEmail:(NSString*)email
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

- (void)sendMetricInviteSent:(BOOL)success
                        code:(NSString*)code
                      method:(gap_InviteMessageMethod)method
                  failReason:(NSString*)fail_reason_;

- (void)sendMetricGhostSMSSent:(BOOL)success
                          code:(NSString*)code
                    failReason:(NSString*)fail_reason;

- (void)sendMetricSendToSelfLimit;

- (void)sendMetricTransferSizeLimitWithTransferSize:(uint64_t)transfer_size;

#pragma mark - Proxy

- (void)setProxy:(gap_ProxyType)type
            host:(NSString*)host
            port:(UInt16)port
        username:(NSString*)username
        password:(NSString*)password;

- (void)unsetProxy:(gap_ProxyType)type;

#pragma mark - Download Directory

- (void)setDownloadDirectory:(NSString*)download_dir
                    fallback:(BOOL)fallback;

@end
