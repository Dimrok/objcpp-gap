//
//  InfinitUser.m
//  Infinit
//
//  Created by Christopher Crone on 31/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitUser.h"

#import "InfinitStateManager.h"
#import "InfinitAvatarManager.h"

@implementation InfinitUser

#pragma mark - Init

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
     phoneNumber:(NSString*)phone_number
{
  if (self = [super init])
  {
    _id_ = id_;
    _status = status;
    _fullname = fullname;
    _handle = handle;
    _swagger = swagger;
    _deleted = deleted;
    _ghost = ghost;
    _ghost_code = ghost_code;
    _ghost_invitation_url = ghost_invitation_url;
    _meta_id = meta_id;
    _phone_number = phone_number;
  }
  return self;
}

+ (id)initNullUser
{
  return [[InfinitUser alloc] initWithId:@0
                                  status:NO
                                fullname:@"Unknown"
                                  handle:@""
                                 swagger:NO
                                 deleted:YES
                                   ghost:YES
                               ghostCode:nil
                      ghostInvitationURL:nil
                                 meta_id:@"" 
                             phoneNumber:nil];
}

#pragma mark - Public

#if TARGET_OS_IPHONE
- (UIImage*)avatar
#else
- (NSImage*)avatar
#endif
{
  return [[InfinitAvatarManager sharedInstance] avatarForUser:self];
}

- (void)setFullname:(NSString*)fullname
{
  if (!self.is_self)
    return;
  _fullname = fullname;
}

- (BOOL)is_self
{
  if ([[[InfinitStateManager sharedInstance] self_id] isEqualToNumber:self.id_])
    return YES;
  else
    return NO;
}

#pragma mark - Update User

- (void)updateWithUser:(InfinitUser*)user
{
  _status = user.status;
  _fullname = user.fullname;
  _handle = user.handle;
  _swagger = user.swagger;
  _deleted = user.deleted;
  _ghost = user.ghost;
  if (user.ghost_code.length > 0)
    _ghost_code = user.ghost_code;
  if (user.ghost_invitation_url.length > 0)
    _ghost_invitation_url = user.ghost_invitation_url;
  if (user.phone_number.length > 0)
    _phone_number = user.phone_number;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:self.class])
    return NO;
  if ([self.id_ isEqualToNumber:[object id_]])
    return YES;
  return NO;
}

- (NSUInteger)hash
{
  return self.id_.hash;
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%p: %@: %@ %@%@: %@%@%@>",
          self,
          self.id_,
          self.deleted ? @"deleted" : self.ghost ? @"ghost" : @"normal",
          self.fullname,
          self.handle.length > 0 ? [NSString stringWithFormat:@" (%@)", self.handle] : @"",
          self.favorite ? @"is favorite, " : @"",
          self.swagger ? @"is swagger, " : @"",
          self.status ? @"online" : @"offline"];
}

@end
