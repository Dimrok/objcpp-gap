//
//  InfinitColor.m
//  Infinit
//
//  Created by Christopher Crone on 08/01/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import "InfinitColor.h"

@implementation InfinitColor

+ (INFINIT_COLOR*)colorWithGray:(NSUInteger)gray
{
  return [InfinitColor colorWithGray:gray alpha:1.0];
}

+ (INFINIT_COLOR*)colorWithGray:(NSUInteger)gray alpha:(CGFloat)alpha
{
  return [InfinitColor colorWithRed:gray green:gray blue:gray alpha:alpha];
}

+ (INFINIT_COLOR*)colorWithRed:(NSUInteger)red green:(NSUInteger)green blue:(NSUInteger)blue
{
  return [InfinitColor colorWithRed:red green:green blue:blue alpha:1.0];
}

+ (INFINIT_COLOR*)colorWithRed:(NSUInteger)red green:(NSUInteger)green blue:(NSUInteger)blue
                         alpha:(CGFloat)alpha
{
#if TARGET_OS_IPHONE
  return [UIColor colorWithRed:(red/255.0f) green:(green/255.0f) blue:(blue/255.0f) alpha:alpha];
#else
  return [NSColor colorWithDeviceRed:(red/255.0f) green:(green/255.0f) blue:(blue/255.0f)
                               alpha:alpha];
#endif
}

+ (INFINIT_COLOR*)colorFromPalette:(InfinitPaletteColors)color
{
  return [InfinitColor colorFromPalette:color alpha:1.0];
}

+ (INFINIT_COLOR*)colorFromPalette:(InfinitPaletteColors)color
                             alpha:(CGFloat)alpha
{
  switch (color)
  {
    case InfinitPaletteColorBurntSienna:
      return [InfinitColor colorWithRed:242 green:94 blue:90 alpha:alpha];
    case InfinitPaletteColorShamRock:
      return [InfinitColor colorWithRed:43 green:190 blue:189 alpha:alpha];
    case InfinitPaletteColorChicago:
      return [InfinitColor colorWithRed:100 green:100 blue:90 alpha:alpha];
    case InfinitPaletteColorLightGray:
      return [InfinitColor colorWithGray:243 alpha:alpha];
    case InfinitPaletteColorSendBlack:
      return [InfinitColor colorWithGray:46 alpha:alpha];

    default:
      return [InfinitColor colorWithRed:0 green:0 blue:0 alpha:alpha];
  }
}

@end
