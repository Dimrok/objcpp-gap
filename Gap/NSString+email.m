//
//  NSString+email.m
//  Gap
//
//  Created by Christopher Crone on 15/01/15.
//
//

#import "NSString+email.h"

static NSPredicate* _infinit_email_predicate = nil;

@implementation NSString (infinit_email)

- (BOOL)infinit_isEmail
{
  if (self.length == 0)
    return NO;
  if (_infinit_email_predicate == nil)
  {
    NSString* regex_str =
      @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
      @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
      @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
      @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
      @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
      @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
      @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
    _infinit_email_predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", regex_str];
  }
  return [_infinit_email_predicate evaluateWithObject:self];
}

@end
