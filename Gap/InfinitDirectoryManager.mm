//
//  InfinitDirectoryManager.m
//  Gap
//
//  Created by Christopher Crone on 24/01/15.
//
//

#import "InfinitDirectoryManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.DirectoryManager");

static InfinitDirectoryManager* _instance = nil;

@implementation InfinitDirectoryManager

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitDirectoryManager alloc] init];
  return _instance;
}

#pragma mark - Transaction

- (NSString*)downloadDirectoryForTransaction:(InfinitTransaction*)transaction
{
  NSString* res = [self.download_directory stringByAppendingPathComponent:transaction.meta_id];
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:NO
                                               attributes:nil
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create transaction download folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return res;
}

#pragma mark - Directory Handling

- (NSString*)avatar_cache_directory
{
  NSString* cache_dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                            NSUserDomainMask,
                                                            YES).firstObject;
  NSString* avatar_dir = cache_dir;
  NSDictionary* attrs = nil;
#if TARGET_OS_IPHONE
  attrs = @{NSURLIsExcludedFromBackupKey: @YES};
#else
  avatar_dir = [avatar_dir stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier];
#endif
  avatar_dir = [avatar_dir stringByAppendingPathComponent:@"avatar_cache"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:avatar_dir isDirectory:NULL])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:avatar_dir
                              withIntermediateDirectories:YES
                                               attributes:attrs
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

- (NSString*)download_directory
{
  NSString* res = nil;
  NSDictionary* attrs = nil;
#if TARGET_OS_IPHONE
  NSString* doc_dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                          NSUserDomainMask,
                                                          YES).firstObject;
  res = [doc_dir stringByAppendingPathComponent:@"Downloads"];
  attrs = @{NSURLIsExcludedFromBackupKey: @NO};
#else
  res =
    NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES).firstObject;
#endif
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:NO
                                               attributes:attrs
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create download folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return res;
}

- (NSString*)log_directory
{
  NSString* res = [self.non_persistent_directory stringByAppendingPathComponent:@"logs"];
  NSDictionary* attrs = nil;
#if TARGET_OS_IPHONE
  attrs = @{NSURLIsExcludedFromBackupKey: @YES};
#endif
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:YES
                                               attributes:attrs
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create log folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return res;
}

- (NSString*)persistent_directory
{
  NSString* res = nil;
  NSDictionary* attrs = nil;
#if TARGET_OS_IPHONE
  NSString* app_support_dir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                  NSUserDomainMask,
                                                                  YES).firstObject;
  res = [app_support_dir stringByAppendingPathComponent:@"persistent"];
  attrs = @{NSURLIsExcludedFromBackupKey: @NO};
#else
  res = [NSHomeDirectory() stringByAppendingPathComponent:@".infinit"];
#endif
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:YES
                                               attributes:attrs
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create persistent folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return res;
}

- (NSString*)non_persistent_directory
{
  NSString* res = nil;
  NSDictionary* attrs = nil;
#if TARGET_OS_IPHONE
  NSString* app_support_dir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                  NSUserDomainMask,
                                                                  YES).firstObject;
  res = [app_support_dir stringByAppendingPathComponent:@"non-persistent"];
  attrs = @{NSURLIsExcludedFromBackupKey: @YES};
#else
  res = [NSHomeDirectory() stringByAppendingPathComponent:@".infinit"];
#endif
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:YES
                                               attributes:attrs
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create non-persistent folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return res;
}

- (NSString*)temporary_files_directory
{
#if !TARGET_OS_IPHONE
  NSCAssert(false, @"Temporary files directory only used on iOS");
#endif
  NSString* res = [NSTemporaryDirectory() stringByAppendingPathComponent:@"managed_files"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:NO
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create temporary managed files folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return res;
}

- (NSString*)thumbnail_cache_directory
{
#if !TARGET_OS_IPHONE
  NSCAssert(false, @"Thumbnail cache directory only used on iOS");
#endif
  NSString* cache_dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                            NSUserDomainMask,
                                                            YES).firstObject;
  NSString* thumbnail_dir = [cache_dir stringByAppendingPathComponent:@"thumbnail_cache"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:thumbnail_dir isDirectory:NULL])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:thumbnail_dir
                              withIntermediateDirectories:YES
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create thumbnail cache folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return thumbnail_dir;
}

- (NSString*)upload_thumbnail_cache_directory
{
#if !TARGET_OS_IPHONE
  NSCAssert(false, @"Upload thumbnail cache directory only used on iOS");
#endif
  NSString* cache_dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                            NSUserDomainMask,
                                                            YES).firstObject;
  NSString* thumbnail_dir = [cache_dir stringByAppendingPathComponent:@"upload_thumbnail_cache"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:thumbnail_dir isDirectory:NULL])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:thumbnail_dir
                              withIntermediateDirectories:YES
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:&error];
    if (error)
    {
      ELLE_ERR("%s: unable to create upload thumbnail cache folder: %s",
               self.description.UTF8String, error.description.UTF8String);
      return nil;
    }
  }
  return thumbnail_dir;
}

#pragma mark - Disk Space

- (uint64_t)free_space
{
  uint64_t res = 0;
  __autoreleasing NSError* error = nil;
  NSString* path = self.download_directory;
  NSDictionary* dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path
                                                                               error:&error];
  if (dict)
  {
    NSNumber* free_space_in_bytes = [dict objectForKey:NSFileSystemFreeSize];
    res = free_space_in_bytes.unsignedLongLongValue;
  }
  else
  {
    NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld",
          error.domain, (long)error.code);
  }
  return res;
}

@end
