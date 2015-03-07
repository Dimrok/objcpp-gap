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
#else
# import <AppKit/NSImage.h>
#endif

#import "InfinitUser.h"

@interface InfinitAvatarManager : NSObject

+ (instancetype)sharedInstance;

- (void)setSelfAvatar:(UIImage*)avatar;

#if TARGET_OS_IPHONE
- (UIImage*)avatarForUser:(InfinitUser*)user;
#else
- (NSImage*)avatarForUser:(InfinitUser*)user;
#endif

- (void)clearAvatarForUser:(InfinitUser*)user;

#pragma mark - State Manager Callback
- (void)gotAvatarForUserWithId:(NSNumber*)id_;

- (void)clearCachedAvatars;

@end
