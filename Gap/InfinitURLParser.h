//
//  InfinitURLParser.h
//  Gap
//
//  Created by Christopher Crone on 18/05/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitURLParser : NSObject

/** Fetch ghost code from URL.
 @param url
  URL to check for ghost code.
 @return ghost code or nil if one wasn't found.
 */
+ (NSString*)getGhostCodeFromURL:(NSURL*)url;

/** Fetch referral code from URL.
 @param url
  URL to check for referral code.
 @return referral code or nil if one wasn't found.
*/
+ (NSString*)getReferralCodeFromURL:(NSURL*)url;

@end
