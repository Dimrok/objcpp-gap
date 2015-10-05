//
//  InfinitAccountReferralActions.h
//  Gap
//
//  Created by Chris Crone on 30/09/15.
//
//

#import <Foundation/Foundation.h>

#import "InfinitAccountReferral.h"

@interface InfinitAccountReferralActions : NSObject

@property (nonatomic, readonly) BOOL has_avatar;
@property (nonatomic, readonly) NSUInteger facebook_posts;
@property (nonatomic, readonly) NSUInteger twitter_posts;
@property (nonatomic, readonly) NSArray<InfinitAccountReferral*>* referrals;

+ (instancetype)referralActionsHasAvatar:(BOOL)has_avatar
                           facebookPosts:(NSUInteger)facebook_posts
                            twitterPosts:(NSUInteger)twitter_posts
                               referrals:(NSArray<InfinitAccountReferral*>*)referrals;

@end
