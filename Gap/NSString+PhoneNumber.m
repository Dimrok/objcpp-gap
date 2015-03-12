//
//  NSString+PhoneNumber.m
//  Gap
//
//  Created by Christopher Crone on 07/03/15.
//
//

#import "NSString+PhoneNumber.h"

@implementation NSString (PhoneNumber)

- (BOOL)isPhoneNumber
{
  NSError* error = nil;
  NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypePhoneNumber
                                                             error:&error];
  if (error)
    return NO;
  NSRange range = NSMakeRange(0, self.length);
  NSArray* matches = [detector matchesInString:self options:0 range:range];
  if (matches.count != 1)
    return NO;
  NSTextCheckingResult* res = matches[0];
  if (res.range.length == self.length)
    return YES;
  return NO;
}


@end
