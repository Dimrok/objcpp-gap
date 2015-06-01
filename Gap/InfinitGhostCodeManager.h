//
//  InfinitGhostCodeManager.h
//  Gap
//
//  Created by Christopher Crone on 19/05/15.
//
//

#import <Foundation/Foundation.h>

typedef void(^InfinitGhostCodeUsedBlock)(NSString* code, BOOL success, NSString* reason);

@interface InfinitGhostCodeManager : NSObject

@property (nonatomic, readonly) BOOL code_set;

+ (instancetype)sharedInstance;

/** Set ghost code.
 Passes the ghost code to State to manage. The callback will be called when the code is actually
 used.
 @param code
  Ghost code to pass.
 @param was_link
  If the code was received via a link (i.e.: Not manually entered).
 @param completion_block
  Block to run on use of the ghost code. Can be nil.
 */
- (void)setCode:(NSString*)code
        wasLink:(BOOL)was_link
completionBlock:(InfinitGhostCodeUsedBlock)completion_block;

#pragma mark - State Manager Callback
- (void)ghostCodeUsed:(NSString*)code
              success:(BOOL)success
               reason:(NSString*)reason;

@end
