//
//  InfinitDeviceManager.h
//  Gap
//
//  Created by Christopher Crone on 09/03/15.
//
//

#import <Foundation/Foundation.h>

#import "InfinitDevice.h"

@interface InfinitDeviceManager : NSObject

@property (nonatomic, readonly) NSArray* all_devices;
@property (nonatomic, readonly) NSArray* other_devices;

+ (instancetype)sharedInstance;

- (InfinitDevice*)deviceWithId:(NSString*)id_;

- (void)updateDevices;

@end
