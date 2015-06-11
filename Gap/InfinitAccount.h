//
//  InfinitAccount.h
//  Gap
//
//  Created by Christopher Crone on 10/06/15.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, InfinitAccountType)
{
  InfinitAccountTypeEmail,
  InfinitAccountTypeFacebook,
  InfinitAccountTypePhone,

  InfinitAccountTypeUnknown,
};

@interface InfinitAccount : NSObject

@property (nonatomic, readonly) NSString* identifier;
@property (nonatomic, readonly) InfinitAccountType type;

+ (instancetype)accountOfType:(NSString*)type
               withIdentifier:(NSString*)identifier;

@end
