//
//  InfinitLogManager.m
//  Gap
//
//  Created by Christopher Crone on 16/01/15.
//
//

#import "InfinitLogManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.LogManager");

static InfinitLogManager* _instance = nil;

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
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitLogManager alloc] init];
  return _instance;
}

#pragma mark - General

- (NSString*)crashReportPath
{
  return [[self logFolder] stringByAppendingPathComponent:@"last_crash.log"];
}

- (NSString*)currentLogPath
{
  return [[self logFolder] stringByAppendingPathComponent:@"current_state.log"];
}

- (NSString*)lastLogPath
{
  return [[self logFolder] stringByAppendingPathComponent:@"last_state.log"];
}

#pragma mark - Helpers

- (void)rollLogs
{
  if ([[NSFileManager defaultManager] fileExistsAtPath:[self lastLogPath]])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self lastLogPath] error:&error];
    if (error != nil)
    {
      ELLE_ERR("%s: unable to remove existing log: %s",
               self.description.UTF8String, [self lastLogPath].UTF8String);
    }
  }
  if ([[NSFileManager defaultManager] fileExistsAtPath:[self currentLogPath]])
  {
    NSError* error = nil;
    [[NSFileManager defaultManager] moveItemAtPath:[self currentLogPath]
                                            toPath:[self lastLogPath]
                                             error:&error];
    if (error != nil)
    {
      ELLE_ERR("%s: unable to move existing log: %s",
               self.description.UTF8String, [self currentLogPath].UTF8String);
    }
  }
}

- (NSString*)logFolder
{
  NSString* app_support_dir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                  NSUserDomainMask,
                                                                  YES).firstObject;
  NSString* log_folder = [[app_support_dir stringByAppendingPathComponent:@"non-persistent"]
                                           stringByAppendingPathComponent:@"logs"];

  if (![[NSFileManager defaultManager] fileExistsAtPath:log_folder])
  {
    [[NSFileManager defaultManager] createDirectoryAtPath:log_folder
                              withIntermediateDirectories:YES
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:nil];
  }
  return log_folder;
}

@end
