//
//  InfinitTemporaryFileManager.m
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import "InfinitTemporaryFileManager.h"

#import "InfinitDirectoryManager.h"
#import "InfinitFileSystemError.h"
#import "InfinitLinkTransactionManager.h"
#import "InfinitManagedFiles.h"
#import "InfinitPeerTransactionManager.h"
#import "InfinitStateManager.h"
#import "InfinitStoredMutableDictionary.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.TemporaryFileManager");

static InfinitTemporaryFileManager* _instance = nil;
static dispatch_once_t _instance_token = 0;
static ALAssetsLibrary* _library = nil;
static dispatch_once_t _library_token = 0;

@interface InfinitTemporaryFileManager ()

@property (atomic, readonly) InfinitStoredMutableDictionary* files_map;
@property (atomic, readonly) InfinitStoredMutableDictionary* transaction_map;

@property (nonatomic, readonly) NSString* managed_root;
@property (nonatomic, readonly) NSString* files_map_path;
@property (nonatomic, readonly) NSString* transaction_map_path;

@property (nonatomic, readonly) uint64_t max_mirror_size;

@end

@implementation InfinitTemporaryFileManager

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _max_mirror_size = [InfinitStateManager sharedInstance].max_mirror_size;
    _managed_root = [InfinitDirectoryManager sharedInstance].temporary_files_directory;
    _files_map_path = [self.managed_root stringByAppendingPathComponent:@"files_map"];
    _transaction_map_path = [self.managed_root stringByAppendingPathComponent:@"transaction_map"];
    [self _fillModel];
    [self _cleanup];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_linkTransactionUpdated:)
                                                 name:INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_peerTransactionUpdated:)
                                                 name:INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearModel) 
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
  }
  return self;
}

- (void)clearModel
{
  _instance_token = 0;
  _instance = nil;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self _cleanOrphans];
  [self.transaction_map finalize];
  [self.files_map finalize];
}

- (void)_fillModel
{
  _files_map = [InfinitStoredMutableDictionary dictionaryWithContentsOfFile:self.files_map_path];
  _transaction_map =
    [InfinitStoredMutableDictionary dictionaryWithContentsOfFile:self.transaction_map_path];
  NSMutableSet* old_install_files = [NSMutableSet set];
  // Replace managed files objects in transaction map with those in files map.
  for (InfinitManagedFiles* managed_files in self.files_map.allValues)
  {
    NSArray* keys = [self.transaction_map allKeysForObject:managed_files];
    if (keys.count > 0)
    {
      for (NSString* key in keys)
        [self.transaction_map setObject:managed_files forKey:key];
    }
    if ([managed_files.root_dir rangeOfString:self.managed_root].location == NSNotFound)
      [old_install_files addObject:managed_files.uuid];
  }
  for (NSString* uuid in old_install_files)
    [self deleteManagedFiles:uuid force:YES];
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_TEMPORARY_FILE_MANAGER_READY
                                                        object:nil];
  });
}

- (void)_cleanOrphans
{
  NSMutableSet* orphans = [NSMutableSet set];
  for (InfinitManagedFiles* managed_files in self.files_map.allValues)
  {
    if ([self.transaction_map allKeysForObject:managed_files].count == 0)
    {
      [orphans addObject:managed_files.uuid];
    }
  }
  for (NSString* uuid in orphans)
  {
    [self deleteManagedFiles:uuid force:YES];
  }
}

