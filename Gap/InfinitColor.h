//
//  InfinitColor.h
//  Gap
//
//  Created by Christopher Crone on 08/01/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
# import <UIKit/UIKit.h>
# define INFINIT_COLOR UIColor
#else
# import <AppKit/AppKit.h>
# define INFINIT_COLOR NSColor
#endif

typedef NS_ENUM(NSUInteger, InfinitPaletteColors)
{
  InfinitPaletteColorBurntSienna, // 242, 94,  90
  InfinitPaletteColorShamRock,    // 43,  190, 189
  InfinitPaletteColorChicago,     // 100, 100, 90
  InfinitPaletteColorLightGray,   // 243, 243, 243
  InfinitPaletteColorSendBlack,   // 46,  46,  46
  InfinitPaletteColorLoginBlack,  // 91,  99,  106
};

@interface InfinitColor : NSObject

+ (INFINIT_COLOR*)colorWithGray:(NSUInteger)gray;
+ (INFINIT_COLOR*)colorWithGray:(NSUInteger)gray alpha:(CGFloat)alpha;

+ (INFINIT_COLOR*)colorWithRed:(NSUInteger)red green:(NSUInteger)green blue:(NSUInteger)blue;
+ (INFINIT_COLOR*)colorWithRed:(NSUInteger)red green:(NSUInteger)green blue:(NSUInteger)blue
                   alpha:(CGFloat)alpha;

+ (INFINIT_COLOR*)colorFromPalette:(InfinitPaletteColors)color;
+ (INFINIT_COLOR*)colorFromPalette:(InfinitPaletteColors)color
                       alpha:(CGFloat)alpha;

@end
