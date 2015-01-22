//
//  InfinitAvatarManager.m
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import "InfinitAvatarManager.h"
#import "InfinitStateManager.h"
#import "InfinitUserManager.h"

#import "NSString+email.h"

#if TARGET_OS_IPHONE
# import <UIKit/UIKit.h>
#endif

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.AvatarManager");

static InfinitAvatarManager* _instance = nil;

@interface InfinitAvatarManager ()

@property (readonly) NSString* avatar_dir;

@end

@implementation InfinitAvatarManager
{
  NSMutableDictionary* _avatar_map;
  NSMutableSet* _requested_avatars;
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
    _requested_avatars = [NSMutableSet set];
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

- (NSString*)avatar_dir
{
  NSString* cache_dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                            NSUserDomainMask,
                                                            YES).firstObject;
  NSString* avatar_dir = [cache_dir stringByAppendingPathComponent:@"avatar_cache"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:avatar_dir isDirectory:NULL])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:avatar_dir
                              withIntermediateDirectories:YES
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create avatar cache folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return avatar_dir;
}

- (NSString*)pathForUser:(InfinitUser*)user
{
  NSString* res = [self.avatar_dir stringByAppendingPathComponent:user.meta_id];
  return [res stringByAppendingPathExtension:@"jpg"];
}

- (void)writeUser:(InfinitUser*)user
avatarToDiskCache:(UIImage*)avatar
{
  NSError* error = nil;
  [UIImageJPEGRepresentation(avatar, 0.8f) writeToFile:[self pathForUser:user]
                                               options:NSDataWritingAtomic
                                                 error:&error];
  if (error)
  {
    ELLE_ERR("%s: unable to write avatar (%s) to disk: %s",
             self.description.UTF8String, user.meta_id.UTF8String, error.description.UTF8String);
  }
}

- (UIImage*)diskCacheAvatarForUser:(InfinitUser*)user
{
  NSError* error = nil;
  NSArray* cached_files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.avatar_dir
                                                                              error:&error];
  if (error)
  {
    ELLE_ERR("%s: unable to fetch avatar cache directory contents: %s",
             self.description.UTF8String, error.description.UTF8String);
    return nil;
  }
  for (NSString* item in cached_files)
  {
    NSString* user_id = [item stringByDeletingPathExtension];
    if ([user_id isEqualToString:user.meta_id])
    {
      NSString* path = [self.avatar_dir stringByAppendingPathComponent:item];
      UIImage* avatar = [UIImage imageWithContentsOfFile:path];
      if (avatar != nil)
      {
        [_avatar_map setObject:avatar forKey:user_id];
        return avatar;
      }
    }
  }
  return nil;
}

#pragma mark - Public Functions

#if TARGET_OS_IPHONE
- (UIImage*)avatarForUser:(InfinitUser*)user
{
  UIImage* avatar = [_avatar_map objectForKey:user.meta_id];
#else
- (NSImage*)avatarForUser:(InfinitUser*)user
{
  NSImage* avatar = [_avatar_map objectForKey:user.meta_id];
#endif
  if (![_requested_avatars containsObject:user.meta_id])
  {
    [_requested_avatars addObject:user.meta_id];
    avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:user.id_];
  }
  if (avatar == nil)
  {
    avatar = [self diskCacheAvatarForUser:user];
    if (avatar == nil)
    {
      avatar = [self generateAvatarForUser:user];
      [_avatar_map setObject:avatar forKey:user.meta_id];
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
      InfinitUser* user = [[InfinitUserManager sharedInstance] userWithId:id_];
      [_avatar_map setObject:avatar forKey:user.meta_id];
      [self sendAvatarNotificationForUser:user];
      [self writeUser:user avatarToDiskCache:avatar];
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

#pragma mark - Clear Cache

- (void)clearCachedAvatars
{
  [_avatar_map removeAllObjects];
}

@end
