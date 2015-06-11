//
//  InfinitStateWrapper.h
//  Infinit
//
//  Created by Christopher Crone on 29/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <surface/gap/gap.hh>

@interface InfinitStateWrapper : NSObject

@property (nonatomic, readonly) gap_State* state;

+ (void)startStateWithInitialDownloadDir:(NSString*)download_dir;
+ (instancetype)sharedInstance;

@end
