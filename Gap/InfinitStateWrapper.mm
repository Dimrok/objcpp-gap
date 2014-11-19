//
//  InfinitStateWrapper.mm
//  Infinit
//
//  Created by Christopher Crone on 29/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitStateWrapper.h"

static InfinitStateWrapper* _wrapper_instance = nil;

@implementation InfinitStateWrapper

- (id)initWithState:(gap_State*)state
{
  NSCAssert(_wrapper_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _state = state;
  }
  return self;
}

- (void)dealloc
{
  _wrapper_instance = nil;
  if (_state != nullptr)
    gap_free(_state);
}

#pragma mark - Set Environment Variables

+ (void)setEnvironmentVariables
{
  setenv("INFINIT_META_PROTOCOL", "http", 0);
  setenv("INFINIT_META_HOST", "192.168.0.14", 0);
  setenv("INFINIT_META_PORT", "8080", 0);

  setenv("INFINIT_TROPHONIUS_HOST", "192.168.0.14", 0);
  setenv("INFINIT_TROPHONIUS_PORT", "8181", 0);

//  setenv("INFINIT_PRODUCTION", "1", 0);

  setenv("ELLE_REAL_ASSERT", "1", 0);

  std::string log_level =
    "elle.CrashReporter:DEBUG,"
    "*FIST*:TRACE,"
    "*FIST.State*:DEBUG,"
    "frete.Frete:TRACE,"
    "infinit.surface.gap.Rounds:DEBUG,"
    "*meta*:TRACE,"
    "OSX*:DUMP,"
    "reactor.fsm.*:TRACE,"
    "reactor.network.upnp:DEBUG,"
    "station.Station:DEBUG,"
    "surface.gap.*:TRACE,"
    "surface.gap.TransferMachine:DEBUG,"
    "*trophonius*:DEBUG";
  setenv("ELLE_LOG_LEVEL", log_level.c_str(), 0);
  setenv("ELLE_LOG_TIME", "1", 0);
}

#pragma mark - Fetch Directories

+ (NSString*)downloadDirectory
{
  NSString* doc_dir =
    NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
  NSString* res = [doc_dir stringByAppendingPathComponent:@"Downloads"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:NO
                                               attributes:@{NSURLIsExcludedFromBackupKey: @NO}
                                                    error:nil];
  }
  return res;
}

+ (NSString*)persistentConfigDirectory
{
  NSString* app_support_dir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                  NSUserDomainMask,
                                                                  YES).firstObject;
  NSString* res = [app_support_dir stringByAppendingPathComponent:@"persistent"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:YES
                                               attributes:@{NSURLIsExcludedFromBackupKey: @NO}
                                                    error:nil];
  }
  return res;
}

+ (NSString*)nonPersistentConfigDirectory
{
  NSString* app_support_dir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                  NSUserDomainMask,
                                                                  YES).firstObject;
  NSString* res = [app_support_dir stringByAppendingPathComponent:@"non-persistent"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:NO
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:nil];
  }
  return res;
}

+ (NSString*)temporaryStorageDirectory
{
  NSString* cache_dir =
    NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
  NSString* res = [cache_dir stringByAppendingPathComponent:@"storage"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:res])
  {
    [[NSFileManager defaultManager] createDirectoryAtPath:res
                              withIntermediateDirectories:YES
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:nil];
  }
  return res;
}

#pragma mark - Setup Instace

+ (instancetype)sharedInstance
{
  if (_wrapper_instance == nil)
  {
    BOOL production = NO;
    [InfinitStateWrapper setEnvironmentVariables];
    NSString* download_dir = [InfinitStateWrapper downloadDirectory];
    NSString* persistent_config_dir = [InfinitStateWrapper persistentConfigDirectory];
    NSString* non_persistent_config_dir = [InfinitStateWrapper nonPersistentConfigDirectory];
    NSString* temp_storage_dir = [InfinitStateWrapper temporaryStorageDirectory];
    _wrapper_instance =
      [[InfinitStateWrapper alloc] initWithState:gap_new(production,
                                                         download_dir.UTF8String,
                                                         persistent_config_dir.UTF8String,
                                                         non_persistent_config_dir.UTF8String,
                                                         temp_storage_dir.UTF8String)];
  }
  return _wrapper_instance;
}

@end
