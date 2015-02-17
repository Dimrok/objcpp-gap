//
//  InfinitFileSystemErrors.h
//  Gap
//
//  Created by Christopher Crone on 16/02/15.
//
//

#ifndef Gap_InfinitFileSystemErrors_h
#define Gap_InfinitFileSystemErrors_h

/** Domain of file system errors.
 */
#define INFINIT_FILE_SYSTEM_ERROR_DOMAIN @"io.infinit.Gap.FileSystemErrorDomain"

typedef NS_ENUM(NSUInteger, InfinitFileSystemErrors)
{
  InfinitFileSystemErrorNoFreeSpace,
  InfinitFileSystemErrorPathDoesntExist,
  InfinitFileSystemErrorUnableToWrite,
};

#endif
