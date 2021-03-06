//
//  InfinitStateWrapper.mm
//  Infinit
//
//  Created by Christopher Crone on 29/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitStateWrapper.h"

#import "InfinitDirectoryManager.h"
#import "InfinitLogManager.h"

#import "NSNumber+DataSize.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.StateWrapper");

static InfinitStateWrapper* _wrapper_instance = nil;
static dispatch_once_t _instance_token = 0;
static BOOL _production = NO;

@implementation InfinitStateWrapper

- (id)initWithState:(gap_State*)state
{
  NSCAssert(_wrapper_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _state = state;
    NSString* free_space = @([InfinitDirectoryManager sharedInstance].free_space).infinit_fileSize;
    ELLE_LOG("%s: started state with %s of free space in download directory",
             self.description.UTF8String, free_space.UTF8String);
    [self diskUsage];
  }
  return self;
}

- (void)diskUsage
{
  InfinitDirectoryManager* manager = [InfinitDirectoryManager sharedInstance];
  const char* desc = self.description.UTF8String;
  NSString* folder_size = @([manager folderSize:manager.download_directory]).infinit_fileSize;
  ELLE_LOG("%s: download folder usage: %s", desc, folder_size.UTF8String);
  folder_size = @([manager folderSize:manager.avatar_cache_directory]).infinit_fileSize;
  ELLE_LOG("%s: avatar folder usage: %s", desc, folder_size.UTF8String);
  folder_size = @([manager folderSize:manager.temporary_files_directory]).infinit_fileSize;
  ELLE_LOG("%s: temporary files folder usage: %s", desc, folder_size.UTF8String);
  folder_size = @([manager folderSize:manager.thumbnail_cache_directory]).infinit_fileSize;
  ELLE_LOG("%s: download thumbnail cache folder usage: %s", desc, folder_size.UTF8String);
  folder_size = @([manager folderSize:manager.upload_thumbnail_cache_directory]).infinit_fileSize;
  ELLE_LOG("%s: upload thumbnail cache folder usage: %s", desc, folder_size.UTF8String);
}

- (void)dealloc
{
  if (self.state != nullptr)
    gap_free(_state);
  _wrapper_instance = nil;
  _instance_token = 0;
}

#pragma mark - Set Environment Variables

+ (void)setEnvironmentVariables
{
  NSString* log_file = [InfinitLogManager sharedInstance].current_log_path;
  if (log_file != nil && log_file.length > 0)
    setenv("INFINIT_LOG_FILE", log_file.UTF8String, 0);

  setenv("ELLE_LOG_TIME", "1", 0);

#if DEBUG
//  setenv("INFINIT_META_HOST", "preprod.meta.production.infinit.io", 1);
  std::string local_server = "192.168.0.43";

  setenv("INFINIT_META_PROTOCOL", "http", 0);
  setenv("INFINIT_META_HOST", local_server.c_str(), 0);
  setenv("INFINIT_META_PORT", "8080", 0);

  setenv("INFINIT_TROPHONIUS_HOST", local_server.c_str(), 0);
  setenv("INFINIT_TROPHONIUS_PORT", "8181", 0);

  setenv("ELLE_REAL_ASSERT", "1", 0);
//
//  setenv("INFINIT_CRASH_DEST", "chris@infinit.io", 0);
//
//  setenv("INFINIT_METRICS_INFINIT", "1", 0);
//  setenv("INFINIT_METRICS_INFINIT_HOST", local_server.c_str(), 0);
//  setenv("INFINIT_METRICS_INFINIT_PORT", "8282", 0);
//
//  std::string log_level =
//    "elle.CrashReporter:DEBUG,"
//    "*FIST*:TRACE,"
//    "*FIST.State*:DEBUG,"
//    "frete.Frete:TRACE,"
//    "infinit.surface.gap.Rounds:DEBUG,"
//    "*meta*:TRACE,"
//    "reactor.fsm.*:TRACE,"
//    "reactor.network.upnp:DEBUG,"
//    "station.Station:DEBUG,"
//    "surface.gap.*:TRACE,"
//    "surface.gap.TransferMachine:DEBUG,"
//    "Gap-ObjC++*:DEBUG,"
//    "iOS*:DEBUG,"
//    "*trophonius*:TRACE";
//  setenv("ELLE_LOG_LEVEL", log_level.c_str(), 0);

#else

  _production = YES;
//  setenv("INFINIT_META_HOST", "preprod.meta.production.infinit.io", 0);

#endif
}

#pragma mark - Setup Instace

+ (void)startStateWithInitialDownloadDir:(NSString*)download_dir
{
  NSCAssert(_wrapper_instance == nil, @"Use sharedInstance.");
  dispatch_once(&_instance_token, ^
  {
    [InfinitStateWrapper setEnvironmentVariables];
    InfinitDirectoryManager* dir_manager = [InfinitDirectoryManager sharedInstance];
    NSString* download = download_dir ? download_dir : dir_manager.download_directory;
    NSString* persistent_config_dir = dir_manager.persistent_directory;
    NSString* non_persistent_config_dir = dir_manager.non_persistent_directory;
#if TARGET_OS_IPHONE
    BOOL enable_mirroring = NO;
    uint64_t max_mirror_size = 0;
#else
    BOOL enable_mirroring = YES;
    uint64_t max_mirror_size = 500 * 1024 * 1024; // 500 MiB.
    [InfinitDirectoryManager sharedInstance].download_directory = download_dir;
#endif
    _wrapper_instance =
      [[InfinitStateWrapper alloc] initWithState:gap_new(_production,
                                                         download.UTF8String,
                                                         persistent_config_dir.UTF8String,
                                                         non_persistent_config_dir.UTF8String,
                                                         enable_mirroring,
                                                         max_mirror_size)];
  });
}

+ (instancetype)sharedInstance
{
  NSCAssert(_wrapper_instance != nil, @"Start instance with startStateWithInitialDownloadDir:");
  return _wrapper_instance;
}

@end
