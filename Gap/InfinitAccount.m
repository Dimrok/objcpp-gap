//
//  InfinitAccount.m
//  Gap
//
//  Created by Christopher Crone on 10/06/15.
//
//

#import "InfinitAccount.h"

@interface InfinitAccount ()

@property (nonatomic, readonly) NSString* type_string;

@end

@implementation InfinitAccount

#pragma mark - Init

- (instancetype)initWithType:(InfinitAccountType)type
               andIdentifier:(NSString*)identifier
{
  if (self = [super init])
  {
    if (type == InfinitAccountTypeUnknown)
      return nil;
    _type = type;
    _identifier = identifier;
  }
  return self;
}

+ (instancetype)accountOfType:(NSString*)type
               withIdentifier:(NSString*)identifier
{
  return [[self alloc] initWithType:[self typeFromString:type] andIdentifier:identifier];
}

#pragma mark - Helpers

+ (InfinitAccountType)typeFromString:(NSString*)type
{
  if ([type isEqualToString:@"email"])
    return InfinitAccountTypeEmail;
  if ([type isEqualToString:@"facebook"])
    return InfinitAccountTypeFacebook;
  if ([type isEqualToString:@"phone"])
    return InfinitAccountTypePhone;
  return InfinitAccountTypeUnknown;
}

- (NSString*)type_string
{
  switch (self.type)
  {
    case InfinitAccountTypeEmail:
      return @"email";
    case InfinitAccountTypeFacebook:
      return @"facebook";
    case InfinitAccountTypePhone:
      return @"phone";

    default:
      return @"unknown";
  }
}

#pragma mark - NSObject

- (NSString*)description
{
  return [NSString stringWithFormat:@"<Account %p: %@ – %@>", self, self.type_string, self.identifier];
}

@end
