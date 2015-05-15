//
//  InfinitCodeManager.h
//  Infinit
//
//  Created by Christopher Crone on 29/04/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^InfinitCodeUsedBlock)(BOOL success);

@interface InfinitCodeManager : NSObject

@property (nonatomic, readonly) BOOL has_code;

+ (instancetype)sharedInstance;

/** Set the code manually.
 Ensure that the code is valid before doing this.
 */
- (void)setManualCode:(NSString*)code;

/** Set the code from application argument.
 */
- (void)setArgumentCode:(NSString*)code;

/** Call when code manager should use code.
 */
- (void)useCodeWithCompletionBlock:(InfinitCodeUsedBlock)completion_block;

/** Check a URL for a code and store it if there is one.
 @param url
  URL to check
 @returns YES if there was a code, NO if there wasn't.
 */
- (BOOL)getCodeFromURL:(NSURL*)url;

@end
