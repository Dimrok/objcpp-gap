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
  if (![url.scheme isEqualToString:kInfinitURLScheme])
    return nil;
  ELLE_TRACE("get ghost code from URL: %s", url.description.UTF8String);
  NSString* resource_specifier = [url.resourceSpecifier substringFromIndex:2];
  NSArray* components = [resource_specifier componentsSeparatedByString:@"/"];
  if ([components[0] isEqual:kInfinitURLInvite])
  {
    NSString* possible_code = nil;
    if ([components[1] rangeOfString:@"?"].location != NSNotFound)
      possible_code = [components[1] componentsSeparatedByString:@"?"][0];
    else
      possible_code = components[1];
    return possible_code;
  }
  return nil;
}

@end
