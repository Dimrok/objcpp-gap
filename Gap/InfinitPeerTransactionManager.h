//
//  InfinitPeerTransactionManager.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitPeerTransaction.h"

@interface InfinitPeerTransactionManager : NSObject

@property (readonly) NSArray* transactions;

+ (instancetype)sharedInstance;

- (InfinitPeerTransaction*)transactionWithId:(NSNumber*)id_;

- (void)acceptTransaction:(InfinitPeerTransaction*)transaction;
- (void)rejectTransaction:(InfinitPeerTransaction*)transaction;

- (void)transactionUpdated:(InfinitPeerTransaction*)transaction;
@end
