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
#import "InfinitThreadSafeDictionary.h"
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
static INFINIT_IMAGE* _email_avatar = nil;
static INFINIT_IMAGE* _phone_avatar = nil;


@interface InfinitAvatarManager ()

@property (atomic, readonly) NSString* avatar_dir;
@property (nonatomic, readonly) InfinitThreadSafeDictionary* avatar_map;
@property (atomic, readonly) NSMutableSet* requested_avatars;

@end

@implementation InfinitAvatarManager

#pragma mark - Init

- (id)init
{
  if (self = [super init])
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
                                               object:nil];
    _avatar_map = [InfinitThreadSafeDictionary initWithName:@"AvatarModel"];
    _requested_avatars = [NSMutableSet set];
    if (_phone_avatar == nil)
      _phone_avatar = [INFINIT_IMAGE imageNamed:@"avatar-phone"];
    if (_email_avatar == nil)
      _email_avatar = [INFINIT_IMAGE imageNamed:@"avatar-email"];

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

- (void)writeUser:(InfinitUser*)user
avatarToDiskCache:(INFINIT_IMAGE*)avatar
{
  NSError* error = nil;
#if TARGET_OS_IPHONE
  [UIImageJPEGRepresentation(avatar, 1.0f) writeToFile:[self pathForUser:user]
                                               options:NSDataWritingAtomic
                                                 error:&error];
#else
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

- (INFINIT_IMAGE*)diskCacheAvatarForUser:(InfinitUser*)user
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
      INFINIT_IMAGE* avatar = [[INFINIT_IMAGE alloc] initWithContentsOfFile:path];
      if (avatar != nil && user_id != nil)
      {
        [self.avatar_map setObject:avatar forKey:user_id];
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
    [[NSFileManager defaultManager] removeItemAtPath:[self pathForUser:user] error:&error];
  if (error)
  {
    ELLE_WARN("%s: unable to remove cached avatar (%s): %s",
              self.description.UTF8String, user.meta_id.UTF8String, error.description.UTF8String);
  }
}

#pragma mark - Public Functions

- (void)setSelfAvatar:(INFINIT_IMAGE*)avatar
{
  [[InfinitStateManager sharedInstance] setSelfAvatar:avatar
                                      performSelector:@selector(setAvatarCallback:)
                                             onObject:self];
  InfinitUser* me = [InfinitUserManager sharedInstance].me;
  [self.avatar_map setObject:avatar forKey:me.meta_id];
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

- (INFINIT_IMAGE*)avatarForUser:(InfinitUser*)user
{
  if (user.id_.unsignedIntegerValue == 0)
    return nil;
  INFINIT_IMAGE* avatar = [self.avatar_map objectForKey:user.meta_id];
  if (avatar == nil && ![self.requested_avatars containsObject:user.meta_id])
  {
    [self.requested_avatars addObject:user.meta_id];
    avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:user.id_];
  }
  if (avatar == nil)
  {
    avatar = [self diskCacheAvatarForUser:user];
    if (avatar == nil)
    {
      avatar = [self generateAvatarForUser:user];
      [self.avatar_map setObject:avatar forKey:user.meta_id];
    }
  }
  return avatar;
}

- (void)clearAvatarForUser:(InfinitUser*)user
{
  [self removeDiskCacheForUser:user];
  [self.avatar_map removeObjectForKey:user.meta_id];
}

- (void)setAvatar:(INFINIT_IMAGE*)avatar
          forUser:(InfinitUser*)user
{
  [self.avatar_map setObject:avatar forKey:user.meta_id];
  [self writeUser:user avatarToDiskCache:avatar];
  [self.requested_avatars removeObject:user.meta_id];
  [self sendAvatarNotificationForUser:user];
}

#pragma mark - Generate Avatar

- (INFINIT_IMAGE*)generateAvatarForUser:(InfinitUser*)user
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
  INFINIT_IMAGE* res = nil;
#if TARGET_OS_IPHONE
  CGFloat scale = [UIScreen mainScreen].scale;
  rect = CGRectMake(rect.origin.x, rect.origin.y,
                    rect.size.width * scale, rect.size.height * scale);
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  [fill_color setFill];
  CGContextFillRect(context, rect);
  attrs = @{NSFontAttributeName: [UIFont fontWithName:font_name
                                                 size:(font_size * scale)],
            NSForegroundColorAttributeName: text_color};
#else
  res = [[NSImage alloc] initWithSize:NSMakeSize(rect.size.width, rect.size.height)];
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
  INFINIT_IMAGE* avatar = [[InfinitStateManager sharedInstance] avatarForUserWithId:id_];
  if (avatar != nil)
  {
    InfinitUser* user = [[InfinitUserManager sharedInstance] userWithId:id_];
    [self setAvatar:avatar forUser:user];
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
  [self.avatar_map removeAllObjects];
}

@end
