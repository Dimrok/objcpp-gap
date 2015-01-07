//
//  InfinitStateManager.mm
//  Infinit
//
//  Created by Christopher Crone on 23/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitStateManager.h"

#import "InfinitAvatarManager.h"
#import "InfinitConnectionManager.h"
#import "InfinitLinkTransaction.h"
#import "InfinitLinkTransactionManager.h"
#import "InfinitPeerTransaction.h"
#import "InfinitPeerTransactionManager.h"
#import "InfinitStateResult.h"
#import "InfinitStateWrapper.h"
#import "InfinitUser.h"
#import "InfinitUserManager.h"

#import <surface/gap/gap.hh>

#if TARGET_OS_IPHONE
# import <UIKit/UIImage.h>
#else
# import <AppKit/NSImage.h>
#endif

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.StateManager");

// Block type to queue gap operation
typedef gap_Status(^gap_operation_t)(InfinitStateManager*, NSOperation*);

static InfinitStateManager* _manager_instance = nil;
static NSNumber* _self_id = nil;
static NSString* _self_device_id = nil;

@implementation InfinitStateManager
{
@private
  NSOperationQueue* _queue;

  NSTimer* _poll_timer;
  BOOL _polling; // Use boolean to guard polling as NSTimer valid is iOS 8.0+.
}

#pragma mark - Start

- (id)init
{
  NSCAssert(_manager_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _queue = [[NSOperationQueue alloc] init];
    _queue.name = @"StateManagerQueue";
    _queue.maxConcurrentOperationCount = 1;
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_manager_instance == nil)
    _manager_instance = [[InfinitStateManager alloc] init];
  return _manager_instance;
}

- (InfinitStateWrapper*)stateWrapper
{
  return [InfinitStateWrapper sharedInstance];
}

+ (void)startState
{
  [[InfinitStateManager sharedInstance] _attachCallbacks];
}

- (uint64_t)max_mirror_size
{
  return self.stateWrapper.max_mirror_size;
}

- (void)_attachCallbacks
{
  if (gap_critical_callback(self.stateWrapper.state, on_critical_callback) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach critical callback", self.description.UTF8String);
  }
  if (gap_connection_callback(self.stateWrapper.state, on_connection_callback) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach connection callback", self.description.UTF8String);
  }
  if (gap_peer_transaction_callback(self.stateWrapper.state, on_peer_transaction) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach peer transaction callback", self.description.UTF8String);
  }
  if (gap_link_callback(self.stateWrapper.state, on_link_transaction) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach link transaction callback", self.description.UTF8String);
  }
  if (gap_new_swagger_callback(self.stateWrapper.state, on_new_swagger) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach new swagger callback", self.description.UTF8String);
  }
  if (gap_user_status_callback(self.stateWrapper.state, on_user_status) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach user status callback", self.description.UTF8String);
  }
  if (gap_deleted_favorite_callback(self.stateWrapper.state, on_deleted_favorite) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach favorite deleted callback", self.description.UTF8String);
  }
  if (gap_deleted_swagger_callback(self.stateWrapper.state, on_deleted_swagger) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach swagger deleted callback", self.description.UTF8String);
  }
  if (gap_avatar_available_callback(self.stateWrapper.state, on_avatar) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach avatar recieved callback", self.description.UTF8String);
  }
}

#pragma mark - Stop

- (void)_clearSelf
{
  _self_id = nil;
  _self_device_id = nil;
}

- (void)_stopState
{
  _manager_instance = nil;
  [_poll_timer invalidate];
  _queue.suspended = YES;
  [_queue cancelAllOperations];
  [self _clearSelf];
}

+ (void)stopState
{
  [[InfinitStateManager sharedInstance] _stopState];
}

- (void)dealloc
{
  [self _stopState];
}

#pragma mark - Register/Login/Logout

