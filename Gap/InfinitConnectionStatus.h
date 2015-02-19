//
//  InfinitConnectionStatus.h
//  Gap
//
//  Created by Christopher Crone on 17/02/15.
//
//

#import <Foundation/Foundation.h>

@interface InfinitConnectionStatus : NSObject

@property (nonatomic, readonly) BOOL status;
@property (nonatomic, readonly) BOOL still_trying;
@property (nonatomic, readonly) NSString* last_error;

+ (instancetype)connectionStatus:(BOOL)status
                     stillTrying:(BOOL)still_trying 
                       lastError:(NSString*)last_error;

@end
