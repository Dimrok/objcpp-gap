//
//  InfinitAvatarManager.m
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import "InfinitAvatarManager.h"
#import "InfinitStateManager.h"

static InfinitAvatarManager* _instance = nil;

@implementation InfinitAvatarManager
{
  NSMutableDictionary* _avatar_map;
}

#pragma mark - Init

- (id)init
{
  if (self = [super init])
  {
    _avatar_map = [NSMutableDictionary dictionary];
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitAvatarManager alloc] init];
  return _instance;
}

#pragma mark - Public Functions

- (UIImage*)avatarForUser:(InfinitUser*)user
{
  UIImage* avatar = [_avatar_map objectForKey:user.id_];
  if (avatar == nil)
  {
    avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:user.id_];
  }
  return avatar;
}

#pragma mark - State Manager Callback

- (void)gotAvatarForUserWithId:(NSNumber*)id_
{
  @synchronized(_avatar_map)
  {
    UIImage* avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:id_];
    if (avatar != nil)
    {
      [_avatar_map setObject:avatar forKey:id_];
    }
  }
}

- (void)sendAvatarNotificationForUser:(InfinitUser*)user
{
  NSDictionary* user_info = @{@"id": user.id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_USER_AVATAR_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

@end
