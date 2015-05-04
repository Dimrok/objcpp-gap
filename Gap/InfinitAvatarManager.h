//
//  InfinitAvatarManager.h
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
# import <UIKit/UIImage.h>
# define INFINIT_IMAGE UIImage
#else
# import <AppKit/NSImage.h>
# define INFINIT_IMAGE NSImage
#endif

#import "InfinitUser.h"

@interface InfinitAvatarManager : NSObject

+ (instancetype)sharedInstance;

- (void)setSelfAvatar:(INFINIT_IMAGE*)avatar;

- (INFINIT_IMAGE*)avatarForUser:(InfinitUser*)user;

- (void)clearAvatarForUser:(InfinitUser*)user;

- (void)setAvatar:(INFINIT_IMAGE*)avatar
          forUser:(InfinitUser*)user;

#pragma mark - State Manager Callback
- (void)gotAvatarForUserWithId:(NSNumber*)id_;

- (void)clearCachedAvatars;

@end
