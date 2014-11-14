//
//  InfinitPeerTransactionManager.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitPeerTransaction.h"

#define INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION    @"INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION"
#define INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION @"INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION"

@interface InfinitPeerTransactionManager : NSObject

// Returns a reverse time ordered list of transactions.
@property (readonly) NSArray* transactions;

+ (instancetype)sharedInstance;

/** Peer Transaction corresponding to ID.
 @param id_
  InfinitPeerTransaction ID.
 @return Peer Transaction with corresponding ID.
 */
- (InfinitPeerTransaction*)transactionWithId:(NSNumber*)id_;

#pragma mark - User Interaction
/** Send files to a list of recipients.
 @param files 
  Array of file paths as NSStrings.
 @param recipients 
  Array of recipients that can be either InfinitUser or NSString (email) objects.
 @param message 
  String message of 100 chars max.
 @return Array of InfinitPeerTransaction ids.
 */
- (NSArray*)sendFiles:(NSArray*)files
         toRecipients:(NSArray*)recipients
          withMessage:(NSString*)message;

/** Accept a Transaction.
 @param transaction
  InfinitPeerTransaction object.
 */
- (void)acceptTransaction:(InfinitPeerTransaction*)transaction;
/** Reject a Transaction.
 @param transaction
  InfinitPeerTransaction object.
 */
- (void)rejectTransaction:(InfinitPeerTransaction*)transaction;
/** Cancel a Transaction
 @param transaction
  InfinitPeerTransaction object.
 */
- (void)cancelTransaction:(InfinitPeerTransaction*)transaction;

#pragma mark - State Manager Callback
- (void)transactionUpdated:(InfinitPeerTransaction*)transaction;
@end
