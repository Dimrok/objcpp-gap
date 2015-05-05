//
//  InfinitFileSystemError.m
//  Gap
//
//  Created by Christopher Crone on 06/04/15.
//
//

#import "InfinitFileSystemError.h"

#import "InfinitGapLocalizedString.h"

@implementation InfinitFileSystemError

+ (instancetype)errorWithCode:(InfinitFileSystemErrorCode)code
{
  return [InfinitFileSystemError errorWithCode:code reason:nil];
}

+ (instancetype)errorWithCode:(InfinitFileSystemErrorCode)code
                       reason:(NSString*)reason
{
  NSString* message = [InfinitFileSystemError _stringFromCode:code];
  if (!reason.length)
    message = [message stringByAppendingString:[NSString stringWithFormat:@": %@", reason]];

  return [super errorWithDomain:INFINIT_FILE_SYSTEM_ERROR_DOMAIN
                           code:code 
                       userInfo:@{NSLocalizedDescriptionKey: message}];
}

+ (NSString*)_stringFromCode:(InfinitFileSystemErrorCode)code
{
  switch (code)
  {
    case InfinitFileSystemErrorNoDataToWrite:
      return GapLocalizedString(@"No data to write", nil);
    case InfinitFileSystemErrorPathDoesntExist:
      return GapLocalizedString(@"Path doesn't exist", nil);
    case InfinitFileSystemErrorNoFreeSpace:
      return GapLocalizedString(@"Not enough free space", nil);
    case InfinitFileSystemErrorUnableToWrite:
      return GapLocalizedString(@"Unable to write", nil);
  }
}

@end
