//
//  InfinitAvatarManager.m
//  Gap
//
//  Created by Christopher Crone on 14/11/14.
//
//

#import "InfinitAvatarManager.h"

#import "InfinitColor.h"
#import "InfinitDirectoryManager.h"
#import "InfinitStateManager.h"
#import "InfinitStateResult.h"
#import "InfinitUserManager.h"

#import "NSString+email.h"
#import "NSString+PhoneNumber.h"

#if TARGET_OS_IPHONE
# import <UIKit/UIKit.h>
#endif

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.AvatarManager");

static InfinitAvatarManager* _instance = nil;
static dispatch_once_t _instance_token = 0;
#if TARGET_OS_IPHONE
static UIImage* _email_avatar = nil;
static UIImage* _phone_avatar = nil;
#else
static NSImage* _email_avatar = nil;
static NSImage* _phone_avatar = nil;
#endif


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
                                             selector:@selector(clearModel)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    _avatar_map = [NSMutableDictionary dictionary];
    _requested_avatars = [NSMutableSet set];
    if (_phone_avatar == nil)
    {
#if TARGET_OS_IPHONE
      _phone_avatar = [UIImage imageNamed:@"avatar-phone"];
#else
      _phone_avatar = [NSImage imageNamed:@"avatar-phone"];
#endif
    }
    if (_email_avatar == nil)
    {
#if TARGET_OS_IPHONE
      _email_avatar = [UIImage imageNamed:@"avatar-email"];
#else
      _email_avatar = [NSImage imageNamed:@"avatar-phone"];
#endif
    }

  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearModel
{
  _instance = nil;
  _instance_token = 0;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitAvatarManager alloc] init];
  });
  return _instance;
}

- (NSString*)avatar_dir
{
  return [InfinitDirectoryManager sharedInstance].avatar_cache_directory;
}

- (NSString*)pathForUser:(InfinitUser*)user
{
  NSString* res = [self.avatar_dir stringByAppendingPathComponent:user.meta_id];
  return [res stringByAppendingPathExtension:@"jpg"];
}

#if TARGET_OS_IPHONE
- (void)writeUser:(InfinitUser*)user
avatarToDiskCache:(UIImage*)avatar
{
  NSError* error = nil;
  [UIImageJPEGRepresentation(avatar, 1.0f) writeToFile:[self pathForUser:user]
                                               options:NSDataWritingAtomic
                                                 error:&error];
#else
- (void)writeUser:(InfinitUser*)user
avatarToDiskCache:(NSImage*)avatar
  {
    NSError* error = nil;
    NSData* image_data = avatar.TIFFRepresentation;
    NSBitmapImageRep* image_rep = [[NSBitmapImageRep imageRepsWithData:image_data] firstObject];
    NSDictionary* image_properties = @{NSImageCompressionFactor: @1.0f};
    image_data = [image_rep representationUsingType:NSJPEGFileType properties:image_properties];
    [image_data writeToFile:[self pathForUser:user] options:NSDataWritingAtomic error:&error];
#endif
  if (error)
  {
    ELLE_ERR("%s: unable to write avatar (%s) to disk: %s",
             self.description.UTF8String, user.meta_id.UTF8String, error.description.UTF8String);
  }
}

#if TARGET_OS_IPHONE
- (UIImage*)diskCacheAvatarForUser:(InfinitUser*)user
#else
- (NSImage*)diskCacheAvatarForUser:(InfinitUser*)user
#endif
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
#if TARGET_OS_IPHONE
      UIImage* avatar = [UIImage imageWithContentsOfFile:path];
#else
      NSImage* avatar = [[NSImage alloc] initWithContentsOfFile:path];
#endif
      if (avatar != nil && user_id != nil)
      {
        [_avatar_map setObject:avatar forKey:user_id];
        return avatar;
      }
    }
  }
  return nil;
}

- (void)removeDiskCacheForUser:(InfinitUser*)user
{
  NSError* error = nil;
  if ([[NSFileManager defaultManager] fileExistsAtPath:[self pathForUser:user]])
  {
    [[NSFileManager defaultManager] removeItemAtPath:[self pathForUser:user] error:&error];
  }
  if (error)
  {
    ELLE_WARN("%s: unable to remove cached avatar (%s): %s",
              self.description.UTF8String, user.meta_id.UTF8String, error.description.UTF8String);
  }
}

