//
//  NSString+PhoneNumber.m
//  Gap
//
//  Created by Christopher Crone on 07/03/15.
//
//

#import "NSString+PhoneNumber.h"

static NSDataDetector* _infinit_number_detector = nil;
static dispatch_once_t _infinit_number_detector_token = 0;

@implementation NSString (infinit_PhoneNumber)

- (BOOL)infinit_isPhoneNumber
{
  NSRange range = NSMakeRange(0, self.length);
  NSArray* matches = [[NSString infinit_NumberDetector] matchesInString:self options:0 range:range];
  if (matches.count != 1)
    return NO;
  NSTextCheckingResult* res = matches[0];
  if (res.range.length == self.length)
    return YES;
  return NO;
}


#pragma mark - Helpers

+ (NSDataDetector*)infinit_NumberDetector
{
  dispatch_once(&_infinit_number_detector_token, ^
  {
    _infinit_number_detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypePhoneNumber
                                                               error:nil];
  });
  return _infinit_number_detector;
}

@end
