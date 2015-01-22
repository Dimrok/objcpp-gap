//
//  InfinitAvatarManager.m
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import "InfinitAvatarManager.h"
#import "InfinitStateManager.h"

#import "NSString+email.h"

#if TARGET_OS_IPHONE
# import <UIKit/UIKit.h>
#endif

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel:)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    _avatar_map = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearModel:(NSNotification*)notification
{
  _instance = nil;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitAvatarManager alloc] init];
  return _instance;
}

#pragma mark - Public Functions

#if TARGET_OS_IPHONE
- (UIImage*)avatarForUser:(InfinitUser*)user
{
  UIImage* avatar = [_avatar_map objectForKey:user.id_];
#else
- (NSImage*)avatarForUser:(InfinitUser*)user
{
  NSImage* avatar = [_avatar_map objectForKey:user.id_];
#endif
  if (avatar == nil)
  {
    avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:user.id_];
    if (avatar == nil)
    {
      avatar = [self generateAvatarForUser:user];
      [_avatar_map setObject:avatar forKey:user.id_];
    }
  }
  return avatar;
}

#pragma mark - Generate Avatar

#if TARGET_OS_IPHONE
- (UIImage*)generateAvatarForUser:(InfinitUser*)user
{
  UIColor* fill = [UIColor colorWithRed:202.0f/255.0f
                                  green:217.0f/255.0f
                                   blue:223.0f/255.0f
                                  alpha:1.0f];
  CGFloat scale = [[UIScreen mainScreen] scale];
  CGRect rect = CGRectMake(0.0f, 0.0f, 120.0f * scale, 120.0f * scale);
  UIImage* res = [[UIImage alloc] init];
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  [fill setFill];
  CGContextFillRect(context, rect);
  [[UIColor whiteColor] set];
  NSMutableString* text = [[NSMutableString alloc] init];
  if (user.fullname.length == 0)
    [text appendFormat:@" "];
  else if (user.fullname.isEmail)
    [text appendFormat:@"@"];
  else
  {
    NSUInteger letters = 0;
    for (NSString* component in [user.fullname componentsSeparatedByString:@" "])
    {
      if (component.length > 0)
      {
        [text appendFormat:@"%c", [component characterAtIndex:0]];
        letters++;
        if (letters >= 2)
          break;
      }
    }
  }
  NSDictionary* attrs = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light"
                                                               size:(51.0f * scale)],
                          NSForegroundColorAttributeName: [UIColor whiteColor]};
  NSAttributedString* str = [[NSAttributedString alloc] initWithString:text attributes:attrs];
  [str drawAtPoint:CGPointMake(round((rect.size.width - str.size.width) / 2.0f),
                               round((rect.size.height - str.size.height) / 2.0f))];
  res = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return res;
}
#endif

#pragma mark - State Manager Callback

- (void)gotAvatarForUserWithId:(NSNumber*)id_
{
  @synchronized(_avatar_map)
  {
#if TARGET_OS_IPHONE
    UIImage* avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:id_];
#else
    NSImage* avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:id_];
#endif
    if (avatar != nil)
    {
      [_avatar_map setObject:avatar forKey:id_];
      [self sendAvatarNotificationForUserId:id_];
    }
  }
}

- (void)sendAvatarNotificationForUserId:(NSNumber*)id_
{
  NSDictionary* user_info = @{@"id": id_};
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_USER_AVATAR_NOTIFICATION
                                                      object:self
                                                    userInfo:user_info];
}

#pragma mark - Clear Cache

- (void)clearCachedAvatars
{
  [_avatar_map removeAllObjects];
}

@end
