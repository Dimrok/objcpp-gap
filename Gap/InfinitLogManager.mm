//
//  InfinitLogManager.m
//  Gap
//
//  Created by Christopher Crone on 16/01/15.
//
//

#import "InfinitLogManager.h"

#import "InfinitDirectoryManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.LogManager");

static InfinitLogManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitLogManager
{
@private
  NSInteger _current_number;
}

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    [self rollLogs];
#if !TARGET_OS_IPHONE
    [self _cleanOldLogs];
#endif
  }
  return self;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitLogManager alloc] init];
  });
  return _instance;
}

- (void)_cleanOldLogs
{
  // Remove old format logs: state_<x>.log.
  NSError* error = nil;
  NSString* old_log_dir = [NSHomeDirectory() stringByAppendingPathComponent:@".infinit"];
  NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:old_log_dir
                                                                          error:&error];
  NSMutableArray* old_logs = [NSMutableArray array];
  for (NSString* file in contents)
  {
    if ([file.pathExtension isEqualToString:@"log"])
      [old_logs addObject:file];
  }
  NSString* path = nil;
  for (NSString* file in old_logs)
  {
    path = [old_log_dir stringByAppendingPathComponent:file];
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
  }
}

#pragma mark - General

- (NSString*)crash_report_path
{
  return [[self logFolder] stringByAppendingPathComponent:@"last_crash.crash"];
}

- (NSString*)current_log_path
{
  return [[self logFolder] stringByAppendingPathComponent:@"current_state.log"];
}

- (NSString*)last_log_path
{
  return [[self logFolder] stringByAppendingPathComponent:@"last_state.log"];
}

#pragma mark - Helpers

- (void)rollLogs
{
  if ([[NSFileManager defaultManager] fileExistsAtPath:self.last_log_path])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.last_log_path error:&error];
    if (error != nil)
    {
      ELLE_ERR("%s: unable to remove existing log: %s",
               self.description.UTF8String, self.last_log_path.UTF8String);
    }
  }
  if ([[NSFileManager defaultManager] fileExistsAtPath:self.current_log_path])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] moveItemAtPath:self.current_log_path
                                            toPath:self.last_log_path
                                             error:&error];
    if (error != nil)
    {
      ELLE_ERR("%s: unable to move existing log: %s",
               self.description.UTF8String, self.current_log_path.UTF8String);
    }
  }
}

- (NSString*)logFolder
{
  return [InfinitDirectoryManager sharedInstance].log_directory;
}

@end
