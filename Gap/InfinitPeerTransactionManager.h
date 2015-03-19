//
//  InfinitPeerTransactionManager.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitDevice.h"
#import "InfinitFileSystemErrors.h"
#import "InfinitPeerTransaction.h"
#import "InfinitUser.h"

/** Notification sent when there is a new peer transaction.
 Contains a dictionary with the transaction "id".
*/
#define INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION         @"INFINIT_NEW_PEER_TRANSACTION_NOTIFICATION"

/** Notification sent when an existing peer transaction has its status updated.
 Contains a dictionary with the transaction "id".
 */
#define INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION      @"INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION"

/** Notification sent when a transaction sent to a phone number has received the ghost code from 
 Meta.
 Contains a dictionary with the transaction "id".
 */
#define INFINIT_PEER_PHONE_TRANSACTION_NOTIFICATION       @"INFINIT_PEER_PHONE_TRANSACTION_NOTIFICATION"

/** Notification sent when a transaction is initially accepted by the other party.
 Contains a dictionary with the transaction "id".
 */
#define INFINIT_PEER_TRANSACTION_ACCEPTED_NOTIFICATION    @"INFINIT_PEER_TRANSACTION_ACCEPTED_NOTIFICATION"

/** Notification sent when send operation started.
 */
#define INFINIT_PEER_TRANSACTION_CREATED_NOTIFICATION     @"INFINIT_PEER_TRANSACTION_CREATED_NOTIFICATION"

/** Notification sent when Peer Transaction model is ready.
 */
#define INFINIT_PEER_TRANSACTION_MODEL_READY_NOTIFICATION @"INFINIT_PEER_TRANSACTION_MODEL_READY_NOTIFICATION"

@interface InfinitPeerTransactionManager : NSObject

/// Returns list of Meta IDs for archived transactions.
@property (readonly) NSArray* archived_transaction_meta_ids;
/// Returns number of receivable transactions.
@property (readonly) NSUInteger receivable_transaction_count;
/// Boolean for when transactions are running.
@property (readonly) BOOL running_transactions;
/// Returns a reverse time ordered list of transactions.
@property (readonly) NSArray* transactions;
/// Returns if there are unread transactions.
@property (readonly) BOOL unread_transactions;

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

/** List of revers time ordered transactions involving a given user.
 @param user
  Involved user.
 @return Array of InfinitPeerTransaction objects.
 */
- (NSArray*)transactionsInvolvingUser:(InfinitUser*)user;

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

/** Send files to a list of recipients.
 @param files
  Array of file paths as NSStrings.
 @param recipient
  User to which you'd like to send the files.
 @param device
  Recipient's device.
 @param message
  String message of 100 chars max.
 @return InfinitPeerTransaction id.
 */
- (NSNumber*)sendFiles:(NSArray*)files
           toRecipient:(InfinitUser*)recipient
              onDevice:(InfinitDevice*)device
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

/** Archive all existing Transactions that aren't relevant to device.
 */
- (void)archiveIrrelevantTransactions;

/** Archive a Transaction.
 @param transaction
  Transaction to archive. Archiving is currently only locally effected.
 */
- (void)archiveTransaction:(InfinitPeerTransaction*)transaction;

/** Unarchive a Transaction.
 @param transaction
  Transaction to unarchive. Archiving is currently only locally effected.
 */
- (void)unarchiveTransaction:(InfinitPeerTransaction*)transaction;

/** Mark transaction as read.
 @param transaction
  Transaction to be marked read;
 */
- (void)markTransactionRead:(InfinitPeerTransaction*)transaction;

/** Number of unread transactions with user.
 @param user
  Other user that was involved in transactions.
 */
- (NSUInteger)unreadTransactionsWithUser:(InfinitUser*)user;

/** Mark all transactions with user as read.
 @param user
  Other user that was involved in transactions.
 */
- (void)markTransactionsWithUserRead:(InfinitUser*)user;

/** Number of incomplete transactions with user.
 @param user
  Other user that was involved in transactions.
 @return Number of incomplete transactions.
 */
- (NSUInteger)incompleteTransactionsWithUser:(InfinitUser*)user;

/** Number of transferring transactions with user.
 @param user
  Other user that was involved in transactions.
 @return Number of incomplete transactions.
 */
- (NSUInteger)transferringTransactionsWithUser:(InfinitUser*)user;

/** Progress of transactions with user.
 @param user
  Other user that was involved in transactions.
 @return Total progress of transactions with user.
 */
- (double)progressWithUser:(InfinitUser*)user;

/** Latest transaction per swagger.
 The result is reverse time ordered.
 @return Array of transactions.
 */
- (NSArray*)latestTransactionPerSwagger;

#pragma mark - State Manager Callback
- (void)transactionUpdated:(InfinitPeerTransaction*)transaction;
@end
