//
//  InfinitAccountsManager.m
//  Gap
//
//  Created by Christopher Crone on 10/06/15.
//
//

#import "InfinitAccountsManager.h"

#import "InfinitStateManager.h"

@interface InfinitAccountsManager ()

@property (atomic, readwrite) NSArray* accounts;

@end

static InfinitAccountsManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitAccountsManager

#pragma mark - Init

- (instancetype)init
{
  NSCAssert(_instance == nil, @"Use sharedInstance.");
  if (self = [super init])
  {
  }
  return self;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[self alloc] init];
  });
  if (!_instance.accounts.count && [InfinitStateManager sharedInstance].logged_in)
  {
    _instance.accounts = [[InfinitStateManager sharedInstance] accounts];
  }
  return _instance;
}

#pragma mark - Public

- (NSArray*)account_list
{
  return [self.accounts copy];
}

- (BOOL)have_facebook
{
  for (InfinitAccount* account in self.accounts)
  {
    if (account.type == InfinitAccountTypeFacebook)
      return YES;
  }
  return NO;
}

#pragma mark - State Manager Callback
- (void)accountsUpdated:(NSArray*)accounts
{
  self.accounts = accounts;
}

@end
