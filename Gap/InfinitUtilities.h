//
//  InfinitUtilities.h
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import <Foundation/Foundation.h>

@interface InfinitUtilities : NSObject

/** Check that string is a valid email address.
 @param string 
  String to be tested.
 @return YES if valid, NO if not.
 */
+ (BOOL)stringIsEmail:(NSString*)string;

@end
