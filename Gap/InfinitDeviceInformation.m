//
//  InfinitDeviceInformation.m
//  Gap
//
//  Created by Christopher Crone on 01/04/15.
//
//

#import "InfinitDeviceInformation.h"

#if TARGET_OS_IPHONE
# import <UIKit/UIKit.h>
#endif

#import <sys/sysctl.h>

@implementation InfinitDeviceInformation

+ (NSString*)deviceName
{
  NSString* res = nil;
#if TARGET_OS_IPHONE
  res = [UIDevice currentDevice].name;
#else
  res = [NSHost currentHost].localizedName;
#endif
  if (res.length > 64)
    return [res substringToIndex:63];
  else if (res.length > 1)
    return res;
  else
    return @"Unknown";
}

+ (NSString*)deviceModel
{
  NSString* res = @"unknown";
  size_t len = 0;
#if TARGET_OS_IPHONE
  NSString* search_string = @"hw.machine";
#else
  NSString* search_string = @"hw.model";
#endif
  sysctlbyname(search_string.UTF8String, NULL, &len, NULL, 0);
  if (len)
  {
    char* model = malloc(len * sizeof(char));
    sysctlbyname(search_string.UTF8String, model, &len, NULL, 0);
    res = [NSString stringWithUTF8String:model];
    free(model);
  }
  return res;
}

@end
