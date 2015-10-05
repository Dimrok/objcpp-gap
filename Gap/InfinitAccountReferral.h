//
//  InfinitAccountReferral.h
//  Gap
//
//  Created by Chris Crone on 01/10/15.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, InfinitReferralStatus)
{
  InfinitReferralStatus_Pending = 0,
  InfinitReferralStatus_Complete,
  InfinitReferralStatus_Blocked,
};

typedef NS_ENUM(NSUInteger, InfinitReferralMethod)
{
  InfinitReferralMethod_Ghost = 0,
  InfinitReferralMethod_Plain,
  InfinitReferralMethod_Link,
};

@interface InfinitAccountReferral : NSObject

@property (nonatomic, readonly) BOOL has_logged_in;
@property (nonatomic, readonly) NSString* identifier;
@property (nonatomic, readonly) InfinitReferralMethod method;
@property (nonatomic, readonly) InfinitReferralStatus status;

+ (instancetype)referral:(NSString*)identifier
                  method:(InfinitReferralMethod)method
                  status:(InfinitReferralStatus)status
             hasLoggedIn:(BOOL)has_logged_in;

@end
