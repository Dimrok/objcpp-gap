//
//  InfinitFeaturesManager.h
//  Gap
//
//  Created by Christopher Crone on 19/11/14.
//
//

#import <Foundation/Foundation.h>

@interface InfinitFeaturesManager : NSObject

+ (instancetype)sharedInstance;

- (NSDictionary*)features;

@end
