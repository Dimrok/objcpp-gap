//
//  InfinitFileSystemError.m
//  Gap
//
//  Created by Christopher Crone on 06/04/15.
//
//

#import "InfinitFileSystemError.h"

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
      return NSLocalizedString(@"No data to write", nil);
    case InfinitFileSystemErrorPathDoesntExist:
      return NSLocalizedString(@"Path doesn't exist", nil);
    case InfinitFileSystemErrorNoFreeSpace:
      return NSLocalizedString(@"Not enough freespace", nil);
    case InfinitFileSystemErrorUnableToWrite:
      return NSLocalizedString(@"Unable to write", nil);
  }
}

@end
