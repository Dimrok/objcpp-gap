//
//  InfinitExternalAccountsManager.h
//  Gap
//
//  Created by Christopher Crone on 10/06/15.
//
//

#import <Foundation/Foundation.h>

#import "InfinitExternalAccount.h"

@interface InfinitExternalAccountsManager : NSObject

@property (nonatomic, readonly) NSArray* account_list;
@property (nonatomic, readonly) BOOL have_facebook;

+ (instancetype)sharedInstance;

#pragma mark - State Manager Callback
- (void)accountsUpdated:(NSArray*)accounts;

@end
