//
//  InfinitCrashReporter.m
//  Gap
//
//  Created by Christopher Crone on 16/01/15.
//
//

#import "InfinitCrashReporter.h"

#import "InfinitLogManager.h"
#import "InfinitStateManager.h"
#import "InfinitStateResult.h"

#import "CrashReporter.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.CrashReporter");

static InfinitCrashReporter* _instance = nil;

@implementation InfinitCrashReporter
{
@private
  PLCrashReporter* _reporter;
}

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
#if TARGET_OS_IPHONE
    PLCrashReporterConfig* config = [PLCrashReporterConfig defaultConfiguration];
#else
    PLCrashReporterConfig* config =
      [[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD
                                         symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll];
#endif
    _reporter = [[PLCrashReporter alloc] initWithConfiguration:config];
    NSError* error = nil;
    [_reporter enableCrashReporterAndReturnError:&error];
    if (error != nil)
    {
      ELLE_ERR("%s: unable to configure crash reporter: %@", self.description.UTF8String, error);
    }
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitCrashReporter alloc] init];
  return _instance;
}

#pragma mark - General

- (void)sendExistingCrashReport
{
  if (![_reporter hasPendingCrashReport])
    return;
  NSError* error = nil;
  NSData* crash_data = [_reporter loadPendingCrashReportDataAndReturnError:&error];
  if (error != nil)
  {
    ELLE_ERR("%s: unable to fetch crash report data: %@", self.description.UTF8String, error);
    return;
  }
  PLCrashReport* crash_log = [[PLCrashReport alloc] initWithData:crash_data error:&error];
  if (error != nil)
  {
    ELLE_ERR("%s: unable to decode crash report data: %@", self.description.UTF8String, error);
    return;
  }
  PLCrashReportTextFormat format = PLCrashReportTextFormatiOS;
  NSString* report = [PLCrashReportTextFormatter stringValueForCrashReport:crash_log
                                                            withTextFormat:format];
  NSString* crash_log_path = [InfinitLogManager sharedInstance].crash_report_path;
  [report writeToFile:crash_log_path
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:&error];
  if (error != nil)
  {
    ELLE_ERR("%s: unable to write crash report: %@", self.description.UTF8String, error);
    return;
  }
  NSString* state_log = [InfinitLogManager sharedInstance].last_log_path;
  [[InfinitStateManager sharedInstance] sendLastCrashLog:crash_log_path
                                            withStateLog:state_log 
                                         performSelector:@selector(sendCrashLogsCallback:)
                                                onObject:self];
}

- (void)sendCrashLogsCallback:(InfinitStateResult*)result
{
  if (result.success)
  {
    ELLE_LOG("%s: successfully sent last crash", self.description.UTF8String);
  }
  else
  {
    ELLE_ERR("%s: unable to send last crash: %d", self.description.UTF8String, result.status);
  }
  NSError* error = nil;
  [_reporter purgePendingCrashReportAndReturnError:&error];
  if (error != nil)
  {
    ELLE_ERR("%s: unable to purge last crash report", self.description.UTF8String);
  }
  NSString* report_path = [InfinitLogManager sharedInstance].crash_report_path;
  if ([[NSFileManager defaultManager] fileExistsAtPath:report_path])
  {
    error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:report_path error:&error];
    if (error != nil)
    {
      ELLE_ERR("%s: unable to remove crash report", self.description.UTF8String);
    }
  }
}

- (void)reportAProblem:(NSString*)problem
                  file:(NSString*)file
{
  [[InfinitStateManager sharedInstance] reportAProblem:problem
                                               andFile:file
                                       performSelector:@selector(reportAProblemCallback:)
                                              onObject:self];
}

- (void)reportAProblemCallback:(InfinitStateResult*)result
{
  if (result.success)
  {
    ELLE_LOG("%s: successfully reported a problem", self.description.UTF8String);
  }
  else
  {
    ELLE_ERR("%s: unable to report a problem: %d", self.description.UTF8String, result.status);
  }
}

@end
