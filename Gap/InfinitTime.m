//
//  InfinitTime.m
//  Infinit
//
//  Created by Christopher Crone on 17/01/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import "InfinitTime.h"

#import "InfinitGapLocalizedString.h"

static NSCalendar* _calendar = nil;
static dispatch_once_t _calendar_token = 0;

static NSDateFormatter* _today_formatter = nil;
static NSDateFormatter* _week_formatter_short = nil;
static NSDateFormatter* _week_formatter_long = nil;
static NSDateFormatter* _other_formatter_short = nil;
static NSDateFormatter* _other_formatter_long = nil;
static dispatch_once_t _formatter_token = 0;

static dispatch_queue_t _relative_queue = nil;

@implementation InfinitTime

+ (NSString*)relativeDateOf:(NSTimeInterval)timestamp
               longerFormat:(BOOL)longer
{
  [self _createFormatters];
  __block NSString* res;
  dispatch_sync(_relative_queue, ^
  {
    NSDate* transaction_date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDateFormatter* formatter = nil;
    if (timestamp < now && timestamp > (now - 3 * 60.0)) // 3 min ago
    {
      res = GapLocalizedString(@"Now", nil);
    }
    else if (timestamp < now && timestamp > (now - 60 * 60.0)) // an hour ago
    {
      NSTimeInterval time_ago = floor((now - timestamp) / 60.0);
      res = [NSString stringWithFormat:@"%.0f %@", time_ago, GapLocalizedString(@"min ago", nil)];
    }
    else if ([InfinitTime _isToday:transaction_date])
    {
      res = [_today_formatter stringFromDate:transaction_date];
    }
    else if ([InfinitTime _isInLastWeek:transaction_date])
    {
      if (longer)
        formatter = _week_formatter_long;
      else
        formatter = _week_formatter_short;
      res = [[formatter stringFromDate:transaction_date] capitalizedString];
    }
    else
    {
      if (longer)
        formatter = _other_formatter_long;
      else
        formatter = _other_formatter_short;
      res = [[formatter stringFromDate:transaction_date] capitalizedString];;
    }
  });
  return res;
}

+ (NSString*)timeRemainingFrom:(NSTimeInterval)seconds_left
{
  NSString* res;
  if (seconds_left < 10)
    res = GapLocalizedString(@"less than 10 s", @"less than 10 s");
  else if (seconds_left < 60)
    res = GapLocalizedString(@"less than 1 min", @"less than 1 min");
  else if (seconds_left < 90)
    res = GapLocalizedString(@"about 1 min", @"about 1 min");
  else if (seconds_left < 3600)
    res = [NSString stringWithFormat:@"%.0f min", seconds_left / 60];
  else if (seconds_left < 86400)
    res = [NSString stringWithFormat:@"%.0f h", seconds_left / 3600];
  else if (seconds_left < 172800)
  {
    double days = seconds_left / 86400;
    double hours = days - floor(days);
    days = floor(days);
    res = [NSString stringWithFormat:@"%.0f d %.1f h", days, hours];
  }
  else
  {
    res = GapLocalizedString(@"more than two days", @"more than two days");
  }
  return res;
}

+ (NSString*)stringFromDuration:(NSTimeInterval)duration
{
  NSInteger ti = (NSInteger)duration;
  NSInteger seconds = ti % 60;
  NSInteger minutes = (ti / 60) % 60;
  NSInteger hours = (ti / 3600);
  if (ti >= 60 * 60)
    return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
  else
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

#pragma mark - Helpers

+ (void)_createFormatters
{
  dispatch_once(&_formatter_token, ^
  {
    _relative_queue = dispatch_queue_create("io.Infinit.RelativeTime", DISPATCH_QUEUE_SERIAL);

    _today_formatter = [[NSDateFormatter alloc] init];
    _today_formatter.locale = [NSLocale currentLocale];
    _today_formatter.timeStyle = NSDateFormatterShortStyle;

    _week_formatter_long = [[NSDateFormatter alloc] init];
    _week_formatter_long.locale = [NSLocale currentLocale];
    _week_formatter_long.dateFormat = @"EEEE";

    _week_formatter_short = [[NSDateFormatter alloc] init];
    _week_formatter_short.locale = [NSLocale currentLocale];
    _week_formatter_short.dateFormat = @"EEE";

    _other_formatter_long = [[NSDateFormatter alloc] init];
    _other_formatter_long.locale = [NSLocale currentLocale];
    _other_formatter_long.dateFormat = @"d MMMM";

    _other_formatter_short = [[NSDateFormatter alloc] init];
    _other_formatter_short.locale = [NSLocale currentLocale];
    _other_formatter_short.dateFormat = @"d MMM";
  });
}

+ (NSCalendar*)calendar
{
  dispatch_once(&_calendar_token, ^
  {
    _calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
  });
  return _calendar;
}

+ (BOOL)_isToday:(NSDate*)date
{
  NSDate* today = [NSDate date];
  NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
  NSDateComponents* today_components = [[self calendar] components:components
                                                          fromDate:today];
  NSDateComponents* date_components = [[self calendar] components:components
                                                         fromDate:date];
  if ([date_components isEqual:today_components])
    return YES;
  else
    return NO;
}

+ (BOOL)_isInLastWeek:(NSDate*)date
{
  NSDate* now = [NSDate date];
  NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
  NSDateComponents* today_components = [[self calendar] components:components
                                                          fromDate:now];
  NSDate* today = [[self calendar] dateFromComponents:today_components];
  NSDateComponents* minus_six_days = [[NSDateComponents alloc] init];
  minus_six_days.day = -6;
  NSDate* six_days_ago = [[self calendar] dateByAddingComponents:minus_six_days
                                                          toDate:today
                                                         options:0];
  if ([[date earlierDate:now] isEqualToDate:date] &&
      [[date laterDate:six_days_ago] isEqualToDate:date])
  {
    return YES;
  }
  return NO;
}

@end
