//
//  InfinitStateManager.h
//  Infinit
//
//  Created by Christopher Crone on 23/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitUser.h"

@interface InfinitStateManager : NSObject

@property (readwrite) BOOL logged_in;

+ (void)startState;
+ (void)stopState;
+ (instancetype)sharedInstance;

- (void)login:(NSString*)email
     password:(NSString*)password
performSelector:(SEL)selector
     onObject:(id)object;

- (InfinitUser*)userById:(NSNumber*)user_id;
- (NSArray*)swaggers;

@end
