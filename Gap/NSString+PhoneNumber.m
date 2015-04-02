//
//  NSString+PhoneNumber.m
//  Gap
//
//  Created by Christopher Crone on 07/03/15.
//
//

#import "NSString+PhoneNumber.h"

static NSDataDetector* _number_detector = nil;

@implementation NSString (PhoneNumber)

- (BOOL)isPhoneNumber
{
  if (_number_detector == nil)
  {
    _number_detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypePhoneNumber
                                                       error:nil];
  }
  NSRange range = NSMakeRange(0, self.length);
  NSArray* matches = [_number_detector matchesInString:self options:0 range:range];
  if (matches.count != 1)
    return NO;
  NSTextCheckingResult* res = matches[0];
  if (res.range.length == self.length)
    return YES;
  return NO;
}


@end
