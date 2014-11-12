//
//  InfinitUser.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InfinitUser : NSObject

@property (readonly) BOOL deleted;
@property (readonly) BOOL favorite;
@property (strong, readonly) NSString* fullname;
@property (readonly) BOOL ghost;
@property (strong, readonly) NSString* handle;
@property (strong, readonly) NSNumber* id_;
@property (strong, readonly) NSString* meta_id;
@property (readonly) BOOL is_self;
@property (readonly) BOOL status;

- (id)initWithId:(NSNumber*)id_
          status:(BOOL)status
        fullname:(NSString*)fullname
          handle:(NSString*)handle
         deleted:(BOOL)deleted
           ghost:(BOOL)ghost;
@end
