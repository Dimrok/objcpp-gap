//
//  NSNumber+DataSize.m
//  Gap
//
//  Created by Christopher Crone on 19/08/15.
//
//

#import "NSNumber+DataSize.h"

#import "InfinitGapLocalizedString.h"

static dispatch_once_t _infinit_init_token = 0;
static NSNumberFormatter* _infinit_formatter = nil;
static double _infinit_kilo = 1.0f;
static double _infinit_mega = 1.0f;
static double _infinit_giga = 1.0f;
static double _infinit_tera = 1.0f;
static double _infinit_penta = 1.0f;

static dispatch_queue_t _infinit_queue = nil;

@implementation NSNumber (infinit_DataSize)

- (NSString*)infinit_fileSize
{
  [NSNumber _infinit_initialize];
  __block NSString* res = @"<nil>";
  dispatch_sync(_infinit_queue, ^
  {
    double size = self.doubleValue;
    NSString* bytes = GapLocalizedString(@"B", @"bytes");
    if (size < _infinit_kilo)
    {
      res = [NSString stringWithFormat:@"%@\u00A0%@",
             [_infinit_formatter stringFromNumber:@(size)], bytes];
    }
    else if (size < _infinit_mega)
    {
      res = [NSString stringWithFormat:@"%@\u00A0K%@",
             [_infinit_formatter stringFromNumber:@(size / _infinit_kilo)], bytes];
    }
    else if (size < _infinit_giga)
    {
      res = [NSString stringWithFormat:@"%@\u00A0M%@",
             [_infinit_formatter stringFromNumber:@(size / _infinit_mega)], bytes];
    }
    else if (size < _infinit_tera)
    {
      res = [NSString stringWithFormat:@"%@\u00A0G%@",
             [_infinit_formatter stringFromNumber:@(size / _infinit_giga)], bytes];
    }
    else if (size < _infinit_penta)
    {
      res = [NSString stringWithFormat:@"%@\u00A0T%@",
             [_infinit_formatter stringFromNumber:@(size / _infinit_tera)], bytes];
    }
    else
    {
      res = [NSString stringWithFormat:@"%@\u00A0P%@",
             [_infinit_formatter stringFromNumber:@(size / _infinit_penta)], bytes];
    }
  });
  return res;
}

#pragma mark - Helpers

+ (void)_infinit_initialize
{
  dispatch_once(&_infinit_init_token, ^
  {
    _infinit_formatter = [[NSNumberFormatter alloc] init];
    _infinit_formatter.numberStyle = NSNumberFormatterDecimalStyle;
    _infinit_formatter.roundingMode = NSNumberFormatterRoundUp;
    _infinit_formatter.maximumFractionDigits = 2;
    _infinit_kilo = pow(10.0f, 3.0f);
    _infinit_mega = pow(10.0f, 6.0f);
    _infinit_giga = pow(10.0f, 9.0f);
    _infinit_tera = pow(10.0f, 12.0f);
    _infinit_penta = pow(10.0f, 15.0f);
    _infinit_queue = dispatch_queue_create("io.Infinit.NSNumber(DataSize)", DISPATCH_QUEUE_SERIAL);
  });

}

@end
