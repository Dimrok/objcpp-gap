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

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.TemporaryFileManager");

static InfinitTemporaryFileManager* _instance = nil;

@implementation InfinitTemporaryFileManager
{
@private
  NSMutableDictionary* _files_map;
  NSMutableDictionary* _transaction_map;
  NSString* _managed_root;
}

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _files_map = [NSMutableDictionary dictionary];
    _transaction_map = [NSMutableDictionary dictionary];
    _managed_root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"managed_files"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(transactionUpdated:)
                                                 name:INFINIT_LINK_TRANSACTION_STATUS_NOTIFICATION
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(transactionUpdated:)
                                                 name:INFINIT_PEER_TRANSACTION_STATUS_NOTIFICATION
                                               object:nil];
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

#pragma mark - Transaction Callback

- (void)transactionUpdated:(NSNotification*)notification
{
  NSNumber* id_ = notification.userInfo[@"id"];
  InfinitManagedFiles* managed_files = [_transaction_map objectForKey:id_];
  if (managed_files == nil)
    return;
  [self deleteManagedFiles:managed_files.uuid];
  [_transaction_map removeObjectForKey:id_];
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

- (void)setTransactionId:(NSNumber*)transaction_id
         forManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to set transaction_id, %s not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  NSLog(@"xxx %@ has transaction_id: %@", uuid, transaction_id);
  [_transaction_map setObject:managed_files forKey:transaction_id];
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
    [managed_files.managed_paths addObjectsFromArray:files];
  }
}

- (void)removeFiles:(NSArray*)files
   fromManagedFiles:(NSString*)uuid
{
  InfinitManagedFiles* managed_files = [_files_map objectForKey:uuid];
  if (managed_files == nil)
  {
    ELLE_ERR("%s: unable to remove files from %s, not in map",
             self.description.UTF8String, uuid.UTF8String);
    return;
  }
  for (NSString* file in files)
  {
    [managed_files.managed_paths removeObject:file];
  }
  [self _deleteFiles:files];
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
  [self _deleteFiles:managed_files.managed_paths.array];
  if ([self _pathExists:managed_files.root_dir])
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

- (void)_deleteFiles:(NSArray*)files
{
  NSError* error;
  BOOL success;
  for (NSString* file in files)
  {
    success = [[NSFileManager defaultManager] removeItemAtPath:file error:&error];
    if (!success)
    {
      ELLE_WARN("%s: unable to remove %s: %s", self.description.UTF8String,
                file.UTF8String, error.description.UTF8String);
    }
    NSLog(@"xxx deleted: %@", file);
  }
}

@end