- (void)registerFullname:(NSString*)fullname
                   email:(NSString*)email
                password:(NSString*)password
         performSelector:(SEL)selector
                onObject:(id)object
{
  __weak InfinitStateManager* weak_self = self;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     gap_clean_state(manager.stateWrapper.state);
     [manager _clearSelf];
     [manager _startPolling];
     gap_Status res;
     if (weak_self.push_token != nil && weak_self.push_token.length > 0)
     {
       std::string device_push_token = weak_self.push_token.UTF8String;
       res = gap_register(manager.stateWrapper.state,
                          fullname.UTF8String,
                          email.UTF8String,
                          password.UTF8String,
                          device_push_token);
     }
     else
     {
       res = gap_register(manager.stateWrapper.state,
                          fullname.UTF8String,
                          email.UTF8String,
                          password.UTF8String);
     }
     if (res == gap_ok)
       manager.logged_in = YES;
     else
       [manager _stopPolling];
     return res;
   } performSelector:selector onObject:object];
}

- (void)login:(NSString*)email
     password:(NSString*)password
performSelector:(SEL)selector
     onObject:(id)object
{
  __weak InfinitStateManager* weak_self = self;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     gap_clean_state(manager.stateWrapper.state);
     [manager _clearSelf];
     [manager _startPolling];
     gap_Status res;
     if (weak_self.push_token != nil && weak_self.push_token.length > 0)
     {
       std::string device_push_token = weak_self.push_token.UTF8String;
       res = gap_login(manager.stateWrapper.state,
                       email.UTF8String,
                       password.UTF8String,
                       device_push_token);
     }
     else
     {
       res = gap_login(manager.stateWrapper.state, email.UTF8String, password.UTF8String);
     }
     if (res == gap_ok)
       manager.logged_in = YES;
     else
       [manager _stopPolling];
     return res;
   } performSelector:selector onObject:object];
}

- (void)logoutPerformSelector:(SEL)selector
                     onObject:(id)object
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     [manager _stopPolling];
     gap_Status res = gap_logout(manager.stateWrapper.state);
     return res;
   } performSelector:selector onObject:object];
}

#pragma mark - Polling

- (BOOL)_polling
{
  return _polling;
}

- (void)_startPolling
{
  _polling = YES;
  _poll_timer = [NSTimer timerWithTimeInterval:2.0f
                                        target:self
                                      selector:@selector(_poll)
                                      userInfo:nil
                                       repeats:YES];
  if ([_poll_timer respondsToSelector:@selector(tolerance)])
  {
    _poll_timer.tolerance = 5.0;
  }
  [[NSRunLoop mainRunLoop] addTimer:_poll_timer forMode:NSDefaultRunLoopMode];
}

- (void)_stopPolling
{
  _polling = NO;
  [_poll_timer invalidate];
  _poll_timer = nil;
}

- (void)_poll
{
  if (!_polling)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    if (![manager _polling])
      return gap_error;
    return gap_poll(manager.stateWrapper.state);
  }];
}

#pragma mark - User

- (InfinitUser*)userById:(NSNumber*)id_
{
  if (!self._loggedIn)
    return nil;
  auto user = gap_user_by_id(self.stateWrapper.state, id_.unsignedIntValue);
  return [self _convertUser:user];
}

- (NSArray*)swaggers
{
  if (!self._loggedIn)
    return nil;
  auto swaggers_ = gap_swaggers(self.stateWrapper.state);
  NSMutableArray* res = [NSMutableArray array];
  for (auto const& swagger: swaggers_)
    [res addObject:[self _convertUser:swagger]];
  return res;
}

- (NSArray*)favorites
{
  if (!self._loggedIn)
    return nil;
  auto favorites_ = gap_favorites(self.stateWrapper.state);
  NSMutableArray* res = [NSMutableArray array];
  for (uint32_t favorite: favorites_)
    [res addObject:[self _numFromUint:favorite]];
  return res;
}

- (void)addFavorite:(InfinitUser*)user
{
  if (!self._loggedIn)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
     return gap_favorite(manager.stateWrapper.state, user.id_.unsignedIntValue);
   }];
}

- (void)removeFavorite:(InfinitUser*)user
{
  if (!self._loggedIn)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
     return gap_unfavorite(manager.stateWrapper.state, user.id_.unsignedIntValue);
   }];
}

- (NSNumber*)self_id
{
  if (!self._loggedIn)
    return nil;
  if (_self_id == nil)
    _self_id = [self _numFromUint:gap_self_id(self.stateWrapper.state)];
  return _self_id;
}

- (NSString*)self_device_id
{
  if (_self_device_id == nil)
    _self_device_id = [self _nsString:gap_self_device_id(self.stateWrapper.state)];
  return _self_device_id;
}

