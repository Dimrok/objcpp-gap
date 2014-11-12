//
//  InfinitPeerTransactionManager.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitPeerTransactionManager.h"

#import "InfinitStateManager.h"

static InfinitPeerTransactionManager* _instance = nil;

@implementation InfinitPeerTransactionManager
{
@private
  NSMutableDictionary* _transaction_map;
}

#pragma mark - Init

- (id)init
{
  if (self = [super init])
  {
    [self _fillTransactionMap];
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitPeerTransactionManager alloc] init];
  return _instance;
}

- (void)_fillTransactionMap
{
  _transaction_map = [NSMutableDictionary dictionary];
  NSArray* transactions = [[InfinitStateManager sharedInstance] peerTransactions];
  for (InfinitPeerTransaction* transaction in transactions)
    [_transaction_map setObject:transaction forKey:transaction.id_];
}

#pragma mark - Access Transactions

- (NSArray*)transactions
{
  return [[_transaction_map allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (InfinitPeerTransaction*)transactionWithId:(NSNumber*)id_
{
  @synchronized(_transaction_map)
  {
    InfinitPeerTransaction* res = [_transaction_map objectForKey:id_];
    if (res == nil)
    {
      res = [[InfinitStateManager sharedInstance] peerTransactionById:id_];
    }
    return res;
  }
}

#pragma mark - Accept/Reject

- (void)acceptTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] acceptTransactionWithId:transaction.id_];
}

- (void)rejectTransaction:(InfinitPeerTransaction*)transaction
{
  [[InfinitStateManager sharedInstance] rejectTransactionWithId:transaction.id_];
}

#pragma mark - Transaction Updated

- (void)transactionUpdated:(InfinitPeerTransaction*)transaction
{
  @synchronized(_transaction_map)
  {
    InfinitPeerTransaction* existing = [_transaction_map objectForKey:transaction.id_];
    if (existing == nil)
    {
      [_transaction_map setObject:transaction forKey:transaction.id_];
    }
    else
    {
      [existing updateWithTransaction:transaction];
    }
  }
}

@end
