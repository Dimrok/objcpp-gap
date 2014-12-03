//
//  InfinitManagedFiles.h
//  Gap
//
//  Created by Christopher Crone on 25/11/14.
//
//

#import <Foundation/Foundation.h>

@interface InfinitManagedFiles : NSObject

@property (nonatomic, readonly) NSString* uuid;
@property (nonatomic, readwrite) NSMutableOrderedSet* managed_paths;
@property (nonatomic, readwrite) NSString* root_dir;
@property (nonatomic, readwrite) NSNumber* transaction_id;
@property (nonatomic, readwrite) NSNumber* total_size;
@property (nonatomic, readwrite) NSMutableDictionary* asset_map;

@end
