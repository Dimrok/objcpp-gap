//
//  InfinitTime.m
//  Infinit
//
//  Created by Christopher Crone on 17/01/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import "InfinitTime.h"

static NSCalendar* _calendar = nil;

static NSDateFormatter* _today_formatter = nil;
static NSDateFormatter* _week_formatter_short = nil;
static NSDateFormatter* _week_formatter_long = nil;
static NSDateFormatter* _other_formatter_short = nil;
static NSDateFormatter* _other_formatter_long = nil;

@implementation InfinitTime

+ (NSString*)relativeDateOf:(NSTimeInterval)timestamp
               longerFormat:(BOOL)longer
{
  NSDate* transaction_date = [NSDate dateWithTimeIntervalSince1970:timestamp];
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  NSDateFormatter* formatter = nil;
  NSString* res;
  if (timestamp < now && timestamp > (now - 3 * 60.0)) // 3 min ago
  {
    res = NSLocalizedString(@"Now", nil);
  }
  else if (timestamp < now && timestamp > (now - 60 * 60.0)) // an hour ago
  {
    NSTimeInterval time_ago = floor((now - timestamp) / 60.0);
    res = [NSString stringWithFormat:@"%.0f %@", time_ago, NSLocalizedString(@"min ago", nil)];
  }
  else if ([InfinitTime isToday:transaction_date])
  {
    if (_today_formatter == nil)
    {
      _today_formatter = [[NSDateFormatter alloc] init];
      _today_formatter.locale = [NSLocale currentLocale];
      _today_formatter.timeStyle = NSDateFormatterShortStyle;
    }
    res = [_today_formatter stringFromDate:transaction_date];
  }
  else if ([InfinitTime isInLastWeek:transaction_date])
  {
    if (longer)
    {
      if (_week_formatter_long == nil)
      {
        _week_formatter_long = [[NSDateFormatter alloc] init];
        _week_formatter_long.locale = [NSLocale currentLocale];
        _week_formatter_long.dateFormat = @"EEEE";
      }
      formatter = _week_formatter_long;
    }
    else
    {
      if (_week_formatter_short == nil)
      {
        _week_formatter_short = [[NSDateFormatter alloc] init];
        _week_formatter_short.locale = [NSLocale currentLocale];
        _week_formatter_short.dateFormat = @"EEE";
      }
      formatter = _week_formatter_short;
    }
    res = [[formatter stringFromDate:transaction_date] capitalizedString];
  }
  else
  {
    if (longer)
    {
      if (_other_formatter_long == nil)
      {
        _other_formatter_long = [[NSDateFormatter alloc] init];
        _other_formatter_long.locale = [NSLocale currentLocale];
        _other_formatter_long.dateFormat = @"d MMMM";
      }
      formatter = _other_formatter_long;
    }
    else
    {
      if (_other_formatter_short == nil)
      {
        _other_formatter_short = [[NSDateFormatter alloc] init];
        _other_formatter_short.locale = [NSLocale currentLocale];
        _other_formatter_short.dateFormat = @"d MMM";
      }
      formatter = _other_formatter_short;
    }
    res = [[formatter stringFromDate:transaction_date] capitalizedString];;
  }
  return res;
}

+ (BOOL)isToday:(NSDate*)date
{
  NSDate* today = [NSDate date];
  NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
  if (_calendar == nil)
    _calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
  NSDateComponents* today_components = [_calendar components:components
                                                      fromDate:today];
  NSDateComponents* date_components = [_calendar components:components
                                                    fromDate:date];
  if ([date_components isEqual:today_components])
    return YES;
  else
    return NO;
}

+ (BOOL)isInLastWeek:(NSDate*)date
{
  NSDate* now = [NSDate date];
  if (_calendar == nil)
    _calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
  NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
  NSDateComponents* today_components = [_calendar components:components
                                                      fromDate:now];
  NSDate* today = [_calendar dateFromComponents:today_components];
  NSDateComponents* minus_six_days = [[NSDateComponents alloc] init];
  minus_six_days.day = -6;
  NSDate* six_days_ago = [_calendar dateByAddingComponents:minus_six_days
                                                    toDate:today
                                                   options:0];
  if ([[date earlierDate:now] isEqualToDate:date] &&
      [[date laterDate:six_days_ago] isEqualToDate:date])
  {
    return YES;
  }
  return NO;
}

+ (NSString*)timeRemainingFrom:(NSTimeInterval)seconds_left
{
  NSString* res;

  if (seconds_left < 10)
    res = NSLocalizedString(@"less than 10 s", @"less than 10 s");
  else if (seconds_left < 60)
    res = NSLocalizedString(@"less than 1 min", @"less than 1 min");
  else if (seconds_left < 90)
    res = NSLocalizedString(@"about 1 min", @"about 1 min");
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
    res = NSLocalizedString(@"more than two days", @"more than two days");
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

@end
