//
//  InfinitGhostCodeManager.m
//  Gap
//
//  Created by Christopher Crone on 19/05/15.
//
//

#import "InfinitGhostCodeManager.h"

#import "InfinitStateManager.h"
#import "InfinitURLParser.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.GhostCodeManager");

@interface InfinitGhostCodeManager ()

@property (atomic, readonly) InfinitGhostCodeUsedBlock code_used_block;

@end

static InfinitGhostCodeManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitGhostCodeManager

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use sharedInstance.");
  if (self = [super init])
  {}
  return self;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitGhostCodeManager alloc] init];
  });
  return _instance;
}

#pragma mark - Code Handling

- (void)setCode:(NSString*)code
        wasLink:(BOOL)was_link
completionBlock:(InfinitGhostCodeUsedBlock)completion_block
{
  if (!code.length)
  {
    ELLE_WARN("%s: got empty code", self.description.UTF8String);
    return;
  }
  ELLE_TRACE("%s: set code: %s from %s",
             self.description.UTF8String, code.UTF8String, was_link ? "link" : "user");
  if (self.code_set)
  {
    ELLE_WARN("%s: overwriting ghost code used block", self.description.UTF8String);
  }
  _code_set = YES;
  _code_used_block = completion_block;
  [[InfinitStateManager sharedInstance] useGhostCode:code wasLink:was_link];
}

#pragma mark - State Manager Callback

- (void)ghostCodeUsed:(NSString*)code
              success:(BOOL)success
               reason:(NSString*)reason
{
  _code_set = NO;
  dispatch_async(dispatch_get_main_queue(), ^
  {
    if (self.code_used_block)
    {
      ELLE_TRACE("%s: ghost code used, run callback", self.description.UTF8String);
      if (self.code_used_block)
        self.code_used_block(code, success, reason);
      _code_used_block = nil;
      return;
    }
    ELLE_TRACE("%s: ghost code used, no callback to run", self.description.UTF8String);
  });
}

@end
