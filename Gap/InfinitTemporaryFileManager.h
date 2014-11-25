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

- (NSString*)createManagedFiles;

- (NSArray*)pathsForManagedFiles:(NSString*)uuid;

- (void)addFiles:(NSArray*)files
  toManagedFiles:(NSString*)uuid
            copy:(BOOL)copy;

- (void)removeFiles:(NSArray*)files
   fromManagedFiles:(NSString*)uuid;

- (void)setTransactionId:(NSNumber*)transaction_id
         forManagedFiles:(NSString*)uuid;

- (void)deleteManagedFiles:(NSString*)uuid;

@end
