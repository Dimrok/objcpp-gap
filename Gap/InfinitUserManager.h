//
//  InfinitUserManager.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "InfinitUser.h"

@interface InfinitUserManager : NSObject

+ (instancetype)sharedInstance;

- (InfinitUser*)userWithId:(NSNumber*)user_id;

@end
