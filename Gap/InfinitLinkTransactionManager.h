//
//  InfinitLinkTransactionManager.h
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import <Foundation/Foundation.h>

#import "InfinitLinkTransaction.h"

/** Notification sent when there is a new link transaction.
 Contains a dictionary with the transaction "id".
 */
#define INFINIT_NEW_LINK_TRANSACTION_NOTIFICATION     @"INFINIT_NEW_LINK_TRANSACTION_NOTIFICATION"

/** Notification sent when an existing link transaction's data has changed. (e.g.: click count).
 Contains a dictionary with the transaction "id".
*/
#define INFINIT_LINK_TRANSACTION_DATA_NOTIFICATION    @"INFINIT_LINK_TRANSACTION_DATA_NOTIFICATION"

/** Notification sent when the status of an existing link transaction is updated.
 Contains a dictionary with the transaction "id".
*/
#define INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION  @"INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION"

/** Notification sent when an existing link transaction has been deleted.
 Contains a dictionary with the transaction "id".
*/
#define INFINIT_LINK_TRANSACTION_DELETED_NOTIFICATION @"INFINIT_LINK_TRANSACTION_DELETED_NOTIFICATION"

/** Notification sent when link created.
 Contains a dictionary with the transaction "id".
 */
#define INFINIT_LINK_TRANSACTION_CREATED_NOTIFICATION @"INFINIT_LINK_TRANSACTION_CREATED_NOTIFICATION"

@interface InfinitLinkTransactionManager : NSObject

/// Boolean for when transactions are running.
@property (readonly) BOOL running_transactions;
// Returns a reverse time ordered list of transactions.
@property (readonly) NSArray* transactions;

+ (instancetype)sharedInstance;

/** Peer Transaction corresponding to ID.
 @param id_
 InfinitPeerTransaction ID.
 @return Peer Transaction with corresponding ID.
 */
- (InfinitLinkTransaction*)transactionWithId:(NSNumber*)id_;

#pragma mark - User Interaction
/** Create a link.
 @param files
  List of files as NSStrings.
 @param message
  Message of up to 100 chars.
 @returns Transaction ID.
 */
- (NSNumber*)createLinkWithFiles:(NSArray*)files
                     withMessage:(NSString*)message;

/** Create a link from a screenshot.
 @param file
  Screenshot.
 @returns Transaction ID.
 */
- (NSNumber*)createScreenshotLink:(NSString*)file;

/** Pause a Transaction.
 @param transaction
  Transaction to pause.
 */
- (void)pauseTransaction:(InfinitLinkTransaction*)transaction;

/** Resume a Transaction.
 @param transaction
  Transaction to resume.
 */
- (void)resumeTransaction:(InfinitLinkTransaction*)transaction;

/** Cancel a Transaction.
 @param transaction
  Transaction to cancel.
 */
- (void)cancelTransaction:(InfinitLinkTransaction*)transaction;

/** Delete a Transaction.
 @param transaction
  Transaction to delete.
 */
- (void)deleteTransaction:(InfinitLinkTransaction*)transaction;

#pragma mark - State Manager Callback
- (void)transactionUpdated:(InfinitLinkTransaction*)transaction;

@end
