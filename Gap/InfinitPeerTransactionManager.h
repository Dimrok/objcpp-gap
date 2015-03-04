//
//  InfinitPeerTransactionManager.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitFileSystemErrors.h"
#import "InfinitPeerTransaction.h"

/** Notification sent when there is a new peer transaction.
 Contains a dictionary with the transaction ID.
*/
#define INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION    @"INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION"

/** Notification sent when an existing peer transaction has its status updated.
 Contains a dictionary with the transaction ID.
 */
#define INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION @"INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION"

@interface InfinitPeerTransactionManager : NSObject

/// Returns list of Meta IDs for archived transactions.
@property (readonly) NSArray* archived_transaction_meta_ids;
/// Boolean for when transactions are running.
@property (readonly) BOOL running_transactions;
/// Returns a reverse time ordered list of transactions.
@property (readonly) NSArray* transactions;

+ (instancetype)sharedInstance;

/** List of reverse time ordered transactions.
 @param archived
  Include or exclude archived transactions.
 @param device_only
  Include or exclude transactions to other devices.
 @return Array of InfinitPeerTransaction objects.
 */
- (NSArray*)transactionsIncludingArchived:(BOOL)archived
                           thisDeviceOnly:(BOOL)device_only;

/** Peer Transaction corresponding to ID.
 @param id_
  InfinitPeerTransaction ID.
 @return Peer Transaction with corresponding ID.
 */
- (InfinitPeerTransaction*)transactionWithId:(NSNumber*)id_;

/** Cached Peer Transaction with corresponding Meta ID.
 This will only return a transaction if it is in the local model.
 @param meta_id
  Meta ID of transaction.
 @return Peer Transaction
 */
- (InfinitPeerTransaction*)transactionWithMetaId:(NSString*)meta_id;

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
  Transaction to accept.
 @param error
  Error object that should be checked upon return. Will be nil if there was no error.
 @return False if there was an error.
 */
- (BOOL)acceptTransaction:(InfinitPeerTransaction*)transaction
                withError:(NSError**)error;

/** Reject a Transaction.
 @param transaction
  Transaction to reject.
 */
- (void)rejectTransaction:(InfinitPeerTransaction*)transaction;

/** Pause a Transaction.
 @param transaction
  Transaction to pause.
 */
- (void)pauseTransaction:(InfinitPeerTransaction*)transaction;

/** Resume a Transaction.
 @param transaction
  Transaction to resume.
 */
- (void)resumeTransaction:(InfinitPeerTransaction*)transaction;

/** Cancel a Transaction
 @param transaction
  Transaction to cancel.
 */
- (void)cancelTransaction:(InfinitPeerTransaction*)transaction;

/** Archive a Transaction.
 @param transaction
  Transaction to archive. Archiving is currently only locally effected.
 */
- (void)archiveTransaction:(InfinitPeerTransaction*)transaction;

#pragma mark - State Manager Callback
- (void)transactionUpdated:(InfinitPeerTransaction*)transaction;
@end