- (void)_cleanup
{
  NSString* old_managed_root =
    [NSTemporaryDirectory() stringByAppendingPathComponent:self.managed_root.lastPathComponent];
  // Remove old temporary files root.
  if ([[NSFileManager defaultManager] fileExistsAtPath:old_managed_root isDirectory:NULL])
  {
    [[NSFileManager defaultManager] removeItemAtPath:old_managed_root error:nil];
  }
  NSMutableSet* remove_keys = [NSMutableSet set];
  InfinitLinkTransactionManager* l_manager = [InfinitLinkTransactionManager sharedInstance];
  InfinitPeerTransactionManager* p_manager = [InfinitPeerTransactionManager sharedInstance];
  NSMutableArray* transactions = [NSMutableArray arrayWithArray:l_manager.transactions];
  [transactions addObjectsFromArray:p_manager.transactions];
  for (id key in self.transaction_map.allKeys)
  {
    InfinitManagedFiles* managed_files = [self.transaction_map objectForKey:key];
    // Transactions without meta ids are useless as are ones that we no longer track in our managers
    if (![key isKindOfClass:NSString.class] ||
        !([l_manager transactionWithMetaId:key] || [p_manager transactionWithMetaId:key]))
    {
      [remove_keys addObjectsFromArray:[self.transaction_map allKeysForObject:managed_files]];
      [self deleteManagedFiles:managed_files.uuid force:YES];
    }
    // It's possible during an update that our base path changed. If this happens, the files will
    // no longer be in the same place. Transaction will fail but it happens early so we need to
    // clean up.
    else
    {
      if (![[NSFileManager defaultManager] fileExistsAtPath:managed_files.root_dir isDirectory:NULL])
      {
        [remove_keys addObjectsFromArray:[self.transaction_map allKeysForObject:managed_files]];
        [remove_keys addObject:key];
        [self deleteManagedFiles:managed_files.uuid force:YES];
      }
    }
  }
  for (id key in remove_keys)
  {
    [self.transaction_map removeObjectForKey:key];
  }
  NSError* error = nil;
  NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.managed_root
                                                                          error:&error];
  if (error)
  {
    ELLE_WARN("%s: unable to read root managed files folder", self.description.UTF8String);
    return;
  }
  for (NSString* folder in contents)
  {
    if (![folder isEqualToString:self.files_map_path.lastPathComponent] &&
        ![folder isEqualToString:self.transaction_map_path.lastPathComponent] &&
        ![self.files_map objectForKey:folder])
    {
      NSString* path = [self.managed_root stringByAppendingPathComponent:folder];
      [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
      if (error)
      {
        ELLE_WARN("%s: unable to remove orphan managed files: %s",
                  self.description.UTF8String, folder);
      }
    }
  }
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitTemporaryFileManager alloc] init];
  });
  return _instance;
}

- (ALAssetsLibrary*)_sharedLibrary
{
  dispatch_once(&_library_token, ^
  {
    _library = [[ALAssetsLibrary alloc] init];
  });
  return _library;
}

#pragma mark - Transaction Callback

- (BOOL)_transactionFilesNeededForStatus:(gap_TransactionStatus)status
{
  switch (status)
  {
    case gap_transaction_canceled:
    case gap_transaction_cloud_buffered:
    case gap_transaction_deleted:
    case gap_transaction_failed:
    case gap_transaction_finished:
    case gap_transaction_rejected:
    case gap_transaction_on_other_device:
      return NO;

    default:
      return YES;
  }
}

- (void)_genericTransactionUpdate:(InfinitTransaction*)transaction
{
  if (!transaction.from_device || !transaction.meta_id.length)
    return;
  InfinitManagedFiles* temp = [self.transaction_map objectForKey:transaction.id_];
  if (temp && transaction.meta_id.length)
  {
    [self.transaction_map removeObjectForKey:transaction.id_];
    [self.transaction_map setObject:temp forKey:transaction.meta_id];
  }

  InfinitManagedFiles* managed_files = [self.transaction_map objectForKey:transaction.meta_id];
  if (managed_files == nil)
    return;

  if (managed_files.total_size.unsignedIntegerValue < self.max_mirror_size ||
      ![self _transactionFilesNeededForStatus:transaction.status])
  {
    ELLE_DEBUG("%s: no longer need files for transaction: %s",
               self.description.UTF8String, transaction.meta_id.UTF8String);
    [self.transaction_map removeObjectForKey:transaction.meta_id];
    if ([self.transaction_map allKeysForObject:managed_files].count == 0)
      [self deleteManagedFiles:managed_files.uuid];
  }
}

