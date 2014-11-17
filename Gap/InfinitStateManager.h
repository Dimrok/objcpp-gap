//
//  InfinitStateManager.h
//  Infinit
//
//  Created by Christopher Crone on 23/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitConnectionManager.h"
#import "InfinitLinkTransaction.h"
#import "InfinitPeerTransaction.h"
#import "InfinitUser.h"

@interface InfinitStateManager : NSObject

@property (readwrite) BOOL logged_in;

+ (void)startState;
+ (void)stopState;
+ (instancetype)sharedInstance;

#pragma mark - Register/Login/Logout
- (void)registerFullname:(NSString*)fullname
                   email:(NSString*)email
                password:(NSString*)password
         performSelector:(SEL)selector
                onObject:(id)object;

- (void)login:(NSString*)email
     password:(NSString*)password
performSelector:(SEL)selector
     onObject:(id)object;

- (void)logoutPerformSelector:(SEL)selector
                     onObject:(id)object;

#pragma mark - User
/// Users should be accessed using the User Manager.
- (NSArray*)swaggers;
- (InfinitUser*)userById:(NSNumber*)id_;
- (void)userByHandle:(NSString*)handle
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(id)data;

- (NSNumber*)self_id;
- (NSString*)self_device_id;

- (UIImage*)avatarForUserWithId:(NSNumber*)id_;

#pragma mark - All Transactions
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
- (void)acceptTransactionWithId:(NSNumber*)id_;
- (void)rejectTransactionWithId:(NSNumber*)id_;

#pragma mark - Connection Status
- (void)setNetworkConnectionStatus:(InfinitNetworkStatus)status;

@end
