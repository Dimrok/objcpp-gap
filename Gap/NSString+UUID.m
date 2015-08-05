//
//  NSString+UUID.m
//  Gap
//
//  Created by Christopher Crone on 27/04/15.
//
//

#import "NSString+UUID.h"

#define INFINIT_UUID_REGEX @"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

static NSRegularExpression* _infinit_uuid_regex = nil;
static dispatch_once_t _infinit_regex_token = 0;

@implementation NSString (infinit_UUID)

- (BOOL)infinit_isUUID
{
  NSUInteger matches =
    [[NSString  _infinit_uuidRegex] numberOfMatchesInString:self
                                                    options:0
                                                      range:NSMakeRange(0, self.length)];
  if (matches == 1)
    return YES;
  return NO;
}

#pragma mark - Helpers

+ (NSRegularExpression*)_infinit_uuidRegex
{
  dispatch_once(&_infinit_regex_token, ^
  {
    _infinit_uuid_regex =
      [NSRegularExpression regularExpressionWithPattern:INFINIT_UUID_REGEX
                                                options:NSRegularExpressionCaseInsensitive
                                                  error:nil];
  });
  return _infinit_uuid_regex;
}

@end