- (void)_linkTransactionUpdated:(NSNotification*)notification
{
  NSNumber* id_ = notification.userInfo[kInfinitTransactionId];
  InfinitLinkTransaction* transaction =
    [[InfinitLinkTransactionManager sharedInstance] transactionWithId:id_];

  [self _genericTransactionUpdate:transaction];
}

- (void)_peerTransactionUpdated:(NSNotification*)notification
{
  NSNumber* id_ = notification.userInfo[kInfinitTransactionId];
  InfinitPeerTransaction* transaction =
    [[InfinitPeerTransactionManager sharedInstance] transactionWithId:id_];

  [self _genericTransactionUpdate:transaction];
}

#pragma mark - Public

- (NSString*)createManagedFiles
{
  InfinitManagedFiles* managed_files = [[InfinitManagedFiles alloc] init];
  [self.files_map setObject:managed_files forKey:managed_files.uuid];
  managed_files.root_dir = [self.managed_root stringByAppendingPathComponent:managed_files.uuid];
  return managed_files.uuid;
}

- (NSArray*)pathsForManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to fetch files from %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return @[];
  }
  return managed_files.managed_paths.array;
}

- (NSUInteger)fileCountForManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to fetch files from %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return 0;
  }
  return managed_files.managed_paths.count;
}

- (NSNumber*)totalSizeOfManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to get total size, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return nil;
  }
  return managed_files.total_size;
}

- (void)addALAssetsLibraryURLList:(NSArray*)list
                   toManagedFiles:(NSString*)uuid
                  completionBlock:(InfinitTemporaryFileManagerCallback)block
{
  ELLE_TRACE("%s: adding %lu items to %s",
             self.description.UTF8String, list.count, uuid.UTF8String);
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(queue, ^
  {
    __block NSError* child_error = nil;
    InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
    if (managed_files == nil)
    {
      ELLE_ERR("%s: unable to add asset list, %s not in map",
               self.description.UTF8String, uuid.UTF8String);
      return;
    }
    dispatch_semaphore_t test_sema = dispatch_semaphore_create(0);
    dispatch_semaphore_t copy_sema = dispatch_semaphore_create(0);
    __block BOOL asset_nil_bug = NO;

    [[self _sharedLibrary] assetForURL:list[0] resultBlock:^(ALAsset* asset)
    {
      if (asset == nil)
        asset_nil_bug = YES;
      dispatch_semaphore_signal(test_sema);
    } failureBlock:^(NSError *error)
    {
      dispatch_semaphore_signal(test_sema);
    }];
    dispatch_semaphore_wait(test_sema, DISPATCH_TIME_FOREVER);

    if (!asset_nil_bug)
    {
      for (NSURL* url in list)
      {
        [[self _sharedLibrary] assetForURL:url resultBlock:^(ALAsset* asset)
        {
          [self _foundAsset:asset withURL:url forManagedFiles:managed_files withError:&child_error];
          dispatch_semaphore_signal(copy_sema);
        } failureBlock:^(NSError* error)
        {
          ELLE_ERR("%s: unable to create file (%s): %s", self.description.UTF8String,
                   url.absoluteString.UTF8String, error.description.UTF8String);
          dispatch_semaphore_signal(copy_sema);
        }];
      }
    }
    else
    {
      [[self _sharedLibrary] enumerateGroupsWithTypes:ALAssetsGroupAll
                                           usingBlock:^(ALAssetsGroup* group, BOOL* stop)
       {
         [group enumerateAssetsWithOptions:NSEnumerationReverse
                                usingBlock:^(ALAsset* result, NSUInteger index, BOOL* stop)
          {
            NSURL* url = result.defaultRepresentation.url;
            if ([list containsObject:url])
            {
              [self _foundAsset:result withURL:url
                forManagedFiles:managed_files
                      withError:&child_error];
              dispatch_semaphore_signal(copy_sema);
            }
          }];
       } failureBlock:^(NSError* error)
       {
         dispatch_semaphore_signal(copy_sema);
       }];
    }
    for (NSUInteger i = 0; i < list.count; i++)
      dispatch_semaphore_wait(copy_sema, DISPATCH_TIME_FOREVER);
    dispatch_async(dispatch_get_main_queue(), ^
    {
      BOOL success = YES;
      if (child_error)
        success = NO;
      block(success, child_error);
    });
  });
}

