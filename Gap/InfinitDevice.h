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
  InfinitDeviceTypeiPhone,
  InfinitDeviceTypeMacLaptop,
  InfinitDeviceTypePCLinux,
  InfinitDeviceTypePCWindows,

  InfinitDeviceTypeUnknown,
};

@interface InfinitDevice : NSObject

@property (nonatomic, readonly) NSString* id_;
@property (nonatomic, readonly) BOOL is_self;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* os_string;
@property (nonatomic, readonly) InfinitDeviceType type;

- (instancetype)initWithId:(NSString*)id_
                      name:(NSString*)name
                        os:(NSString*)os;

@end
