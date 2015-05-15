//
//  InfinitCodeManager.m
//  Infinit
//
//  Created by Christopher Crone on 29/04/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import "InfinitCodeManager.h"

#import "InfinitConstants.h"

#import <Gap/InfinitConnectionManager.h>
#import <Gap/InfinitStateManager.h>

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.CodeManager");

@interface InfinitCodeManager ()

@property (nonatomic, readwrite) NSString* code;
@property (atomic, readonly) BOOL code_from_link;
@property (atomic, readonly) BOOL valid;

@end

static InfinitCodeManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitCodeManager

#pragma mark - Init

- (instancetype)init
{
  NSCAssert(_instance == nil, @"Use sharedInstance.");
  if (self = [super init])
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionStatusChanged:)
                                                 name:INFINIT_CONNECTION_STATUS_CHANGE
                                               object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitCodeManager alloc] init];
  });
  return _instance;
}

#pragma mark - General

- (void)setManualCode:(NSString*)code
{
  if (!code.length)
    return;
  ELLE_LOG("%s: set code manually: %s", self.description.UTF8String, code.UTF8String);
  _code_from_link = NO;
  _code = code;
}

- (void)setArgumentCode:(NSString*)code
{
  if (!code.length)
    return;
  ELLE_LOG("%s: set code from argument: %s", self.description.UTF8String, code.UTF8String);
  NSLog(@"xxx set code: %@", code);
  _code_from_link = YES;
  _code = code;
}

- (BOOL)has_code
{
  return self.code.length;
}

- (void)useCodeWithCompletionBlock:(InfinitCodeUsedBlock)completion_block
{
  NSLog(@"xxx use code");
  if (!self.code.length)
  {
    if (completion_block)
      completion_block(NO);
    return;
  }
  NSString* code_copy = [self.code copy];
  _code = nil;
  _valid = NO;
  __weak InfinitCodeManager* weak_self = self;
  [[InfinitStateManager sharedInstance] useGhostCode:code_copy
                                             wasLink:self.code_from_link
                                     completionBlock:^(InfinitStateResult* result)
  {
    InfinitCodeManager* strong_self = weak_self;
    if (completion_block)
      completion_block(result.success);
    strong_self->_code_from_link = NO;
  }];
}

- (BOOL)getCodeFromURL:(NSURL*)url
{
  if (![url.scheme isEqualToString:kInfinitURLScheme])
    return NO;
  ELLE_LOG("%s: get code from URL: %s", self.description.UTF8String, url.description.UTF8String);
  _code_from_link = NO;
  NSString* resource_specifier = [url.resourceSpecifier substringFromIndex:2];
  NSArray* components = [resource_specifier componentsSeparatedByString:@"/"];
  if ([components[0] isEqual:@"invitation"])
  {
    NSString* possible_code = nil;
    if ([components[1] rangeOfString:@"?"].location != NSNotFound)
      possible_code = [components[1] componentsSeparatedByString:@"?"][0];
    else
      possible_code = components[1];
    _code = possible_code;
    _code_from_link = YES;
    return YES;
  }
  return NO;
}

#pragma mark - Connection Handling

- (void)connectionStatusChanged:(NSNotification*)notification
{
  InfinitConnectionStatus* connection_status = notification.object;
  if (connection_status.status && self.has_code)
    [self useCodeWithCompletionBlock:nil];
}

@end
