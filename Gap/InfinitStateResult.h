//
//  InfinitStateResult.h
//  Infinit
//
//  Created by Christopher Crone on 29/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <surface/gap/enums.hh>

@interface InfinitStateResult : NSObject

@property (readonly) gap_Status status;
@property (readonly) id data;
@property (readonly) BOOL success;

- (id)initWithStatus:(gap_Status)status;
- (id)initWithStatus:(gap_Status)status
             andData:(id)data;
@end
