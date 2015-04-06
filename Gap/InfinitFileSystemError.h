//
//  InfinitFileSystemError.h
//  Gap
//
//  Created by Christopher Crone on 06/04/15.
//
//

#import <Foundation/Foundation.h>

#define INFINIT_FILE_SYSTEM_ERROR_DOMAIN @"io.infinit.Gap.FileSystemErrorDomain"

typedef NS_ENUM(NSUInteger, InfinitFileSystemErrorCode)
{
  InfinitFileSystemErrorNoFreeSpace,
  InfinitFileSystemErrorPathDoesntExist,
  InfinitFileSystemErrorNoDataToWrite,
  InfinitFileSystemErrorUnableToWrite,
};

@interface InfinitFileSystemError : NSError

+ (instancetype)errorWithCode:(InfinitFileSystemErrorCode)code;

+ (instancetype)errorWithCode:(InfinitFileSystemErrorCode)code
                       reason:(NSString*)reason;

@end
