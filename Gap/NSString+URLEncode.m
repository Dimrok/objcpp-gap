//
//  NSString+URLEncode.m
//  Gap
//
//  Created by Chris Crone on 24/09/15.
//
//

#import "NSString+URLEncode.h"

@implementation NSString (infinit_URLEncode)

- (NSString*)infinit_URLEncoded
{
  return [self stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

@end
