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

/** Total size of managed files.
 @param uuid
  The identifying UUID.
 @return Total size of managed files.
 */
- (NSNumber*)totalSizeOfManagedFiles:(NSString*)uuid;

/** Add a list of Asset Library URLs to be managed.
 The expected URLs are of form: 
  assets-library://asset/asset.JPG?id=1D8E0CAE-0A8E-4420-BC85-5E79814106A2&ext=JPG"
 Files will be created for the associated assets.
 @param list
  List of Assets Library URLs as NSURLs.
 @param uuid
  The identifying UUID.
 @param selector
  The selector to call when the process has been completed.
 @param object
  The object on which to call the selector when done.
 */
- (void)addALAssetsLibraryURLList:(NSArray*)list
                   toManagedFiles:(NSString*)uuid
                  performSelector:(SEL)selector
                         onObject:(id)object;

/** Add a list of PHAssets to be managed.
 @param list
  List of PHAssets.
 @param uuid
  The identifying UUID.
 @param selector
  The selector to call when the process has been completed.
 @param object
  The object on which to call the selector when done.
 */
- (void)addPHAssetsLibraryURLList:(NSArray*)list
                   toManagedFiles:(NSString*)uuid
                  performSelector:(SEL)selector
                         onObject:(id)object;

/** Remove a list of Asset Library URLs from managed files.
 @param list
  List of URLs to be removed as NSURLs.
 @param uuid
  The idetity of the managed files.
 */
- (void)removeALAssetLibraryURLList:(NSArray*)list
                   fromManagedFiles:(NSString*)uuid;

/** Add an NSData object to be managed.
 @param data
  Data with which to build file.
 @param filename
  Name of file to be created (including extension).
 @param uuid
  The identifying UUID.
 @return Path to created file.
 */
- (NSString*)addData:(NSData*)data
        withFilename:(NSString*)filename
      toManagedFiles:(NSString*)uuid;

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

/** Set the transaction IDs for the managed files.
 The files will then automatically be deleted when they're no longer needed.
 @param transaction_ids
  Array of transaction IDs (as NSNumbers) to track.
 @param uuid
  The identifying UUID.
 */
- (void)setTransactionIds:(NSArray*)transaction_ids
          forManagedFiles:(NSString*)uuid;

/** Delete the managed files corresponding to the UUID. 
 This would be required if they managed files are never given a transaction ID to track.
 @param uuid
  The identifying UUID.
 */
- (void)deleteManagedFiles:(NSString*)uuid;

@end
