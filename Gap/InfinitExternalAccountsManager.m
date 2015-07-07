//
//  InfinitExternalAccountsManager.m
//  Gap
//
//  Created by Christopher Crone on 10/06/15.
//
//

#import "InfinitExternalAccountsManager.h"

#import "InfinitStateManager.h"

@interface InfinitExternalAccountsManager ()

@property (atomic, readwrite) NSArray* accounts;

@end

static InfinitExternalAccountsManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@implementation InfinitExternalAccountsManager

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
  return _instance;
}

#pragma mark - Public

- (NSArray*)account_list
{
  return [self.accounts copy];
}

- (BOOL)have_facebook
{
  for (InfinitExternalAccount* account in self.accounts)
  {
    if (account.type == InfinitExternalAccountTypeFacebook)
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