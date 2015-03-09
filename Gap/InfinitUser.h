//
//  InfinitUser.h
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
# import <UIKit/UIImage.h>
#else
# import <AppKit/NSImage.h>
#endif

/** Notification sent when a user's avatar is ready.
 Contains a dictionary with the user "id".
 */
#define INFINIT_USER_AVATAR_NOTIFICATION @"INFINIT_USER_AVATAR_NOTIFICATION"

@interface InfinitUser : NSObject

#if TARGET_OS_IPHONE
@property (nonatomic, readonly) UIImage* avatar;
#else
@property (nonatomic, readonly) NSImage* avatar;
#endif
@property (nonatomic, readwrite) BOOL deleted;
@property (nonatomic, readwrite) BOOL favorite;
@property (nonatomic, readwrite) NSString* fullname;
@property (nonatomic, readonly) BOOL ghost;
@property (nonatomic, readonly) NSString* ghost_code;
@property (nonatomic, readonly) NSString* ghost_invitation_url;
@property (nonatomic, readonly) NSString* handle;
@property (nonatomic, readonly) NSNumber* id_;
@property (nonatomic, readonly) BOOL is_self;
@property (nonatomic, readonly) NSString* meta_id;
@property (nonatomic, readonly) NSString* phone_number;
@property (nonatomic, readwrite) BOOL status;
@property (nonatomic, readonly) BOOL swagger;

- (id)initWithId:(NSNumber*)id_
          status:(BOOL)status
        fullname:(NSString*)fullname
          handle:(NSString*)handle
         swagger:(BOOL)swagger
         deleted:(BOOL)deleted
           ghost:(BOOL)ghost
       ghostCode:(NSString*)ghost_code
ghostInvitationURL:(NSString*)ghost_invitation_url
         meta_id:(NSString*)meta_id
     phoneNumber:(NSString*)phone_number;

- (void)updateWithUser:(InfinitUser*)user;

@end
