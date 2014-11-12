//
//  InfinitStateManager.h
//  Infinit
//
//  Created by Christopher Crone on 23/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitPeerTransaction.h"
#import "InfinitUser.h"

@interface InfinitStateManager : NSObject

@property (readwrite) BOOL logged_in;

+ (void)startState;
+ (void)stopState;
+ (instancetype)sharedInstance;

#pragma mark - Login/Logout
- (void)login:(NSString*)email
     password:(NSString*)password
performSelector:(SEL)selector
     onObject:(id)object;

- (void)logoutPerformSelector:(SEL)selector
                     onObject:(id)object;

#pragma mark - User
/// Users should be accessed using the User Manager.
- (InfinitUser*)userById:(NSNumber*)id_;
- (NSArray*)swaggers;

- (NSNumber*)self_id;
- (NSString*)self_device_id;

#pragma mark - PeerTransaction
/// Peer Transactions should be accessed using the Peer Transaction Manager.
- (InfinitPeerTransaction*)peerTransactionById:(NSNumber*)id_;
- (NSArray*)peerTransactions;

- (void)acceptTransactionWithId:(NSNumber*)id_;
- (void)rejectTransactionWithId:(NSNumber*)id_;

@end
