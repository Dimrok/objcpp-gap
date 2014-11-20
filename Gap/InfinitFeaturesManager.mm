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

ELLE_LOG_COMPONENT("iOS.FeaturesManager");

static InfinitFeaturesManager* _instance = nil;

@implementation InfinitFeaturesManager
{
@private
  NSDictionary* _features;
}

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _features = [[[InfinitStateManager sharedInstance] features] copy];
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitFeaturesManager alloc] init];
  return _instance;
}

- (NSDictionary*)features
{
  return _features;
}

@end