#if TARGET_OS_IPHONE
- (UIImage*)avatarForUserWithId:(NSNumber*)id_
#else
- (NSImage*)avatarForUserWithId:(NSNumber*)id_
#endif
{
  if (!self._loggedIn)
    return nil;
  void* gap_data;
  size_t size;
  gap_Status status = gap_avatar(self.stateWrapper.state, id_.unsignedIntValue, &gap_data, &size);
#if TARGET_OS_IPHONE
  UIImage* res = nil;
  if (status == gap_ok && size > 0)
  {
    NSData* data = [[NSData alloc] initWithBytes:gap_data length:size];
    res = [UIImage imageWithData:data];
  }
#else
  NSImage* res = nil;
  if (status == gap_ok && size > 0)
  {
    NSData* data = [[NSData alloc] initWithBytes:gap_data length:size];
    res = [[NSImage alloc] initWithData:data];
  }
#endif
  return res;
}

#pragma mark - All Transactions

- (void)pauseTransactionWithId:(NSNumber*)id_
{
  if (!self._loggedIn)
    return;
  gap_pause_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

- (void)resumeTransactionWithId:(NSNumber*)id_
{
  if (!self._loggedIn)
    return;
  gap_resume_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

- (void)cancelTransactionWithId:(NSNumber*)id_
{
  if (!self._loggedIn)
    return;
  gap_cancel_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

- (float)transactionProgressForId:(NSNumber*)id_
{
  if (!self._loggedIn)
    return 0.0f;
  return gap_transaction_progress(self.stateWrapper.state, id_.unsignedIntValue);
}

#pragma mark - Link Transactions

- (InfinitLinkTransaction*)linkTransactionById:(NSNumber*)id_
{
  if (!self._loggedIn)
    return nil;
  auto transaction = gap_link_transaction_by_id(self.stateWrapper.state, id_.unsignedIntValue);
  return [self _convertLinkTransaction:transaction];
}

- (NSArray*)linkTransactions
{
  if (!self._loggedIn)
    return nil;
  auto transactions_ = gap_link_transactions(self.stateWrapper.state);
  NSMutableArray* res = [NSMutableArray array];
  for (auto const& transaction: transactions_)
  {
    [res addObject:[self _convertLinkTransaction:transaction]];
  }
  return res;
}

- (NSNumber*)createLinkWithFiles:(NSArray*)files
                     withMessage:(NSString*)message
{
  if (!self._loggedIn)
    return nil;
  uint32_t res = gap_create_link_transaction(self.stateWrapper.state,
                                             [self _filesVectorFromNSArray:files],
                                             message.UTF8String);
  return [self _numFromUint:res];
}

- (void)deleteTransactionWithId:(NSNumber*)id_
{
  if (!self._loggedIn)
    return;
  gap_delete_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

#pragma mark - Peer Transactions

- (InfinitPeerTransaction*)peerTransactionById:(NSNumber*)id_
{
  if (!self._loggedIn)
    return nil;
  auto transaction = gap_peer_transaction_by_id(self.stateWrapper.state, id_.unsignedIntValue);
  return [self _convertPeerTransaction:transaction];
}

- (NSArray*)peerTransactions
{
  if (!self._loggedIn)
    return nil;
  auto transactions_ = gap_peer_transactions(self.stateWrapper.state);
  NSMutableArray* res = [NSMutableArray array];
  for (auto const& transaction: transactions_)
  {
    [res addObject:[self _convertPeerTransaction:transaction]];
  }
  return res;
}

- (NSNumber*)sendFiles:(NSArray*)files
           toRecipient:(id)recipient
           withMessage:(NSString*)message
{
  if (!self._loggedIn)
    return nil;
  uint32_t res = 0;
  if ([recipient isKindOfClass:InfinitUser.class])
  {
    InfinitUser* user = recipient;
    res = gap_send_files(self.stateWrapper.state,
                         user.id_.unsignedIntValue,
                         [self _filesVectorFromNSArray:files],
                         message.UTF8String);
  }
  else if ([recipient isKindOfClass:NSString.class])
  {
    NSString* email = recipient;
    res = gap_send_files_by_email(self.stateWrapper.state,
                                  email.UTF8String,
                                  [self _filesVectorFromNSArray:files],
                                  message.UTF8String);
  }
  return [self _numFromUint:res];
}

- (void)acceptTransactionWithId:(NSNumber*)id_
{
  if (!self._loggedIn)
    return;
  gap_accept_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

- (void)rejectTransactionWithId:(NSNumber*)id_
{
  if (!self._loggedIn)
    return;
  gap_reject_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

#pragma mark - Connection Status

- (void)setNetworkConnectionStatus:(InfinitNetworkStatus)status
{
  bool connected = false;
  if (status == ReachableViaLAN || status == ReachableViaWWAN)
    connected = true;
  gap_internet_connection(self.stateWrapper.state, connected);
}

#pragma mark - Features

- (NSDictionary*)features
{
  auto features_ = gap_fetch_features(self.stateWrapper.state);
  NSMutableDictionary* dict = [NSMutableDictionary dictionary];
  for (std::pair<std::string, std::string> const& pair: features_)
  {
    NSString* key = [self _nsString:pair.first];
    dict[key] = [self _nsString:pair.second];
  }
  return dict;
}

#pragma mark - Self

- (BOOL)_loggedIn
{
  BOOL res = gap_logged_in(self.stateWrapper.state);
  if (self.logged_in != res)
    self.logged_in = res;
  return res;
}

- (NSString*)selfFullname
{
  auto fullname = gap_self_fullname(self.stateWrapper.state);
  return [self _nsString:fullname];
}

- (void)setSelfFullname:(NSString*)fullname
        performSelector:(SEL)selector
               onObject:(id)object
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
     return gap_set_self_fullname(manager.stateWrapper.state, fullname.UTF8String);
   } performSelector:selector onObject:object];
}

- (NSString*)selfHandle
{
  if (!self._loggedIn)
    return nil;
  auto handle = gap_self_handle(self.stateWrapper.state);
  return [self _nsString:handle];
}

- (void)setSelfHandle:(NSString*)handle
      performSelector:(SEL)selector
             onObject:(id)object
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
     return gap_set_self_handle(manager.stateWrapper.state, handle.UTF8String);
   } performSelector:selector onObject:object];
}

