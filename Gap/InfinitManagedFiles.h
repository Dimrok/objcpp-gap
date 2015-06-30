//
//  InfinitManagedFiles.h
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import <Foundation/Foundation.h>

@interface InfinitManagedFiles : NSObject <NSCoding>

/// Asset URLs that have been converted to files.
@property (nonatomic, readwrite) NSMutableDictionary* asset_map;
/// If the files were copied to a temporary location.
@property (nonatomic, readwrite) BOOL copied;
/// If the files are currently copying.
@property (nonatomic, readwrite) BOOL copying;
/// Callback to run when finished copying.
@property (nonatomic, copy) void (^done_copying_block)();
/// File count.
@property (nonatomic, readonly) NSUInteger file_count;
/// Paths to files.
@property (nonatomic, readwrite) NSMutableOrderedSet* managed_paths;
/// Assets that should not be sent but were added at some point.
@property (nonatomic, readonly) NSMutableSet* remove_assets;
/// Root directory where files are stored if they were copied.
@property (nonatomic, readwrite) NSString* root_dir;
/// If the managed files are in the process of being sent.
@property (atomic, readwrite) BOOL sending;
/// Array of sorted paths.
@property (nonatomic, readonly) NSArray* sorted_paths;
/// Total size of the files.
@property (nonatomic, readwrite) uint64_t total_size;
/// Unique identifier for the files.
@property (nonatomic, readonly) NSString* uuid;

@end
