//
//  InfinitAccountReferral.m
//  Gap
//
//  Created by Chris Crone on 01/10/15.
//
//

#import "InfinitAccountReferral.h"

@implementation InfinitAccountReferral

- (instancetype)initWithIdentifier:(NSString*)identifier
                            method:(InfinitReferralMethod)method
                            status:(InfinitReferralStatus)status
                       hasLoggedIn:(BOOL)has_logged_in
{
  if (self = [super init])
  {
    _identifier = identifier;
    _method = method;
    _status = status;
    _has_logged_in = has_logged_in;
  }
  return self;
}

+ (instancetype)referral:(NSString*)identifier
                  method:(InfinitReferralMethod)method
                  status:(InfinitReferralStatus)status
             hasLoggedIn:(BOOL)has_logged_in
{
  return [[self alloc] initWithIdentifier:identifier
                                   method:method
                                   status:status
                              hasLoggedIn:has_logged_in];
}

@end