- (NSString*)selfEmail
{
  if (!self._loggedIn)
    return nil;
  auto email = gap_self_email(self.stateWrapper.state);
  return [self _nsString:email];
}

- (void)setSelfEmail:(NSString*)email
            password:(NSString*)password
     performSelector:(SEL)selector
            onObject:(id)object
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
     return gap_set_self_email(manager.stateWrapper.state, email.UTF8String, password.UTF8String);
   } performSelector:selector onObject:object];
}

- (void)changeFromPassword:(NSString*)old_password
                toPassword:(NSString*)new_password
           performSelector:(SEL)selector
                  onObject:(id)object
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
     return gap_change_password(manager.stateWrapper.state,
                                old_password.UTF8String,
                                new_password.UTF8String);
   } performSelector:selector onObject:object];
}

#if TARGET_OS_IPHONE
- (void)setSelfAvatar:(UIImage*)image
#else
- (void)setSelfAvatar:(NSImage*)image
#endif
      performSelector:(SEL)selector
             onObject:(id)object
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
#if TARGET_OS_IPHONE
     NSData* image_data = UIImageJPEGRepresentation(image, 0.8f);
#else
     NSData* image_data = [image TIFFRepresentation];
     NSBitmapImageRep* image_rep = [NSBitmapImageRep imageRepWithData:image_data];
     NSDictionary* image_props = [NSDictionary dictionaryWithObject:@0.8f
                                                             forKey:NSImageCompressionFactor];
     image_data = [image_rep representationUsingType:NSJPEGFileType properties:image_props];
#endif
     return gap_update_avatar(manager.stateWrapper.state, image_data.bytes, image_data.length);
   } performSelector:selector onObject:object];
}

#pragma mark - Search

- (void)userByHandle:(NSString*)handle
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(NSMutableDictionary*)data
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager._loggedIn)
       return gap_not_logged_in;
     auto user_ = gap_user_by_handle(manager.stateWrapper.state, handle.UTF8String);
     InfinitUser* user = [manager _convertUser:user_];
     data[@"user"] = user;
     return gap_ok;
   } performSelector:selector onObject:object withData:data];
}