- (void)addPHAssetsLibraryURLList:(NSArray*)list
                   toManagedFiles:(NSString*)uuid
                  completionBlock:(InfinitTemporaryFileManagerCallback)block
{
  ELLE_TRACE("%s: adding %lu items to %s",
             self.description.UTF8String, list.count, uuid.UTF8String);
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(queue, ^
  {
    InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
    if (managed_files == nil)
    {
      ELLE_ERR("%s: unable to add asset list, %s not in map",
               self.description.UTF8String, uuid.UTF8String);
      return;
    }
    NSError* child_error = nil;
    for (PHAsset* asset in list)
    {
      [self _addPHAsset:asset toManagedFiles:managed_files withError:&child_error];
      if (child_error)
        break;
    }
    dispatch_async(dispatch_get_main_queue(), ^
    {
      BOOL success = YES;
      if (child_error)
        success = NO;
      block(success, child_error);
    });
  });
}

- (NSString*)addData:(NSData*)data
        withFilename:(NSString*)filename
      toManagedFiles:(NSString*)uuid
               error:(NSError**)error
{
  if (data == nil)
  {
    NSString* filename_ = filename;
    if (filename_ == nil || !filename_.length)
      filename_ = @"<empty filename>";
    ELLE_ERR("%s: unable to write file to %s, data is nil",
             self.description.UTF8String, filename_.UTF8String);
    if (error != NULL)
      *error = [InfinitFileSystemError errorWithCode:InfinitFileSystemErrorNoDataToWrite];
    return nil;
  }
  ELLE_DEBUG("%s: writing %lu to %s",
             self.description.UTF8String, data.length, filename.UTF8String);
  if (data.length > [InfinitDirectoryManager sharedInstance].free_space)
  {
    ELLE_ERR("%s: insufficient freespace: %lu > %lu",
             self.description.UTF8String, data.length,
             [InfinitDirectoryManager sharedInstance].free_space);
    if (error != NULL)
      *error = [InfinitFileSystemError errorWithCode:InfinitFileSystemErrorNoFreeSpace];
    return nil;
  }
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to write file to %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return nil;
  }
  NSString* path = [managed_files.root_dir stringByAppendingPathComponent:filename];
  if (![self _pathExists:managed_files.root_dir])
    [self _createDirectoryAtPath:managed_files.root_dir];
  NSError* operation_error = nil;
  if (![data writeToFile:path options:NSDataWritingAtomic error:&operation_error])
  {
    ELLE_ERR("%s: unable to write file %s: %s", self.description.UTF8String,
             path.UTF8String, operation_error.description.UTF8String);
    if (error != NULL)
    {
      *error = [InfinitFileSystemError errorWithCode:InfinitFileSystemErrorUnableToWrite
                                              reason:operation_error.description];
    }
    return nil;
  }
  [managed_files.managed_paths addObject:path];
  managed_files.total_size = [self _folderSize:managed_files.root_dir];
  return path;
}

- (void)addFiles:(NSArray*)files
  toManagedFiles:(NSString*)uuid
            copy:(BOOL)copy
{
  ELLE_TRACE("%s: adding files to managed files (%s): %s",
             self.description.UTF8String, uuid.UTF8String, files.description.UTF8String);
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to add files to %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  if (copy)
  {
    [managed_files.managed_paths addObjectsFromArray:[self _copyFiles:files
                                                               toPath:managed_files.root_dir]];
  }
  else
  {
    [managed_files.managed_paths addObjectsFromArray:[self _moveFiles:files
                                                               toPath:managed_files.root_dir]];
  }
  managed_files.total_size = [self _folderSize:managed_files.root_dir];
}

