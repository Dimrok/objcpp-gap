//
//  InfinitDataSize.m
//  Gap
//
//  Created by Christopher Crone on 17/01/15.
//
//

#import "InfinitDataSize.h"

@implementation InfinitDataSize

// Do not confuse MB and MiB. Apple use MB, GB, etc for their file and storage sizes.
+ (NSString*)fileSizeStringFrom:(NSNumber*)file_size
{
  NSString* res;
  double size = file_size.doubleValue;
  NSString* bytes = NSLocalizedString(@"B", @"bytes");
  if (size < pow(10.0, 3.0))
    res = [NSString stringWithFormat:@"%.0f %@", size, bytes];
  else if (size < pow(10.0, 6.0))
    res = [NSString stringWithFormat:@"%.0f K%@", size / pow(10.0, 3.0), bytes];
  else if (size < pow(10.0, 9.0))
    res = [NSString stringWithFormat:@"%.1f M%@", size / pow(10.0, 6.0), bytes];
  else if (size < pow(10.0, 12.0))
    res = [NSString stringWithFormat:@"%.2f G%@", size / pow(10.0, 9.0), bytes];
  else
    res = [NSString stringWithFormat:@"%.3f T%@", size / pow(10.0, 12.0), bytes];

  return res;
}

@end