- (void)textSearch:(NSString*)text
   performSelector:(SEL)selector
          onObject:(id)object
          withData:(NSMutableDictionary*)data
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager.logged_in)
       return gap_not_logged_in;
     auto results = gap_users_search(manager.stateWrapper.state, text.UTF8String);
     NSMutableArray* res = [NSMutableArray array];
     for (auto const& user: results)
     {
       [res addObject:[manager _convertUser:user]];
     }
     data[@"users"] = res;
     return gap_ok;
   } performSelector:selector onObject:object withData:data];
}

- (void)searchEmails:(NSArray*)emails
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(NSMutableDictionary*)data
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager.logged_in)
       return gap_not_logged_in;
     std::vector<std::string> emails_;
     for (NSString* email in emails)
     {
       emails_.push_back(email.UTF8String);
     }
     auto results = gap_users_by_emails(manager.stateWrapper.state, emails_);
     NSMutableDictionary* res = [NSMutableDictionary dictionary];
     for (auto const& result: results)
     {
       res[[manager _nsString:result.first]] = [manager _convertUser:result.second];
     }
     data[@"results"] = res;
     return gap_ok;
   } performSelector:selector onObject:object withData:data];
}

#pragma mark - Conversions

- (std::vector<std::string>)_filesVectorFromNSArray:(NSArray*)array
{
  std::vector<std::string> res;
  for (NSString* element in array)
  {
    res.push_back(element.fileSystemRepresentation);
  }
  return res;
}

- (NSString*)_nsString:(std::string const&)string
{
  return [NSString stringWithUTF8String:string.c_str()];
}

- (NSNumber*)_numFromUint:(uint32_t)id_
{
  return [NSNumber numberWithUnsignedInt:id_];
}

- (InfinitLinkTransaction*)_convertLinkTransaction:(surface::gap::LinkTransaction const&)transaction
{
  NSString* link = @"";
  if (transaction.link)
    link = [NSString stringWithUTF8String:transaction.link.get().c_str()];
  InfinitLinkTransaction* res =
    [[InfinitLinkTransaction alloc] initWithId:[self _numFromUint:transaction.id]
                                        status:transaction.status
                                 sender_device:[self _nsString:transaction.sender_device_id]
                                          name:[self _nsString:transaction.name]
                                         mtime:transaction.mtime
                                          link:link
                                   click_count:[self _numFromUint:transaction.click_count]];
  return res;
}

- (InfinitPeerTransaction*)_convertPeerTransaction:(surface::gap::PeerTransaction const&)transaction
{
  NSMutableArray* files = [NSMutableArray array];
  NSNumber* size = [NSNumber numberWithLongLong:transaction.total_size];
  for (auto const& file: transaction.file_names)
  {
    [files addObject:[self _nsString:file]];
  }
  InfinitPeerTransaction* res =
    [[InfinitPeerTransaction alloc] initWithId:[self _numFromUint:transaction.id]
                                        status:transaction.status
                                        sender:[self _numFromUint:transaction.sender_id]
                                 sender_device:[self _nsString:transaction.sender_device_id]
                                     recipient:[self _numFromUint:transaction.recipient_id]
                                         files:files
                                         mtime:transaction.mtime
                                       message:[self _nsString:transaction.message]
                                          size:size
                                     directory:transaction.is_directory];
  return res;
}

- (InfinitUser*)_convertUser:(surface::gap::User const&)user
{
  InfinitUser* res = [[InfinitUser alloc] initWithId:[self _numFromUint:user.id]
                                              status:user.status
                                            fullname:[self _nsString:user.fullname]
                                              handle:[self _nsString:user.handle]
                                             swagger:user.swagger
                                             deleted:user.deleted
                                               ghost:user.ghost];
  return res;
}

#pragma mark - Operations

- (void)_addOperation:(gap_operation_t)operation
{
  __weak InfinitStateManager* weak_self = self;
  __block NSBlockOperation* block_operation = [NSBlockOperation blockOperationWithBlock:^(void)
    {
      if (block_operation.isCancelled)
        return;
      if (weak_self == nil)
        return;
      operation(weak_self, block_operation);
      if (block_operation.isCancelled)
      {
        ELLE_LOG("%s: cancelled operation", self.description.UTF8String);
        return;
      }
    }];
  [_queue addOperation:block_operation];
}