- (void)setTransactionIds:(NSArray*)transaction_ids
          forManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to set transaction_id, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  for (NSNumber* id_ in transaction_ids)
  {
    [self.transaction_map setObject:managed_files forKey:id_];
  }
}

- (void)deleteManagedFiles:(NSString*)uuid
{
  [self deleteManagedFiles:uuid force:NO];
}

- (void)deleteManagedFiles:(NSString*)uuid
                     force:(BOOL)force
{
  ELLE_DEBUG("%s: removing managed files with UUID: %s",
             self.description.UTF8String, uuid.UTF8String);
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil && !force)
  {
    ELLE_ERR("%s: unable to delete managed files, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  [self.files_map removeObjectForKey:uuid];
  if (managed_files.root_dir.length)
    [self _deleteFiles:@[managed_files.root_dir]];
}

#pragma mark - Helpers

- (BOOL)_pathExists:(NSString*)path
{
  return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (BOOL)_createDirectoryAtPath:(NSString*)path
{
  NSError* error;
  BOOL success =
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:@{NSURLIsExcludedFromBackupKey: @YES}
                                                    error:&error];
  if (!success)
  {
    ELLE_ERR("%s: unable to create managed files directory (%s): %s",
             self.description.UTF8String, path.UTF8String, error.description.UTF8String);
  }
  return success;
}

- (NSArray*)_copyFiles:(NSArray*)files
                toPath:(NSString*)path
{
  if (![self _pathExists:path])
    [self _createDirectoryAtPath:path];
  NSError* error;
  NSString* copy_path;
  BOOL success;
  NSMutableArray* res = [NSMutableArray array];
  for (NSString* file in files)
  {
    copy_path = [path stringByAppendingPathComponent:file.lastPathComponent];
    success = [[NSFileManager defaultManager] copyItemAtPath:file toPath:copy_path error:&error];
    if (success)
    {
      [res addObject:copy_path];
    }
    else
    {
      ELLE_ERR("%s: unable to copy %s to %s: %s", self.description.UTF8String,
               file.UTF8String, path.UTF8String, error.description.UTF8String);
    }
  }
  return res;
}

- (NSArray*)_moveFiles:(NSArray*)files
                toPath:(NSString*)path
{
  if (![self _pathExists:path])
    [self _createDirectoryAtPath:path];
  NSError* error;
  NSString* move_path;
  BOOL success;
  NSMutableArray* res = [NSMutableArray array];
  for (NSString* file in files)
  {
    move_path = [path stringByAppendingPathComponent:file.lastPathComponent];
    success = [[NSFileManager defaultManager] moveItemAtPath:file toPath:move_path error:&error];
    if (success)
    {
      [res addObject:move_path];
    }
    else
    {
      ELLE_ERR("%s: unable to move %s to %s: %s", self.description.UTF8String,
               file.UTF8String, path.UTF8String, error.description.UTF8String);
    }
  }
  return res;
}

- (void)_deleteFiles:(NSArray*)files
{
  NSError* error;
  BOOL success;
  for (NSString* file in files)
  {
    if (![self _pathExists:file])
      continue;
    success = [[NSFileManager defaultManager] removeItemAtPath:file error:&error];
    if (!success)
    {
      ELLE_WARN("%s: unable to remove %s: %s", self.description.UTF8String,
                file.UTF8String, error.description.UTF8String);
    }
  }
}

- (NSNumber*)_folderSize:(NSString*)path
{
  if (![self _pathExists:path])
    return @0;
  NSURL* folder_url = [NSURL fileURLWithPath:path];
  NSNumber* temp_size = @0;
  NSUInteger res = 0;
  NSDirectoryEnumerator* dir_enum =
    [[NSFileManager defaultManager] enumeratorAtURL:folder_url
                         includingPropertiesForKeys:@[NSURLTotalFileAllocatedSizeKey,
                                                      NSURLIsDirectoryKey]
                                            options:NSDirectoryEnumerationSkipsHiddenFiles
                                       errorHandler:nil];
  for (NSURL* file_url in dir_enum)
  {
    [file_url getResourceValue:&temp_size forKey:NSURLFileSizeKey error:NULL];
    res += temp_size.unsignedIntegerValue;
  }
  return [NSNumber numberWithUnsignedInteger:res];
}

- (void)_foundAsset:(ALAsset*)asset
            withURL:(NSURL*)url
    forManagedFiles:(InfinitManagedFiles*)managed_files
          withError:(NSError**)error
{
  NSUInteger asset_size = (NSUInteger)asset.defaultRepresentation.size;
  Byte* buffer = (Byte*)malloc(asset_size);
  NSUInteger buffered = [asset.defaultRepresentation getBytes:buffer
                                                   fromOffset:0
                                                       length:asset_size
                                                        error:nil];
  NSData* data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
  NSString* filename = asset.defaultRepresentation.filename;
  NSString* path =
    [[InfinitTemporaryFileManager sharedInstance] addData:data
                                             withFilename:filename
                                           toManagedFiles:managed_files.uuid
                                                    error:error];
  if (*error || !path.length)
  {
    ELLE_ERR("%s: unable to write data to managed files (%s): %s",
             self.description.UTF8String, managed_files.uuid.UTF8String,
             (*error).description.UTF8String);
    return;
  }
  [managed_files.asset_map setObject:path forKey:url.absoluteString];
}

- (void)_addPHAsset:(PHAsset*)asset
     toManagedFiles:(InfinitManagedFiles*)managed_files
          withError:(NSError**)error
{
  PHImageRequestOptions* options = [[PHImageRequestOptions alloc] init];
  options.networkAccessAllowed = YES;
  options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
  options.version = PHImageRequestOptionsVersionCurrent;
  options.synchronous = YES;
  [[PHImageManager defaultManager] requestImageDataForAsset:asset
                                                    options:options
                                              resultHandler:^(NSData* imageData,
                                                              NSString* dataUTI,
                                                              UIImageOrientation orientation,
                                                              NSDictionary* info)
  {
    NSURL* url = info[@"PHImageFileURLKey"];
    NSString* filename = url.lastPathComponent;
    if ([filename isEqualToString:@"FullSizeRender.jpg"])
    {
      NSArray* components = url.pathComponents;
      for (NSString* component in components)
      {
        if ([component containsString:@"IMG"])
        {
          NSString* new_filename = [component stringByAppendingString:@".JPG"];
          ELLE_DEBUG("%s: renaming file: %s -> %s",
                     self.description.UTF8String, filename, new_filename);
          filename = new_filename;
          break;
        }
      }
    }
    if (!imageData.length)
    {
      NSString* reason = @"unknown";
      if (info[PHImageCancelledKey])
        reason = @"fetch cancelled";
      if (info[PHImageErrorKey])
        reason = [info[PHImageErrorKey] description];
      ELLE_WARN("%s: got empty file from PHImageManager for %s, reason: %s",
                self.description.UTF8String, filename.UTF8String, reason.UTF8String);
    }
    else if (info[PHImageErrorKey])
    {
      ELLE_WARN("%s: error fetching PHAsset %s, reason: %s",
                self.description.UTF8String, filename.UTF8String,
                [info[PHImageErrorKey] description].UTF8String);
    }
    NSString* path =
      [[InfinitTemporaryFileManager sharedInstance] addData:imageData
                                               withFilename:filename
                                             toManagedFiles:managed_files.uuid
                                                      error:error];
    if (*error || !path.length)
    {
      ELLE_ERR("%s: unable to write data to managed files (%s): %s",
               self.description.UTF8String, managed_files.uuid.UTF8String,
               (*error).description.UTF8String);
      return;
    }
    [managed_files.asset_map setObject:path forKey:url.absoluteString];
  }];
}

@end
