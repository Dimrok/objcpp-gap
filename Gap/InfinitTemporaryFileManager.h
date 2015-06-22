//
//  InfinitTemporaryFileManager.h
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import <Foundation/Foundation.h>

#import "InfinitFileSystemError.h"
#import "InfinitManagedFiles.h"

/** Notification sent when Temporary File Manager has initialized its model.
 */
#define INFINIT_TEMPORARY_FILE_MANAGER_READY @"INFINIT_TEMPORARY_FILE_MANAGER_READY"

/** Notification sent when managed files are deleted.
 userInfo includes a dictionary with the managed files UUID:
 { "managed_files_uuid": <UUID> }
 */
#define INFINIT_MANAGED_FILES_DELETED @"INFINIT_MANAGED_FILES_DELETED"
#define kInfinitManagedFilesId @"managed_files_uuid"

typedef void (^InfinitTemporaryFileManagerCallback)(BOOL success, NSError* error);

@interface InfinitTemporaryFileManager : NSObject

@property (atomic, readonly) BOOL ready;

+ (instancetype)sharedInstance;

/** Fetch managed files with ID.
 @param uuid
  Managed files UUID.
 */
+ (InfinitManagedFiles*)filesWithUUID:(NSString*)uuid;

/** Start the Temporary File Manager. This should be done when the transaction manager is ready.
 */
- (void)start;

/** Create a set of managed files.
 @returns Managed files object.
 */
- (InfinitManagedFiles*)createManagedFiles;

/** Add a list of ALAssets to be managed.
 Files will be created for the associated assets.
 @param list
  List of ALAssets.
 @param managed_files
  The managed files.
 @param block
  Block to be run when done.
 */
- (void)addALAssetsLibraryList:(NSArray*)list
                toManagedFiles:(InfinitManagedFiles*)managed_files
               completionBlock:(InfinitTemporaryFileManagerCallback)block;

/** Add a list of PHAssets to be managed.
 Files will be created for the associated assets.
 @param list
  List of PHAssets.
 @param managed_files
  The managed files.
 @param block
  Block to be run when done.
 */
- (void)addPHAssetsLibraryList:(NSArray*)list
                toManagedFiles:(InfinitManagedFiles*)managed_files
               completionBlock:(InfinitTemporaryFileManagerCallback)block;

/** Add files to be managed without copying or moving the files.
 @param files
  List of NSString paths that you wish to be managed.
 @param managed_files
  The managed files.
 */
- (void)addFiles:(NSArray*)files
  toManagedFiles:(InfinitManagedFiles*)managed_files;

/** Add files to be managed moving the files.
 @param files
  List of NSString paths that you wish to be managed.
 @param managed_files
  The managed files.
 */
- (void)addFilesByMove:(NSArray*)files
        toManagedFiles:(InfinitManagedFiles*)managed_files;

/** Add files to be managed copying the files.
 @param files
  List of NSString paths that you wish to be managed.
 @param managed_files
  The managed files.
 */
- (void)addFilesByCopy:(NSArray*)files
        toManagedFiles:(InfinitManagedFiles*)managed_files;

/** Add transaction IDs for the managed files.
 The files will then automatically be deleted when they're no longer needed and are marked as 
 sending.
 @param transaction_ids
  Array of transaction IDs (as NSNumbers) to track.
 @param managed_files
  The managed files.
 */
- (void)addTransactionIds:(NSArray*)transaction_ids
          forManagedFiles:(InfinitManagedFiles*)managed_files;

/** Mark managed files as sending.
 Marking managed files as sending allows them to be garbage collected when transactions no longer
 need them. Marking the files as sending will also check if the files are needed and if not, will
 clean them up.
 */
- (void)markManagedFilesAsSending:(InfinitManagedFiles*)managed_files;

/** Delete the managed files corresponding to the UUID. 
 This would be required if they managed files are never given a transaction ID to track.
 @param managed_files
  The managed files.
 */
- (void)deleteManagedFiles:(InfinitManagedFiles*)managed_files;

@end
