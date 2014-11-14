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
  if (self = [super init])
  {
    _state = state;
  }
  return self;
}

+ (void)setLocalDev
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

+ (instancetype)sharedInstance
{
  if (_wrapper_instance == nil)
  {
    NSString* doc_dir =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString* download_dir = [doc_dir stringByAppendingPathComponent:@"Downloads"];
    BOOL is_dir;
    if (![[NSFileManager defaultManager] fileExistsAtPath:download_dir isDirectory:&is_dir])
    {
      [[NSFileManager defaultManager] createDirectoryAtPath:download_dir
                                withIntermediateDirectories:NO
                                                 attributes:nil
                                                      error:nil];
    }
    BOOL production = NO;
    [InfinitStateWrapper setLocalDev];
    _wrapper_instance =
    [[InfinitStateWrapper alloc] initWithState:gap_new(production, download_dir.UTF8String)];
  }
  return _wrapper_instance;
}

- (void)dealloc
{
  _wrapper_instance = nil;
  if (_state != nullptr)
    gap_free(_state);
}

@end
