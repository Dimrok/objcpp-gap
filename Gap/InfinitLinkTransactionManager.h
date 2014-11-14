//
//  InfinitLinkTransactionManager.h
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import <Foundation/Foundation.h>

#import "InfinitLinkTransaction.h"

#define INFINIT_NEW_LINK_TRANSACTION_NOTIFICATION     @"INFINIT_NEW_LINK_TRANSACTION_NOTIFICATION"
#define INFINIT_LINK_TRANSACTION_DATA_NOTIFICATION    @"INFINIT_LINK_TRANSACTION_DATA_NOTIFICATION"
#define INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION  @"INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION"
#define INFINIT_LINK_TRANSACTION_DELETED_NOTIFICATION @"INFINIT_LINK_TRANSACTION_DELETED_NOTIFICATION"

@interface InfinitLinkTransactionManager : NSObject

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

/** Cancel a Transaction
 @param transaction
  InfinitLinkTransaction object.
 */
- (void)cancelTransaction:(InfinitLinkTransaction*)transaction;

#pragma mark - State Manager Callback
- (void)transactionUpdated:(InfinitLinkTransaction*)transaction;

@end
