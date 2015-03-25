//
//  InfinitFeaturesManager.m
//  Gap
//
//  Created by Christopher Crone on 19/11/14.
//
//

#import "InfinitFeaturesManager.h"
#import "InfinitStateManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.FeaturesManager");

static InfinitFeaturesManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitFeaturesManager
{
@private
  NSDictionary* _features;
}

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _features = [[[InfinitStateManager sharedInstance] features] copy];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel)
                                                 name:INFINIT_CLEAR_MODEL_NOTIFICATION
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
  dispatch_once(&_instance_token, ^{
    _instance = [[InfinitFeaturesManager alloc] init];
  });
  return _instance;
}

#pragma mark - General

- (NSDictionary*)features
{
  return _features;
}

#pragma mark - Clear Model

- (void)clearModel
{
  _instance = nil;
  _instance_token = 0;
}

@end
