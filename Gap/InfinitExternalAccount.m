//
//  InfinitExternalAccount.m
//  Gap
//
//  Created by Christopher Crone on 10/06/15.
//
//

#import "InfinitExternalAccount.h"

@interface InfinitExternalAccount ()

@property (nonatomic, readonly) NSString* type_string;

@end

@implementation InfinitExternalAccount

#pragma mark - Init

- (instancetype)initWithType:(InfinitExternalAccountType)type
               andIdentifier:(NSString*)identifier
{
  if (self = [super init])
  {
    if (type == InfinitExternalAccountTypeUnknown)
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

+ (InfinitExternalAccountType)typeFromString:(NSString*)type
{
  if ([type isEqualToString:@"email"])
    return InfinitExternalAccountTypeEmail;
  if ([type isEqualToString:@"facebook"])
    return InfinitExternalAccountTypeFacebook;
  if ([type isEqualToString:@"phone"])
    return InfinitExternalAccountTypePhone;
  return InfinitExternalAccountTypeUnknown;
}

- (NSString*)type_string
{
  switch (self.type)
  {
    case InfinitExternalAccountTypeEmail:
      return @"email";
    case InfinitExternalAccountTypeFacebook:
      return @"facebook";
    case InfinitExternalAccountTypePhone:
      return @"phone";

    default:
      return @"unknown";
  }
}

#pragma mark - NSObject

- (NSString*)description
{
  return [NSString stringWithFormat:@"<ExternalAccount %p: %@ – %@>", self, self.type_string, self.identifier];
}

@end
