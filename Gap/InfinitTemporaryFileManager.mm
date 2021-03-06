//
//  InfinitTemporaryFileManager.m
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import "InfinitTemporaryFileManager.h"

#import "InfinitDirectoryManager.h"
#import "InfinitLinkTransactionManager.h"
#import "InfinitManagedFiles.h"
#import "InfinitPeerTransactionManager.h"
#import "InfinitStateManager.h"
#import "InfinitStoredMutableDictionary.h"
#import "NSNumber+DataSize.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.TemporaryFileManager");

static InfinitTemporaryFileManager* _instance = nil;
static dispatch_once_t _instance_token = 0;

@interface InfinitTemporaryFileManager ()

@property (atomic, readonly) InfinitStoredMutableDictionary* files_map;
@property (atomic, readonly) InfinitStoredMutableDictionary* transaction_map;

@property (nonatomic, readonly) NSString* managed_root;
@property (nonatomic, readonly) NSString* files_map_path;
@property (nonatomic, readonly) NSString* transaction_map_path;

@end

@implementation InfinitTemporaryFileManager

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _ready = NO;
    _managed_root = [InfinitDirectoryManager sharedInstance].temporary_files_directory;
    _files_map_path = [self.managed_root stringByAppendingPathComponent:@"files_map"];
    _transaction_map_path = [self.managed_root stringByAppendingPathComponent:@"transaction_map"];
  }
  return self;
}

- (void)start
{
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
  _ready = YES;
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_TEMPORARY_FILE_MANAGER_READY
                                                        object:nil];
  });
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
  {
    ELLE_WARN("%s: removing old files: %s", self.description.UTF8String, uuid.UTF8String);
    [self deleteManagedFiles:uuid force:YES];
  }
}

- (void)_cleanOrphans
{
  NSMutableSet* orphans = [NSMutableSet set];
  for (InfinitManagedFiles* managed_files in self.files_map.allValues)
  {
    if ([self.transaction_map allKeysForObject:managed_files].count == 0)
      [orphans addObject:managed_files.uuid];
  }
  for (NSString* uuid in orphans)
  {
    ELLE_WARN("%s: deleting orphan file: %s", self.description.UTF8String, uuid.UTF8String);
    [self deleteManagedFiles:uuid force:YES];
  }
}

