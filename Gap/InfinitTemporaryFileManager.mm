//
//  InfinitTemporaryFileManager.m
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import "InfinitTemporaryFileManager.h"

#import "InfinitManagedFiles.h"
#import "InfinitLinkTransactionManager.h"
#import "InfinitPeerTransactionManager.h"
#import "InfinitStateManager.h"

#undef check
#import <elle/log.hh>

#import <AssetsLibrary/AssetsLibrary.h>

ELLE_LOG_COMPONENT("Gap-ObjC++.TemporaryFileManager");

static InfinitTemporaryFileManager* _instance = nil;

@implementation InfinitTemporaryFileManager
{
@private
  NSMutableDictionary* _files_map;
  NSMutableDictionary* _transaction_map;

  NSString* _managed_root;

  uint64_t _max_mirror_size;

  ALAssetsLibrary* _library;
}

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _max_mirror_size = [[InfinitStateManager sharedInstance] max_mirror_size];
    _files_map = [NSMutableDictionary dictionary];
    _transaction_map = [NSMutableDictionary dictionary];
    _managed_root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"managed_files"];
    [self _deleteFiles:@[_managed_root]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_linkTransactionUpdated:)
                                                 name:INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_peerTransactionUpdated:)
                                                 name:INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION
                                               object:nil];
    _library = nil;
  }
  return self;
}

- (void)dealloc
{
  [self _deleteFiles:@[_managed_root]];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitTemporaryFileManager alloc] init];
  return _instance;
}

- (ALAssetsLibrary*)_sharedLibrary
{
  if (_library == nil)
    _library = [[ALAssetsLibrary alloc] init];
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

- (void)_linkTransactionUpdated:(NSNotification*)notification
{
  NSNumber* id_ = notification.userInfo[@"id"];
  InfinitManagedFiles* managed_files = [_transaction_map objectForKey:id_];
  if (managed_files == nil)
    return;
  InfinitLinkTransaction* transaction =
    [[InfinitLinkTransactionManager sharedInstance] transactionWithId:id_];
  if (managed_files.total_size.unsignedIntegerValue < _max_mirror_size ||
      ![self _transactionFilesNeededForStatus:transaction.status])
  {
    [_transaction_map removeObjectForKey:id_];
    if([_transaction_map allKeysForObject:managed_files].count == 0)
      [self deleteManagedFiles:managed_files.uuid];
  }
}

- (void)_peerTransactionUpdated:(NSNotification*)notification
{
  NSNumber* id_ = notification.userInfo[@"id"];
  InfinitManagedFiles* managed_files = [_transaction_map objectForKey:id_];
  if (managed_files == nil)
    return;
  InfinitPeerTransaction* transaction =
    [[InfinitPeerTransactionManager sharedInstance] transactionWithId:id_];
  if (managed_files.total_size.unsignedIntegerValue < _max_mirror_size ||
      ![self _transactionFilesNeededForStatus:transaction.status])
  {
    [_transaction_map removeObjectForKey:id_];
    if([_transaction_map allKeysForObject:managed_files].count == 0)
      [self deleteManagedFiles:managed_files.uuid];
  }
}

#pragma mark - Public

- (NSString*)createManagedFiles
{
  InfinitManagedFiles* managed_files = [[InfinitManagedFiles alloc] init];
  [_files_map setObject:managed_files forKey:managed_files.uuid];
  managed_files.root_dir = [_managed_root stringByAppendingPathComponent:managed_files.uuid];
  return managed_files.uuid;
}

- (NSArray*)pathsForManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to fetch files from %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return @[];
  }
  return managed_files.managed_paths.array;
}

- (NSNumber*)totalSizeOfManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to get total size, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return nil;
  }
  return managed_files.total_size;
}

- (void)addAssetsLibraryURLList:(NSArray*)list
                 toManagedFiles:(NSString*)uuid
                performSelector:(SEL)selector
                       onObject:(id)object
{
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(queue, ^
  {
    InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
    if (managed_files == nil)
    {
      ELLE_ERR("%s: unable to add asset list, %s not in map",
               self.description.UTF8String, uuid.UTF8String);
      return;
    }
    NSMethodSignature* method_signature = [object methodSignatureForSelector:selector];
    NSInvocation* callback = [NSInvocation invocationWithMethodSignature:method_signature];
    callback.target = object;
    callback.selector = selector;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    for (NSURL* url in list)
    {
       [[self _sharedLibrary] assetForURL:url
                              resultBlock:^(ALAsset* asset)
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
                                                   toManagedFiles:uuid];
          [managed_files.asset_map setObject:path forKey:url];
          dispatch_semaphore_signal(sema);
        }
                             failureBlock:^(NSError* error)
        {
          ELLE_ERR("%s: unable to create file (%s): %s", self.description.UTF8String,
                   url.absoluteString.UTF8String, error.description.UTF8String);
          dispatch_semaphore_signal(sema);
        }];
      dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    [callback invoke];
  });
}

- (void)removeAssetLibraryURLList:(NSArray*)list
                 fromManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to add asset list, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  NSMutableArray* paths = [NSMutableArray array];
  for (NSURL* url in list)
  {
    NSString* path = [managed_files.asset_map objectForKey:url];
    if (path == nil)
      continue;
    [paths addObject:path];
  }
  [managed_files.asset_map removeObjectsForKeys:list];
  [self removeFiles:paths fromManagedFiles:uuid];
}

- (NSString*)addData:(NSData*)data
        withFilename:(NSString*)filename
      toManagedFiles:(NSString*)uuid
{
  if (data == nil)
  {
    ELLE_ERR("%s: unable to write file to %s, data is nil",
             self.description.UTF8String, filename.UTF8String);
    return nil;
  }
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to write file to %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return nil;
  }
  NSString* path = [managed_files.root_dir stringByAppendingPathComponent:filename];
  if (![self _pathExists:managed_files.root_dir])
    [self _createDirectoryAtPath:managed_files.root_dir];
  NSError* error;
  if (![data writeToFile:path options:NSDataWritingAtomic error:&error])
  {
    ELLE_ERR("%s: unable to write file %s: %s", self.description.UTF8String,
             path.UTF8String, error.description.UTF8String);
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
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
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

- (void)removeFiles:(NSArray*)files
   fromManagedFiles:(NSString*)uuid
{
  if (files == nil || files.count == 0)
    return;

  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to remove files from %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  [managed_files.managed_paths removeObjectsInArray:files];
  [self _deleteFiles:files];
  managed_files.total_size = [self _folderSize:managed_files.root_dir];
}

- (void)setTransactionIds:(NSArray*)transaction_ids
          forManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to set transaction_id, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  for (NSNumber* id_ in transaction_ids)
  {
    [_transaction_map setObject:managed_files forKey:id_];
  }
}

- (void)deleteManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to delete managed files, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  [_files_map removeObjectForKey:uuid];
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

@end
