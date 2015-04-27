//
//  NSString+PhoneNumber.m
//  Gap
//
//  Created by Christopher Crone on 07/03/15.
//
//

#import "NSString+PhoneNumber.h"

static NSDataDetector* _infinit_number_detector = nil;

@implementation NSString (infinit_PhoneNumber)

- (BOOL)infinit_isPhoneNumber
{
  if (_infinit_number_detector == nil)
  {
    _infinit_number_detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypePhoneNumber
                                                               error:nil];
  }
  NSRange range = NSMakeRange(0, self.length);
  NSArray* matches = [_infinit_number_detector matchesInString:self options:0 range:range];
  if (matches.count != 1)
    return NO;
  NSTextCheckingResult* res = matches[0];
  if (res.range.length == self.length)
    return YES;
  return NO;
}


@end
