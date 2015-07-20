//
//  InfinitDataSize.m
//  Gap
//
//  Created by Christopher Crone on 17/01/15.
//
//

#import "InfinitDataSize.h"

#import "InfinitGapLocalizedString.h"

static dispatch_once_t _init_token = 0;
static NSNumberFormatter* _formatter = nil;
static double _kilo = 1.0f;
static double _mega = 1.0f;
static double _giga = 1.0f;
static double _tera = 1.0f;
static double _penta = 1.0f;

@implementation InfinitDataSize

// Do not confuse MB and MiB. Apple use MB, GB, etc for their file and storage sizes.
+ (NSString*)fileSizeStringFrom:(NSNumber*)file_size
{
  dispatch_once(&_init_token, ^
  {
    _formatter = [[NSNumberFormatter alloc] init];
    _formatter.numberStyle = NSNumberFormatterDecimalStyle;
    _formatter.roundingMode = NSNumberFormatterRoundUp;
    _formatter.maximumFractionDigits = 2;
    _kilo = pow(10.0f, 3.0f);
    _mega = pow(10.0f, 6.0f);
    _giga = pow(10.0f, 9.0f);
    _tera = pow(10.0f, 12.0f);
    _penta = pow(10.0f, 15.0f);
  });
  NSString* res = @"<nil>";
  double size = file_size.doubleValue;
  NSString* bytes = GapLocalizedString(@"B", @"bytes");
  if (size < _kilo)
    res = [NSString stringWithFormat:@"%@\u00A0%@", [_formatter stringFromNumber:@(size)], bytes];
  else if (size < _mega)
    res = [NSString stringWithFormat:@"%@\u00A0K%@", [_formatter stringFromNumber:@(size / _kilo)], bytes];
  else if (size < _giga)
    res = [NSString stringWithFormat:@"%@\u00A0M%@", [_formatter stringFromNumber:@(size / _mega)], bytes];
  else if (size < _tera)
    res = [NSString stringWithFormat:@"%@\u00A0G%@", [_formatter stringFromNumber:@(size / _giga)], bytes];
  else if (size < _penta)
    res = [NSString stringWithFormat:@"%@\u00A0T%@", [_formatter stringFromNumber:@(size / _tera)], bytes];
  else
    res = [NSString stringWithFormat:@"%@\u00A0P%@", [_formatter stringFromNumber:@(size / _penta)], bytes];

  return res;
}

@end
