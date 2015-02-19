//
//  InfinitConnectionStatus.m
//  Gap
//
//  Created by Christopher Crone on 17/02/15.
//
//

#import "InfinitConnectionStatus.h"

@implementation InfinitConnectionStatus

#pragma mark - Init

- (id)initWithStatus:(BOOL)status
         stillTrying:(BOOL)still_trying
           lastError:(NSString*)last_error
{
  if (self = [super init])
  {
    _status = status;
    _still_trying = still_trying;
    _last_error = last_error;
  }
  return self;
}

+ (instancetype)connectionStatus:(BOOL)status
                     stillTrying:(BOOL)still_trying
                       lastError:(NSString*)last_error
{
  return [[InfinitConnectionStatus alloc] initWithStatus:status
                                             stillTrying:still_trying 
                                               lastError:last_error];
}

#pragma mark - Description

- (NSString*)description
{
  NSMutableString* res = [[NSMutableString alloc] init];
  [res appendFormat:@"%@connected", self.status ? @"" : @"dis"];
  if (self.status)
    return res;
  [res appendFormat:@", %@retrying", self.still_trying ? @"" : @"not "];
  if (self.last_error.length > 0)
    [res appendFormat:@", error: %@", self.last_error];
  return res;
}

@end
