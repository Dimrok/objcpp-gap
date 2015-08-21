//
//  InfinitConstants.h
//  Infinit
//
//  Created by Christopher Crone on 03/04/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#ifndef Infinit_InfinitConstants_h
# define Infinit_InfinitConstants_h

# if TARGET_OS_IPHONE
/**************************
 * iOS Specific constants *
 **************************/

/// Adjust.io token.
#  define kInfinitAdjustToken @"4uuen7zlcxak"

/// App Store ID.
#  define kInfinitAppStoreId @"955849852"

/// Application group name.
#  define kInfinitAppGroupName @"group.io.infinit.InfinitMobile"

/// Forgot password URL.
#  define kInfinitForgotPasswordURL @"https://infinit.io/forgot_password?utm_source=app&utm_medium=ios&utm_campaign=forgot_password"

/// Photos gallery name.
#  define kInfinitAlbumName @"Infinit"

/// Ratings URLs.
#  define kInfinitStoreRatingLink @"https://itunes.apple.com/app/apple-store/idAPP_ID"

/// Web profile URL.
#  define kInfinitWebProfileURL @"https://infinit.io/account?utm_source=app&utm_medium=ios&utm_campaign=web_profile"

/// Help URL.
#  define kInfinitHelpURL @"http://help.infinit.io/knowledgebase?utm_source=app&utm_medium=ios"

/// Invite URL.
#  define kInfinitReferalInviteURL @"https://infinit.io/account/referral?utm_source=app&utm_medium=ios&utm_campaign=invite"

/// Upgrade plan URL.
#  define kInfinitUpgradePlanURL @"https://infinit.io/account?utm_source=app&utm_medium=ios&utm_campaign=upgrade_plan"

# else
/**************************
 * Mac Specific constants *
 **************************/

/// Forgot password URL.
#  define kInfinitForgotPasswordURL @"https://infinit.io/forgot_password?utm_source=app&utm_medium=mac&utm_campaign=forgot_password"

/// Web profile URL.
#  define kInfinitWebProfileURL @"https://infinit.io/account?utm_source=app&utm_medium=mac&utm_campaign=web_profile"

/// Account for quota URL.
#  define kInfinitWebProfileQuotaURL @"https://infinit.io/account?utm_source=app&utm_medium=mac&utm_campaign=quota"

/// Upgrade plan URL.
#  define kInfinitUpgradePlanURL @"https://infinit.io/account?utm_source=app&utm_medium=mac&utm_campaign=upgrade_plan"

/// Referal URL.
#  define kInfinitReferalMoreStorageURL @"https://infinit.io/account/referral?utm_source=app&utm_medium=mac&utm_campaign=get_more_storage"

/// Invite URL.
#  define kInfinitReferalInviteURL @"https://infinit.io/account/referral?utm_source=app&utm_medium=mac&utm_campaign=invite"

/// Help URL.
#  define kInfinitHelpURL @"http://help.infinit.io/knowledgebase?utm_source=app&utm_medium=mac"

# endif
/**************************
 *    Shared constants    *
 **************************/

/// URL Scheme.
# define kInfinitURLScheme @"infinit"

/// URL Invite.
# define kInfinitURLInvite @"invitation"

/// Facebook read permissions.
# define kInfinitFacebookReadPermissions @[@"public_profile", @"email", @"user_friends"]

#endif
