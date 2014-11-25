//
//  InfinitTemporaryFileManager.h
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import <Foundation/Foundation.h>

@interface InfinitTemporaryFileManager : NSObject

+ (instancetype)sharedInstance;

/** Create a set of managed files.
 @returns UUID used to identify the managed files.
 */
- (NSString*)createManagedFiles;

/** Get paths for the managed files.
 @param uuid
  The identifying UUID.
 @return Array of NSStrings with the managed path for each file.
 */
- (NSArray*)pathsForManagedFiles:(NSString*)uuid;

/** Add files to be managed.
 @param files
  List of NSString paths that you wish to be managed.
 @param uuid
  The identifying UUID.
 @param copy
  Copy these files to a temporary location, otherwise they will be moved. 
  This is useful in the case of images from the gallery.
 */
- (void)addFiles:(NSArray*)files
  toManagedFiles:(NSString*)uuid
            copy:(BOOL)copy;

/** Remove files that are currently being managed. This will delete the files.
 @param files
   List of NSString paths that you wish to remove.
 @param uuid
   The identifying UUID.
 */
- (void)removeFiles:(NSArray*)files
   fromManagedFiles:(NSString*)uuid;

/** Set a transaction ID for the managed files.
 They will then automatically be deleted when they're no longer needed.
 @param transaction_id
  Transaction ID to track.
 @param uuid
  The identifying UUID.
 */
- (void)setTransactionId:(NSNumber*)transaction_id
         forManagedFiles:(NSString*)uuid;

/** Delete the managed files corresponding to the UUID. 
 This would be required if they managed files are never given a transaction ID to track.
 @param uuid
  The identifying UUID.
 */
- (void)deleteManagedFiles:(NSString*)uuid;

@end