#pragma mark - Public Functions

#if TARGET_OS_IPHONE
- (void)setSelfAvatar:(UIImage*)avatar
#else
- (void)setSelfAvatar:(NSImage*)avatar
#endif
{
  [[InfinitStateManager sharedInstance] setSelfAvatar:avatar
                                      performSelector:@selector(setAvatarCallback:)
                                             onObject:self];
  InfinitUser* me = [InfinitUserManager sharedInstance].me;
  [_avatar_map setObject:avatar forKey:me.meta_id];
}

- (void)setAvatarCallback:(InfinitStateResult*)result
{
  if (result.success)
  {
    InfinitUser* me = [InfinitUserManager sharedInstance].me;
    [self removeDiskCacheForUser:me];
  }
  else
  {
    ELLE_ERR("%s: unable to set self avatar", self.description.UTF8String);
  }
}

#if TARGET_OS_IPHONE
- (UIImage*)avatarForUser:(InfinitUser*)user
#else
- (NSImage*)avatarForUser:(InfinitUser*)user
#endif
{
  if (user.id_.unsignedIntegerValue == 0)
    return nil;
#if TARGET_OS_IPHONE
  UIImage* avatar = [_avatar_map objectForKey:user.meta_id];
#else
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

- (void)clearAvatarForUser:(InfinitUser*)user
{
  [self removeDiskCacheForUser:user];
  [_avatar_map removeObjectForKey:user.meta_id];
}

#pragma mark - Generate Avatar

#if TARGET_OS_IPHONE
- (UIImage*)generateAvatarForUser:(InfinitUser*)user
#else
- (NSImage*)generateAvatarForUser:(InfinitUser*)user
#endif
{
#if TARGET_OS_IPHONE
  if (user.fullname.infinit_isPhoneNumber)
    return _phone_avatar;
  else if (user.fullname.infinit_isEmail)
    return _email_avatar;
#endif
  INFINIT_COLOR* fill_color = [InfinitColor colorWithRed:202 green:217 blue:223];
  INFINIT_COLOR* text_color = [InfinitColor colorWithGray:255];
  CGRect rect = CGRectMake(0.0f, 0.0f, 120.0f, 120.0f);
  NSMutableString* text = [[NSMutableString alloc] init];
  if (user.fullname.length == 0)
    [text appendFormat:@" "];
  else if (user.fullname.infinit_isEmail)
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
  NSDictionary* attrs = nil;
  NSString* font_name = @"HelveticaNeue-Light";
  CGFloat font_size = 51.0f;
#if TARGET_OS_IPHONE
  CGFloat scale = [UIScreen mainScreen].scale;
  rect = CGRectMake(rect.origin.x, rect.origin.y,
                    rect.size.width * scale, rect.size.height * scale);
  UIImage* res = nil;
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  [fill_color setFill];
  CGContextFillRect(context, rect);
  attrs = @{NSFontAttributeName: [UIFont fontWithName:font_name
                                                 size:(font_size * scale)],
            NSForegroundColorAttributeName: text_color};
#else
  NSImage* res = [[NSImage alloc] initWithSize:NSMakeSize(rect.size.width, rect.size.height)];
  [res lockFocus];
  [fill_color set];
  NSBezierPath* path = [NSBezierPath bezierPathWithRect:NSRectFromCGRect(rect)];
  [path fill];
  attrs = @{NSFontAttributeName: [NSFont fontWithName:font_name
                                                 size:font_size],
            NSForegroundColorAttributeName: text_color};
#endif
  NSAttributedString* str = [[NSAttributedString alloc] initWithString:text attributes:attrs];
  [str drawAtPoint:CGPointMake(round((rect.size.width - str.size.width) / 2.0f),
                               round((rect.size.height - str.size.height) / 2.0f))];
#if TARGET_OS_IPHONE
  res = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
#else
  [res unlockFocus];
#endif
  return res;
}

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
  NSDictionary* user_info = @{kInfinitUserId: user.id_};
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_USER_AVATAR_NOTIFICATION
                                                        object:self
                                                      userInfo:user_info];
  });
}

#pragma mark - Clear Cache

- (void)clearCachedAvatars
{
  [_avatar_map removeAllObjects];
}

@end
