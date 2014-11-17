//
//  InfinitAvatarManager.h
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>

#import "InfinitUser.h"

@interface InfinitAvatarManager : NSObject

+ (instancetype)sharedInstance;

- (UIImage*)avatarForUser:(InfinitUser*)user;

#pragma mark - State Manager Callback
- (void)gotAvatarForUserWithId:(NSNumber*)id_;

@end
