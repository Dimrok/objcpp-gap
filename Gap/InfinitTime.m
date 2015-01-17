//
//  InfinitTime.m
//  Infinit
//
//  Created by Christopher Crone on 17/01/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import "InfinitTime.h"

@implementation InfinitTime

+ (NSString*)relativeDateOf:(NSTimeInterval)timestamp
               longerFormat:(BOOL)longer
{
  NSDate* transaction_date = [NSDate dateWithTimeIntervalSince1970:timestamp];
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
  formatter.locale = [NSLocale currentLocale];
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
    formatter.timeStyle = NSDateFormatterShortStyle;
    res = [formatter stringFromDate:transaction_date];
  }
  else if ([InfinitTime isInLastWeek:transaction_date])
  {
    if (longer)
      formatter.dateFormat = @"EEEE";
    else
      formatter.dateFormat = @"EEE";
    res = [[formatter stringFromDate:transaction_date] capitalizedString];
  }
  else
  {
    if (longer)
      formatter.dateFormat = @"d MMMM";
    else
      formatter.dateFormat = @"d MMM";
    res = [[formatter stringFromDate:transaction_date] capitalizedString];;
  }
  return res;
}

+ (BOOL)isToday:(NSDate*)date
{
  NSDate* today = [NSDate date];
  NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
  NSCalendar* gregorian =
    [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
  NSDateComponents* today_components = [gregorian components:components
                                                    fromDate:today];
  NSDateComponents* date_components = [gregorian components:components
                                                   fromDate:date];
  if ([date_components isEqual:today_components])
    return YES;
  else
    return NO;
}

+ (BOOL)isInLastWeek:(NSDate*)date
{
  NSDate* now = [NSDate date];
  NSCalendar* gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
  NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
  NSDateComponents* today_components = [gregorian components:components
                                                    fromDate:now];
  NSDate* today = [gregorian dateFromComponents:today_components];
  NSDateComponents* minus_six_days = [[NSDateComponents alloc] init];
  minus_six_days.day = -6;
  NSDate* six_days_ago = [gregorian dateByAddingComponents:minus_six_days
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

@end