- (void)_addOperation:(gap_operation_t)operation
      performSelector:(SEL)selector
             onObject:(id)object
{
  [self _addOperation:operation performSelector:selector onObject:object withData:nil];
}


- (void)_addOperation:(gap_operation_t)operation
      performSelector:(SEL)selector
             onObject:(id)object
             withData:(id)data
{
  __weak InfinitStateManager* weak_self = self;
  __block NSBlockOperation* block_operation = [NSBlockOperation blockOperationWithBlock:^(void)
   {
     if (block_operation.isCancelled)
     {
       ELLE_LOG("%s: cancelled operation: %s.%s",
                self.description.UTF8String,
                [object description].UTF8String,
                NSStringFromSelector(selector).UTF8String);
       return;
     }
     if (weak_self == nil)
       return;
     gap_Status result = operation(weak_self, block_operation);
     InfinitStateResult* operation_result = [[InfinitStateResult alloc] initWithStatus:result
                                                                               andData:data];
     if (block_operation.isCancelled)
     {
       ELLE_LOG("%s: cancelled operation: %s.%s",
                self.description.UTF8String,
                [object description].UTF8String,
                NSStringFromSelector(selector).UTF8String);
       return;
     }
     if (object != nil && selector != nil)
       [object performSelectorOnMainThread:selector
                                withObject:operation_result
                             waitUntilDone:NO];
   }];
  [_queue addOperation:block_operation];
}

#pragma mark - Callbacks

static
void
on_critical_callback()
{
  abort();
}

static
void
on_connection_callback(bool status, bool still_retrying, std::string const& last_error)
{
  NSString* error = [NSString stringWithUTF8String:last_error.c_str()];
  [[InfinitConnectionManager sharedInstance] setConnectedStatus:status
                                                    stillTrying:still_retrying
                                                      lastError:error];
}

- (void)_peerTransactionUpdated:(surface::gap::PeerTransaction const&)transaction_
{
  InfinitPeerTransaction* transaction = [self _convertPeerTransaction:transaction_];
  [[InfinitPeerTransactionManager sharedInstance] transactionUpdated:transaction];
}

static
void
on_peer_transaction(surface::gap::PeerTransaction const& transaction)
{
  [[InfinitStateManager sharedInstance] _peerTransactionUpdated:transaction];
}

- (void)_linkTransactionUpdated:(surface::gap::LinkTransaction const&)transaction_
{
  InfinitLinkTransaction* transaction = [self _convertLinkTransaction:transaction_];
  [[InfinitLinkTransactionManager sharedInstance] transactionUpdated:transaction];
}

static
void
on_link_transaction(surface::gap::LinkTransaction const& transaction)
{
  [[InfinitStateManager sharedInstance] _linkTransactionUpdated:transaction];
}

- (void)_newUser:(surface::gap::User const&)user_
{
  InfinitUser* user = [self _convertUser:user_];
  [[InfinitUserManager sharedInstance] newUser:user];
}

static
void
on_new_swagger(surface::gap::User const& user)
{
  [[InfinitStateManager sharedInstance] _newUser:user];
}

- (void)_userWithId:(uint32_t)user_id
      statusUpdated:(bool)status
{
  [[InfinitUserManager sharedInstance] userWithId:[self _numFromUint:user_id] statusUpdated:status];
}

static
void
on_user_status(uint32_t user_id, bool status)
{
  [[InfinitStateManager sharedInstance] _userWithId:user_id statusUpdated:status];
}

- (void)_userDeleted:(uint32_t)user_id
{
  [[InfinitUserManager sharedInstance] userDeletedWithId:[self _numFromUint:user_id]];
}

static
void
on_deleted_favorite(uint32_t user_id)
{
  [[InfinitStateManager sharedInstance] _userDeleted:user_id];
}

static
void
on_deleted_swagger(uint32_t user_id)
{
  [[InfinitStateManager sharedInstance] _userDeleted:user_id];
}

- (void)_gotAvatarForUserWithId:(uint32_t)user_id
{
  [[InfinitAvatarManager sharedInstance] gotAvatarForUserWithId:[self _numFromUint:user_id]];
}

static
void
on_avatar(uint32_t user_id)
{
  [[InfinitStateManager sharedInstance] _gotAvatarForUserWithId:user_id];
}

@end
