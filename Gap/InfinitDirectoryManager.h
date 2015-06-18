//
//  InfinitDirectoryManager.h
//  Gap
//
//  Created by Christopher Crone on 24/01/15.
//
//

#import <Foundation/Foundation.h>

#import "InfinitTransaction.h"

@interface InfinitDirectoryManager : NSObject

@property (nonatomic, readonly) NSString* avatar_cache_directory;
@property (nonatomic, readwrite, copy) NSString* download_directory;
@property (nonatomic, readonly) NSString* log_directory;
@property (nonatomic, readonly) NSString* persistent_directory;
@property (nonatomic, readonly) NSString* non_persistent_directory;
@property (nonatomic, readonly) NSString* temporary_files_directory;
@property (nonatomic, readonly) NSString* thumbnail_cache_directory;
@property (nonatomic, readonly) NSString* upload_thumbnail_cache_directory;

@property (nonatomic, readonly) uint64_t free_space;

+ (instancetype)sharedInstance;

- (NSString*)downloadDirectoryForTransaction:(InfinitTransaction*)transaction;

@end
