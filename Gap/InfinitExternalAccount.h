//
//  InfinitAccount.h
//  Gap
//
//  Created by Christopher Crone on 10/06/15.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, InfinitExternalAccountType)
{
  InfinitExternalAccountTypeEmail,
  InfinitExternalAccountTypeFacebook,
  InfinitExternalAccountTypePhone,

  InfinitExternalAccountTypeUnknown,
};

@interface InfinitExternalAccount : NSObject

@property (nonatomic, readonly) NSString* identifier;
@property (nonatomic, readonly) InfinitExternalAccountType type;

+ (instancetype)accountOfType:(NSString*)type
               withIdentifier:(NSString*)identifier;

@end
