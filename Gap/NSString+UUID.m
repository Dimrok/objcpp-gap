//
//  NSString+UUID.m
//  Gap
//
//  Created by Christopher Crone on 27/04/15.
//
//

#import "NSString+UUID.h"

#define INFINIT_UUID_REGEX @"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

static NSRegularExpression* _infinit_regex = nil;

@implementation NSString (infinit_UUID)

- (BOOL)infinit_isUUID
{
  if (_infinit_regex == nil)
  {
    _infinit_regex =
      [NSRegularExpression regularExpressionWithPattern:INFINIT_UUID_REGEX
                                                options:NSRegularExpressionCaseInsensitive
                                                  error:nil];
  }
  NSUInteger matches =
    [_infinit_regex numberOfMatchesInString:self options:0 range:NSMakeRange(0, self.length)];
  if (matches == 1)
    return YES;
  return NO;
}

@end
