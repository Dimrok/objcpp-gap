//
//  InfinitAccountUsageQuota.m
//  Gap
//
//  Created by Christopher Crone on 18/08/15.
//
//

#import "InfinitAccountUsageQuota.h"

@implementation InfinitAccountUsageQuota

#pragma mark - Init

- (instancetype)_initWithUsage:(uint64_t)usage
                         quota:(uint64_t)quota
                      quotaSet:(BOOL)quota_set
{
  if (self = [super init])
  {
    _usage = @(usage);
    if (quota_set)
    {
      _quota = @(quota);
      _proportion_used = @(self.usage.doubleValue / self.quota.doubleValue);
      _proportion_remaining = @(1.0f - (self.usage.doubleValue / self.quota.doubleValue));
      _remaining = @(quota - usage);
    }
  }
  return self;
}

+ (instancetype)accountUsage:(uint64_t)usage
                       quota:(uint64_t)quota;
{
  return [[self alloc] _initWithUsage:usage quota:quota quotaSet:YES];
}

+ (instancetype)accountUsage:(uint64_t)usage
{
  return [[self alloc] _initWithUsage:usage quota:0 quotaSet:NO];
}

#pragma mark - NSObject

- (NSString*)description
{
  return [NSString stringWithFormat:@"Quota(usage: %@ / %@)",
          self.usage, self.quota ? self.quota : @"unlimited"];
}

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:self.class])
    return NO;
  InfinitAccountUsageQuota* other = (InfinitAccountUsageQuota*)object;
  if ([other.quota isEqualToNumber:self.quota] && [other.usage isEqualToNumber:self.usage])
    return YES;
  return NO;
}

@end
