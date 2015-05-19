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
@property (nonatomic, readonly) InfinitDevice* this_device;

+ (instancetype)sharedInstance;

- (InfinitDevice*)deviceWithId:(NSString*)id_;

- (void)setThisDeviceName:(NSString*)name;

- (void)updateDevices;

@end
