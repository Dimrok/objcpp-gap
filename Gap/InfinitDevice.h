//
//  InfinitDevice.h
//  Gap
//
//  Created by Christopher Crone on 09/03/15.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, InfinitDeviceType)
{
  InfinitDeviceTypeAndroid,
  InfinitDeviceTypeiPad,
  InfinitDeviceTypeiPhone,
  InfinitDeviceTypeiPod,
  InfinitDeviceTypeMacDesktop,
  InfinitDeviceTypeMacLaptop,
  InfinitDeviceTypePCLinux,
  InfinitDeviceTypePCWindows,

  InfinitDeviceTypeUnknown,
};

@interface InfinitDevice : NSObject

@property (nonatomic, readonly) NSString* id_;
@property (nonatomic, readonly) BOOL is_self;
@property (nonatomic, readonly) NSString* meta_name;
@property (nonatomic, readwrite) NSString* name; // Locally change own name.
@property (nonatomic, readonly) NSString* model;
@property (nonatomic, readonly) NSString* os;
@property (nonatomic, readonly) InfinitDeviceType type;

+ (instancetype)deviceWithId:(NSString*)id_
                        name:(NSString*)name
                          os:(NSString*)os
                       model:(NSString*)model;

@end
