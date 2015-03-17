//
//  InfinitKeychain.h
//  Infinit
//
//  Created by Christopher Crone on 14/01/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InfinitKeychain : NSObject

+ (instancetype)sharedInstance;

- (BOOL)addPassword:(NSString*)password
         forAccount:(NSString*)account;
- (BOOL)credentialsForAccountInKeychain:(NSString*)account;
- (NSString*)passwordForAccount:(NSString*)account;
- (BOOL)removeAccount:(NSString*)account;
- (BOOL)updatePassword:(NSString*)password
            forAccount:(NSString*)account;

- (NSString*)passwordForInternetAccount:(NSString*)account
                               protocol:(NSString*)protocol
                                   host:(NSString*)host
                                   port:(UInt16)port;

@end
