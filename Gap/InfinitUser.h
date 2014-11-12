//
//  InfinitUser.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InfinitUser : NSObject

@property BOOL deleted;
@property BOOL favorite;
@property (strong) NSString* fullname;
@property BOOL ghost;
@property (strong) NSString* handle;
@property (strong) NSNumber* id_;
@property (strong) NSString* meta_id;
@property BOOL status;

- (id)initWithId:(NSNumber*)id_
          status:(BOOL)status
        fullname:(NSString*)fullname
          handle:(NSString*)handle
         deleted:(BOOL)deleted
           ghost:(BOOL)ghost;
@end
