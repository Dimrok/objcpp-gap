//
//  InfinitURLParser.m
//  Gap
//
//  Created by Christopher Crone on 18/05/15.
//
//

#import "InfinitURLParser.h"

#import "InfinitConstants.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.URLParser");

@implementation InfinitURLParser

+ (NSString*)getGhostCodeFromURL:(NSURL*)url
{
  ELLE_TRACE("get ghost code from URL: %s", url.description.UTF8String);
  return [self codeFromURL:url withSpecifier:kInfinitURLInvite];
}

+ (NSString*)getReferralCodeFromURL:(NSURL*)url
{
  ELLE_TRACE("get referral code from URL: %s", url.description.UTF8String);
  NSString* possible_code = [self codeFromURL:url withSpecifier:kInfinitURLReferral];
  if (possible_code.length == 16)
    return possible_code;
  return nil;
}

+ (NSString*)codeFromURL:(NSURL*)url 
           withSpecifier:(NSString*)specifier
{
  if (![url.scheme isEqualToString:kInfinitURLScheme])
    return nil;
  NSString* resource_specifier = [url.resourceSpecifier substringFromIndex:2];
  NSArray* components = [resource_specifier componentsSeparatedByString:@"/"];
  if ([components[0] isEqual:specifier])
  {
    NSString* possible_code = nil;
    if ([components[1] rangeOfString:@"?"].location != NSNotFound)
      possible_code = [components[1] componentsSeparatedByString:@"?"][0];
    else
      possible_code = components[1];
    if (!possible_code.length)
      return nil;
    return possible_code;
  }
  return nil;
}

@end