- (void)_cleanup
{
  NSString* old_managed_root =
    [NSTemporaryDirectory() stringByAppendingPathComponent:self.managed_root.lastPathComponent];
  // Remove old temporary files root.
  if ([[NSFileManager defaultManager] fileExistsAtPath:old_managed_root isDirectory:NULL])
    [[NSFileManager defaultManager] removeItemAtPath:old_managed_root error:nil];
  NSMutableSet* remove_keys = [NSMutableSet set];
  InfinitLinkTransactionManager* l_manager = [InfinitLinkTransactionManager sharedInstance];
  InfinitPeerTransactionManager* p_manager = [InfinitPeerTransactionManager sharedInstance];
  NSMutableArray* transactions = [NSMutableArray arrayWithArray:l_manager.transactions];
  [transactions addObjectsFromArray:p_manager.transactions];
  for (id key in self.transaction_map.allKeys)
  {
    InfinitManagedFiles* managed_files = [self.transaction_map objectForKey:key];
    // Transactions without meta ids are useless.
    if (![key isKindOfClass:NSString.class])
    {
      ELLE_WARN("%s: removing files for transaction without meta ID: %s",
                self.description.UTF8String, managed_files.uuid.UTF8String);
      [remove_keys addObjectsFromArray:[self.transaction_map allKeysForObject:managed_files]];
      [self deleteManagedFiles:managed_files.uuid force:YES];
    }
    // Transactions which aren't in either of the managers are useless too.
    else if ([l_manager transactionWithMetaId:key] == nil &&
             [p_manager transactionWithMetaId:key] == nil)
    {
      ELLE_WARN("%s: removing files with no corresponding transaction in manager: %s",
                self.description.UTF8String, managed_files.uuid.UTF8String);
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
        ELLE_WARN("%s: removing files because of base path change: %s",
                  self.description.UTF8String, managed_files.uuid.UTF8String);
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
      ELLE_WARN("%s: removing orphan: %s", self.description.UTF8String, folder.UTF8String);
      [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
      if (error)
      {
        ELLE_WARN("%s: unable to remove orphan managed files: %s",
                  self.description.UTF8String, folder.UTF8String);
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

#pragma mark - Transaction Callback

- (BOOL)_transactionFilesNeededForStatus:(gap_TransactionStatus)status
{
  switch (status)
  {
    case gap_transaction_canceled:
    case gap_transaction_cloud_buffered:
    case gap_transaction_deleted:
    case gap_transaction_failed:
    case gap_transaction_ghost_uploaded:
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
  InfinitManagedFiles* managed_files = [self.transaction_map objectForKey:transaction.id_];
  if (managed_files)
  {
    ELLE_TRACE("%s: set transaction id (%s) for managed files (%s)", self.description.UTF8String,
               transaction.meta_id.UTF8String, managed_files.uuid.UTF8String);
    [self.transaction_map removeObjectForKey:transaction.id_];
    [self.transaction_map setObject:managed_files forKey:transaction.meta_id];
  }
  else
  {
    managed_files = [self.transaction_map objectForKey:transaction.meta_id];
  }

  if (managed_files == nil)
    return;

  if (![self _transactionFilesNeededForStatus:transaction.status])
  {
    ELLE_LOG("%s: no longer need files for transaction: %s",
             self.description.UTF8String, transaction.meta_id.UTF8String);
    [self.transaction_map removeObjectForKey:transaction.meta_id];
    if (managed_files.sending && [self.transaction_map allKeysForObject:managed_files].count == 0)
      [self deleteManagedFiles:managed_files];
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

+ (InfinitManagedFiles*)filesWithUUID:(NSString*)uuid
{
  return [[InfinitTemporaryFileManager sharedInstance].files_map objectForKey:uuid];
}

- (InfinitManagedFiles*)createManagedFiles
{
  InfinitManagedFiles* managed_files = [[InfinitManagedFiles alloc] init];
  [self.files_map setObject:managed_files forKey:managed_files.uuid];
  managed_files.root_dir = [self.managed_root stringByAppendingPathComponent:managed_files.uuid];
  return managed_files;
}

- (void)addALAssetsLibraryList:(NSArray*)list_
                toManagedFiles:(InfinitManagedFiles*)managed_files
               completionBlock:(InfinitTemporaryFileManagerCallback)block
{
  
  if (!list_.count)
    return;
  ELLE_TRACE("%s: adding %lu items to %s",
             self.description.UTF8String, list_.count, managed_files.uuid.UTF8String);
  if (![self.files_map objectForKey:managed_files.uuid])
  {
    ELLE_ERR("%s: unable to add asset list, %s not in map",
             self.description.UTF8String, managed_files.uuid.UTF8String);
    return;
  }
  managed_files.copied = YES;NSMutableArray* list = [NSMutableArray array];
  for (ALAsset* asset in list_)
  {
    NSURL* identifier = [asset valueForProperty:ALAssetPropertyAssetURL];
    if ([managed_files.asset_map objectForKey:identifier] ||
        [managed_files.assets_copying containsObject:identifier])
      continue;
    [list addObject:asset];
    [managed_files.assets_copying addObject:identifier];
  }
  managed_files.copying = YES;
  __block NSError* child_error = nil;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
  {
    for (ALAsset* asset in list)
    {
      [self _foundAsset:asset
                withURL:[asset valueForProperty:ALAssetPropertyAssetURL]
        forManagedFiles:managed_files
              withError:&child_error];
    }
    if (child_error)
      managed_files.done_copying_block = nil;
    dispatch_async(dispatch_get_main_queue(), ^
    {
      for (ALAsset* asset in list_)
        [managed_files.assets_copying removeObject:[asset valueForProperty:ALAssetPropertyAssetURL]];
      managed_files.copying = NO;
      BOOL success = YES;
      if (child_error)
        success = NO;
      block(success, child_error);
    });
  });
}

- (void)addPHAssetsLibraryList:(NSArray*)list_
                toManagedFiles:(InfinitManagedFiles*)managed_files
               completionBlock:(InfinitTemporaryFileManagerCallback)block
{
  if (!list_.count)
    return;
  ELLE_TRACE("%s: adding %lu items to %s",
             self.description.UTF8String, list_.count, managed_files.uuid.UTF8String);
  if (![self.files_map objectForKey:managed_files.uuid])
  {
    ELLE_ERR("%s: unable to add asset list, %s not in map",
             self.description.UTF8String, managed_files.uuid.UTF8String);
    return;
  }
  managed_files.copied = YES;
  NSMutableArray* list = [NSMutableArray array];
  for (PHAsset* asset in list_)
  {
    if ([managed_files.asset_map objectForKey:asset.localIdentifier] ||
        [managed_files.assets_copying containsObject:asset.localIdentifier])
      continue;
    [list addObject:asset];
    [managed_files.assets_copying addObject:asset.localIdentifier];
  }
  managed_files.copying = YES;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
  {
    NSError* child_error = nil;
    for (PHAsset* asset in list)
    {
      [self _addPHAsset:asset toManagedFiles:managed_files withError:&child_error];
      if (child_error)
      {
        ELLE_TRACE("%s: got child error, breaking", self.description.UTF8String)
        managed_files.done_copying_block = nil;
        break;
      }
    }
    dispatch_async(dispatch_get_main_queue(), ^
    {
      for (PHAsset* asset in list)
        [managed_files.assets_copying removeObject:asset.localIdentifier];
      managed_files.copying = NO;
      BOOL success = child_error ? NO : YES;
      block(success, child_error);
    });
  });
}

- (NSString*)addData:(NSData*)data
        withFilename:(NSString*)filename
        creationDate:(NSDate*)creation_date
    modificationDate:(NSDate*)modification_date
      toManagedFiles:(InfinitManagedFiles*)managed_files
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
  ELLE_DEBUG("%s: writing %s to %s", self.description.UTF8String,
             @(data.length).infinit_fileSize.UTF8String, filename.UTF8String);
  uint64_t free_space = [InfinitDirectoryManager sharedInstance].free_space;
  if (data.length > free_space)
  {
    ELLE_ERR("%s: insufficient free space: %s > %s", self.description.UTF8String,
             @(data.length).infinit_fileSize.UTF8String, @(free_space).infinit_fileSize.UTF8String);
    if (error != NULL)
      *error = [InfinitFileSystemError errorWithCode:InfinitFileSystemErrorNoFreeSpace];
    return nil;
  }
  if (![self.files_map objectForKey:managed_files.uuid])
  {
    ELLE_ERR("%s: unable to write file to %s, not in map",
             self.description.UTF8String, managed_files.uuid.UTF8String);
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

  NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
  if (creation_date)
    [attributes setObject:creation_date forKey:NSFileCreationDate];
  if (modification_date)
    [attributes setObject:modification_date forKey:NSFileModificationDate];
  if (attributes)
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:path error:nil];

  return path;
}

- (void)addFiles:(NSArray*)files
  toManagedFiles:(InfinitManagedFiles*)managed_files
{
  [self _addFiles:files toManagedFiles:managed_files copy:NO move:NO];
}

- (void)addFilesByMove:(NSArray*)files
        toManagedFiles:(InfinitManagedFiles*)managed_files
{
  [self _addFiles:files toManagedFiles:managed_files copy:NO move:YES];
}

- (void)addFilesByCopy:(NSArray*)files
        toManagedFiles:(InfinitManagedFiles*)managed_files
{
  [self _addFiles:files toManagedFiles:managed_files copy:YES move:NO];
}

- (NSArray*)_addFiles:(NSArray*)files
       toManagedFiles:(InfinitManagedFiles*)managed_files
                 copy:(BOOL)copy
                 move:(BOOL)move
{
  NSCAssert(!(copy && move), @"Select either copy or move.");
  ELLE_TRACE("%s: adding files to managed files (%s): %s", self.description.UTF8String,
             managed_files.uuid.UTF8String, files.description.UTF8String);
  NSArray* res = nil;
  if (![self.files_map objectForKey:managed_files.uuid])
  {
    ELLE_ERR("%s: unable to add files to %s, not in map",
             self.description.UTF8String, managed_files.uuid.UTF8String);
    return res;
  }
  // We only want to handle the copy flag here if it's not being handled upstream by, for example,
  // a group asset copy.
  BOOL handle_copy_flag = NO;
  if (!managed_files.copying)
  {
    handle_copy_flag = YES;
    managed_files.copying = copy;
  }
  managed_files.copied = (copy || move);
  if (copy)
  {
    res = [self _copyFiles:files toPath:managed_files.root_dir];
    [managed_files.managed_paths addObjectsFromArray:res];
  }
  else if (move)
  {
    res = [self _moveFiles:files toPath:managed_files.root_dir];
    [managed_files.managed_paths addObjectsFromArray:res];
  }
  else
  {
    [managed_files.managed_paths addObjectsFromArray:files];
  }
  managed_files.total_size = [self _folderSize:managed_files.root_dir];
  if (handle_copy_flag)
    managed_files.copying = NO;
  return res;
}

- (void)addTransactionIds:(NSArray*)transaction_ids
          forManagedFiles:(InfinitManagedFiles*)managed_files
{
  if (![self.files_map objectForKey:managed_files.uuid])
  {
    ELLE_ERR("%s: unable to set transaction_id, %s not in map",
             self.description.UTF8String, managed_files.uuid.UTF8String);
    return;
  }
  for (NSNumber* id_ in transaction_ids)
  {
    [self.transaction_map setObject:managed_files forKey:id_];
  }
}

- (void)markManagedFilesAsSending:(InfinitManagedFiles*)managed_files
{
  if (![self.files_map objectForKey:managed_files.uuid])
  {
    ELLE_ERR("%s: unable to mark files as sending, %s not in map",
             self.description.UTF8String, managed_files.uuid.UTF8String);
    return;
  }
  managed_files.sending = YES;
  if ([self.transaction_map allKeysForObject:managed_files].count == 0)
    [self deleteManagedFiles:managed_files];
}

- (void)deleteManagedFiles:(InfinitManagedFiles*)managed_files
{
  [self deleteManagedFiles:managed_files.uuid force:NO];
}

- (void)deleteManagedFiles:(NSString*)uuid
                     force:(BOOL)force
{
  if (uuid == nil)
    return;
  dispatch_async(dispatch_get_main_queue(), ^
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_MANAGED_FILES_DELETED
                                                        object:nil
                                                      userInfo:@{kInfinitManagedFilesId: uuid}];
  });
  ELLE_DEBUG("%s: removing managed files with UUID: %s",
             self.description.UTF8String, uuid.UTF8String);
  InfinitManagedFiles* managed_files = [self.files_map objectForKey:uuid];
  if (managed_files == nil && !force)
  {
    ELLE_ERR("%s: unable to delete managed files, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  else if (managed_files == nil)
  {
    [self _deleteFiles:@[[self.managed_root stringByAppendingPathComponent:uuid]]];
    return;
  }
  [self.files_map removeObjectForKey:uuid];
  if (managed_files.copied && managed_files.root_dir.length)
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

- (uint64_t)_folderSize:(NSString*)path
{
  if (![self _pathExists:path])
    return 0;
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
  return res;
}

- (BOOL)_foundAsset:(ALAsset*)asset
            withURL:(NSURL*)url
    forManagedFiles:(InfinitManagedFiles*)managed_files
          withError:(NSError**)error
{
  NSUInteger asset_size = (NSUInteger)asset.defaultRepresentation.size;
  Byte* buffer = (Byte*)malloc(asset_size);
  NSUInteger buffered = [asset.defaultRepresentation getBytes:buffer
                                                   fromOffset:0
                                                       length:asset_size
                                                        error:error];
  if (*error)
  {
    ELLE_WARN("%s: unable to get bytes from ALAsset: %s",
              self.description.UTF8String, (*error).description.UTF8String);
  }
  if (buffered < asset_size)
  {
    ELLE_WARN("%s: bytes fetched from ALAsset less than size: %lu < %lu",
              self.description.UTF8String, buffered, asset_size);
  }
  NSData* data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
  NSString* filename = asset.defaultRepresentation.filename;
  NSDate* creation_date = [asset valueForProperty:ALAssetPropertyDate];
  NSString* path =
    [[InfinitTemporaryFileManager sharedInstance] addData:data
                                             withFilename:filename
                                             creationDate:creation_date
                                         modificationDate:nil
                                           toManagedFiles:managed_files
                                                    error:error];
  if (*error || !path.length)
  {
    ELLE_ERR("%s: unable to write data to managed files (%s): %s",
             self.description.UTF8String, managed_files.uuid.UTF8String,
             (*error).description.UTF8String);
    return NO;
  }
  dispatch_sync(dispatch_get_main_queue(), ^
  {
    if (path.length)
      [managed_files.asset_map setObject:path forKey:url];
  });
  return YES;
}

- (BOOL)_addPHAsset:(PHAsset*)asset
     toManagedFiles:(InfinitManagedFiles*)managed_files
          withError:(NSError**)error
{
  __block BOOL res = YES;
  __block NSString* path = nil;
  if (asset.mediaType == PHAssetMediaTypeVideo)
  {
    PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
    options.version = PHVideoRequestOptionsVersionCurrent;
    dispatch_semaphore_t get_path_sema = dispatch_semaphore_create(0);
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset
                                                    options:options
                                              resultHandler:^(AVAsset* av_asset,
                                                              AVAudioMix* audio_mix,
                                                              NSDictionary* info)
    {
      InfinitTemporaryFileManager* manager = [InfinitTemporaryFileManager sharedInstance];
      if ([av_asset isKindOfClass:AVURLAsset.class])
      {
        AVURLAsset* url_asset = (AVURLAsset*)av_asset;
        NSString* video_path = url_asset.URL.path;
        NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:video_path
                                                                               error:nil];
        NSNumber* file_size_number = [attrs objectForKey:NSFileSize];
        uint64_t free_space = [InfinitDirectoryManager sharedInstance].free_space;
        if (free_space < file_size_number.unsignedLongValue)
        {
          ELLE_WARN("%s: video from path fallback, not enough free space: %s > %s",
                    manager.description.UTF8String, file_size_number.infinit_fileSize.UTF8String,
                    @(free_space).infinit_fileSize.UTF8String)
          if (error != NULL)
            *error = [InfinitFileSystemError errorWithCode:InfinitFileSystemErrorNoFreeSpace];
        }
        else
        {
          NSArray* paths = [manager _addFiles:@[video_path]
                               toManagedFiles:managed_files 
                                         copy:YES 
                                         move:NO];
          if (paths.count && [paths[0] length])
          {
            path = paths[0];
          }
          else
          {
            ELLE_WARN("%s: unable to fetch PHAsset AVURLAsset, invalid path",
                      manager.description.UTF8String);
          }
        }
      }
      else if ([av_asset isKindOfClass:AVComposition.class])
      {
        AVComposition* composition = (AVComposition*)av_asset;
        AVCompositionTrack* track = [composition tracksWithMediaType:AVMediaTypeVideo].firstObject;
        AVCompositionTrackSegment* segment = track.segments.firstObject;
        if (segment.sourceURL.path.length)
        {
          NSArray* paths = [manager _addFiles:@[segment.sourceURL.path]
                               toManagedFiles:managed_files
                                         copy:YES
                                         move:NO];
          if (paths.count && [paths[0] length])
          {
            path = paths[0];
          }
          else
          {
            ELLE_WARN("%s: unable to fetch PHAsset AVComposition, invalid path",
                      manager.description.UTF8String);
          }
        }
        else
        {
          ELLE_WARN("%s: unable to fetch PHAsset AVComposition, invalid path",
                    manager.description.UTF8String);
        }
      }
      else if (info[PHImageErrorKey] && [info[PHImageErrorKey] description].length)
      {
        ELLE_WARN("%s: error fetching PHAsset video, reason: %s",
                  manager.description.UTF8String, [info[PHImageErrorKey] description].UTF8String);
      }
      else
      {
        ELLE_WARN("%s: unable to fetch PHAsset video (%s), unknown reason",
                  manager.description.UTF8String, NSStringFromClass(av_asset.class));
      }
      dispatch_semaphore_signal(get_path_sema);
    }];
    dispatch_semaphore_wait(get_path_sema, DISPATCH_TIME_FOREVER);
  }
  else
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
      InfinitTemporaryFileManager* manager = [InfinitTemporaryFileManager sharedInstance];
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
            ELLE_DEBUG("%s: renaming file: %s -> %s", manager.description.UTF8String,
                       filename.UTF8String, new_filename.UTF8String);
            filename = new_filename;
            break;
          }
        }
      }
      if (!imageData.length)
      {
        NSString* reason = @"<empty>";
        if (info[PHImageCancelledKey])
          reason = @"fetch cancelled";
        if (info[PHImageErrorKey] && [info[PHImageErrorKey] description].length)
          reason = [info[PHImageErrorKey] description];
        ELLE_WARN("%s: got empty file from PHImageManager for %s, reason: %s",
                  manager.description.UTF8String, filename.UTF8String, reason.UTF8String);
      }
      else if (info[PHImageErrorKey] && [info[PHImageErrorKey] description].length)
      {
        ELLE_WARN("%s: error fetching PHAsset %s, reason: %s",
                  manager.description.UTF8String, (filename.length ? filename.UTF8String : "<nil>"),
                  [info[PHImageErrorKey] description].UTF8String);
      }
      if (imageData.length)
      {
        path = [[InfinitTemporaryFileManager sharedInstance] addData:imageData
                                                        withFilename:filename
                                                        creationDate:asset.creationDate
                                                    modificationDate:asset.modificationDate
                                                      toManagedFiles:managed_files
                                                               error:error];
      }
    }];
  }
  if (*error || !path.length)
  {
    NSString* error_message =
      (*error).description.length ? (*error).description : @"<unknown error>";
    ELLE_ERR("%s: unable to write data to managed files (%s): %s",
             self.description.UTF8String, managed_files.uuid.UTF8String, error_message.UTF8String);
    res = NO;
  }
  else
  {
    dispatch_sync(dispatch_get_main_queue(), ^
    {
      [managed_files.asset_map setObject:path forKey:asset.localIdentifier];
    });
  }
  return res;
}

@end
