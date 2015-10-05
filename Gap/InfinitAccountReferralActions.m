//
//  InfinitAccountReferralActions.m
//  Gap
//
//  Created by Chris Crone on 30/09/15.
//
//

#import "InfinitAccountReferralActions.h"

@implementation InfinitAccountReferralActions

- (instancetype)initWithHasAvatar:(BOOL)has_avatar
                    facebookPosts:(NSUInteger)facebook_posts
                     twitterPosts:(NSUInteger)twitter_posts
                        referrals:(NSArray<InfinitAccountReferral*>*)referrals
{
  if (self = [super init])
  {
    _has_avatar = has_avatar;
    _facebook_posts = facebook_posts;
    _twitter_posts = twitter_posts;
    _referrals = referrals;
  }
  return self;
}

+ (instancetype)referralActionsHasAvatar:(BOOL)has_avatar
                           facebookPosts:(NSUInteger)facebook_posts
                            twitterPosts:(NSUInteger)twitter_posts
                               referrals:(NSArray<InfinitAccountReferral*>*)referrals
{
  return [[self alloc] initWithHasAvatar:has_avatar
                           facebookPosts:facebook_posts
                            twitterPosts:twitter_posts 
                               referrals:referrals];
}

@end
