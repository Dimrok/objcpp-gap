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
#import "InfinitCrashReporter.h"
#import "InfinitDirectoryManager.h"
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

@interface InfinitStateManager ()

@property (nonatomic, readwrite) NSString* current_user;

@end

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
    _current_user = nil;
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
  [InfinitCrashReporter sharedInstance];
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

- (void)_clearSelfAndModel:(BOOL)clear_model
{
  if (clear_model)
    [self _clearModels];
  _self_id = nil;
  _self_device_id = nil;
  _current_user = nil;
}

- (void)_clearSelf
{
  [self _clearSelfAndModel:YES];
}

- (void)_stopState
{
  _manager_instance = nil;
  [_poll_timer invalidate];
  _queue.suspended = YES;
  [_queue cancelAllOperations];
}

+ (void)stopState
{
  [[InfinitStateManager sharedInstance] _stopState];
  [[InfinitStateManager sharedInstance] _clearSelfAndModel:NO];
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
     [manager _clearSelf];
     if (res == gap_ok)
     {
       [[InfinitConnectionManager sharedInstance] setConnectedStatus:YES
                                                         stillTrying:NO
                                                           lastError:@""];
       manager.logged_in = YES;
       [weak_self setCurrent_user:email];
       [[InfinitCrashReporter sharedInstance] sendExistingCrashReport];
     }
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
     [manager _clearSelf];
     if (res == gap_ok)
     {
       [[InfinitConnectionManager sharedInstance] setConnectedStatus:YES
                                                         stillTrying:NO
                                                           lastError:@""];
       manager.logged_in = YES;
       [weak_self setCurrent_user:email];
       [[InfinitCrashReporter sharedInstance] sendExistingCrashReport];
     }
     else
     {
       [manager _stopPolling];
     }
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
  _poll_timer = [NSTimer timerWithTimeInterval:1.0f
                                        target:self
                                      selector:@selector(_poll)
                                      userInfo:nil
                                       repeats:YES];
  if ([_poll_timer respondsToSelector:@selector(tolerance)])
  {
    _poll_timer.tolerance = 1.0f;
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
  if (!self.logged_in)
    return nil;
  surface::gap::User res;
  gap_Status status = gap_user_by_id(self.stateWrapper.state, id_.unsignedIntValue, res);
  if (status != gap_ok)
    return nil;
  return [self _convertUser:res];
}

- (NSArray*)swaggers
{
  if (!self.logged_in)
    return nil;
  std::vector<surface::gap::User> res_;
  gap_Status status = gap_swaggers(self.stateWrapper.state, res_);
  if (status != gap_ok)
    return nil;
  NSMutableArray* res = [NSMutableArray array];
  for (auto const& swagger: res_)
    [res addObject:[self _convertUser:swagger]];
  return res;
}

- (NSArray*)favorites
{
  if (!self.logged_in)
    return nil;
  std::vector<uint32_t> res_;
  gap_Status status = gap_favorites(self.stateWrapper.state, res_);
  if (status != gap_ok)
    return nil;
  NSMutableArray* res = [NSMutableArray array];
  for (uint32_t favorite: res_)
    [res addObject:[self _numFromUint:favorite]];
  return res;
}

- (void)addFavorite:(InfinitUser*)user
{
  if (!self.logged_in)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager.logged_in)
       return gap_not_logged_in;
     return gap_favorite(manager.stateWrapper.state, user.id_.unsignedIntValue);
   }];
}

- (void)removeFavorite:(InfinitUser*)user
{
  if (!self.logged_in)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager.logged_in)
       return gap_not_logged_in;
     return gap_unfavorite(manager.stateWrapper.state, user.id_.unsignedIntValue);
   }];
}

- (NSNumber*)self_id
{
  if (!self.logged_in)
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
  if (!self.logged_in)
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
  if (!self.logged_in)
    return;
  gap_pause_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

- (void)resumeTransactionWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return;
  gap_resume_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

- (void)cancelTransactionWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return;
  gap_cancel_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

- (float)transactionProgressForId:(NSNumber*)id_
{
  if (!self.logged_in)
    return 0.0f;
  return gap_transaction_progress(self.stateWrapper.state, id_.unsignedIntValue);
}

#pragma mark - Link Transactions

- (InfinitLinkTransaction*)linkTransactionById:(NSNumber*)id_
{
  if (!self.logged_in)
    return nil;
  surface::gap::LinkTransaction res;
  gap_Status status = gap_link_transaction_by_id(self.stateWrapper.state, id_.unsignedIntValue, res);
  if (status != gap_ok)
    return nil;
  return [self _convertLinkTransaction:res];
}

- (NSArray*)linkTransactions
{
  if (!self.logged_in)
    return nil;
  std::vector<surface::gap::LinkTransaction> res_;
  gap_Status status = gap_link_transactions(self.stateWrapper.state, res_);
  if (status != gap_ok)
    return nil;
  NSMutableArray* res = [NSMutableArray array];
  for (auto const& transaction: res_)
  {
    [res addObject:[self _convertLinkTransaction:transaction]];
  }
  return res;
}

- (NSNumber*)createLinkWithFiles:(NSArray*)files
                     withMessage:(NSString*)message
{
  if (!self.logged_in)
    return nil;
  uint32_t res = gap_create_link_transaction(self.stateWrapper.state,
                                             [self _filesVectorFromNSArray:files],
                                             message.UTF8String);
  return [self _numFromUint:res];
}

- (void)deleteTransactionWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return;
  gap_delete_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

#pragma mark - Peer Transactions

- (InfinitPeerTransaction*)peerTransactionById:(NSNumber*)id_
{
  if (!self.logged_in)
    return nil;
  surface::gap::PeerTransaction res;
  gap_Status status = gap_peer_transaction_by_id(self.stateWrapper.state, id_.unsignedIntValue, res);
  if (status != gap_ok)
    return nil;
  return [self _convertPeerTransaction:res];
}

- (NSArray*)peerTransactions
{
  if (!self.logged_in)
    return nil;
  std::vector<surface::gap::PeerTransaction> res_;
  gap_Status status = gap_peer_transactions(self.stateWrapper.state, res_);
  if (status != gap_ok)
    return nil;
  NSMutableArray* res = [NSMutableArray array];
  for (auto const& transaction: res_)
  {
    [res addObject:[self _convertPeerTransaction:transaction]];
  }
  return res;
}

- (NSNumber*)sendFiles:(NSArray*)files
           toRecipient:(id)recipient
           withMessage:(NSString*)message
{
  if (!self.logged_in)
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
            toRelativeDirectory:(NSString*)directory
{
  if (!self.logged_in)
    return;
  if (directory != nil && directory.length > 0)
  {
    std::string output_dir = directory.UTF8String;
    gap_accept_transaction(self.stateWrapper.state, id_.unsignedIntValue, output_dir);
  }
  else
  {
    gap_accept_transaction(self.stateWrapper.state, id_.unsignedIntValue);
  }
}

- (void)rejectTransactionWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return;
  gap_reject_transaction(self.stateWrapper.state, id_.unsignedIntValue);
}

#pragma mark - Connection Status

- (void)setNetworkConnectionStatus:(InfinitNetworkStatuses)status
{
  bool connected = false;
  if (status == InfinitNetworkStatusReachableViaLAN ||
      status == InfinitNetworkStatusReachableViaWWAN)
  {
    connected = true;
  }
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
     if (!manager.logged_in)
       return gap_not_logged_in;
     return gap_set_self_fullname(manager.stateWrapper.state, fullname.UTF8String);
   } performSelector:selector onObject:object];
}

- (NSString*)selfHandle
{
  if (!self.logged_in)
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
     if (!manager.logged_in)
       return gap_not_logged_in;
     return gap_set_self_handle(manager.stateWrapper.state, handle.UTF8String);
   } performSelector:selector onObject:object];
}

- (NSString*)selfEmail
{
  if (!self.logged_in)
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
     if (!manager.logged_in)
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
     if (!manager.logged_in)
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
     if (!manager.logged_in)
       return gap_not_logged_in;
#if TARGET_OS_IPHONE
     NSData* image_data = UIImageJPEGRepresentation(image, 0.9f);
#else
     NSData* image_data = [image TIFFRepresentation];
     NSBitmapImageRep* image_rep = [NSBitmapImageRep imageRepWithData:image_data];
     NSDictionary* image_props = [NSDictionary dictionaryWithObject:@0.9f
                                                             forKey:NSImageCompressionFactor];
     image_data = [image_rep representationUsingType:NSJPEGFileType properties:image_props];
#endif
     return gap_update_avatar(manager.stateWrapper.state, image_data.bytes, image_data.length);
   } performSelector:selector onObject:object];
}

#pragma mark - Search

- (void)userByMetaId:(NSString*)meta_id
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(NSMutableDictionary*)data
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    if (!manager.logged_in)
      return gap_not_logged_in;
    surface::gap::User res;
    gap_Status status = gap_user_by_meta_id(manager.stateWrapper.state, meta_id.UTF8String, res);
    if (status == gap_ok)
    {
      InfinitUser* user = [manager _convertUser:res];
      if (user != nil)
        data[@"user"] = user;
    }
    return gap_ok;
  } performSelector:selector onObject:object withData:data];
}

- (void)userByHandle:(NSString*)handle
     performSelector:(SEL)selector
            onObject:(id)object
            withData:(NSMutableDictionary*)data
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager.logged_in)
       return gap_not_logged_in;
     surface::gap::User res;
     gap_Status status = gap_user_by_handle(manager.stateWrapper.state, handle.UTF8String, res);
     if (status == gap_ok)
     {
       InfinitUser* user = [manager _convertUser:res];
       if (user != nil)
         data[@"user"] = user;
     }
     return status;
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
     std::vector<surface::gap::User> res_;
     gap_Status status = gap_users_search(manager.stateWrapper.state, text.UTF8String, res_);
     if (status == gap_ok)
     {
       NSMutableArray* res = [NSMutableArray array];
       for (auto const& user_: res_)
       {
         InfinitUser* user = [manager _convertUser:user_];
         if (user != nil)
           [res addObject:user];
       }
       data[@"users"] = res;
     }
     return status;
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
     std::unordered_map<std::string, surface::gap::User> res_;
     gap_Status status = gap_users_by_emails(manager.stateWrapper.state, emails_, res_);
     if (status == gap_ok)
     {
       NSMutableDictionary* res = [NSMutableDictionary dictionary];
       for (auto const& result: res_)
       {
         InfinitUser* user = [manager _convertUser:result.second];
         if (user != nil)
           res[[manager _nsString:result.first]] = user;
       }
       data[@"results"] = res;
     }
     return status;
   } performSelector:selector onObject:object withData:data];
}

#pragma mark - Crash Reporting

- (void)sendLastCrashLog:(NSString*)crash_log
            withStateLog:(NSString*)state_log
         performSelector:(SEL)selector
                onObject:(id)object
{
  __weak InfinitStateManager* weak_self = self;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    std::string username = "unknown";
    if (weak_self.current_user != nil && weak_self.current_user.length > 0)
      username = weak_self.current_user.UTF8String;
    return gap_send_last_crash_logs(manager.stateWrapper.state,
                                    username,
                                    crash_log.UTF8String,
                                    state_log.UTF8String,
                                    "");
  } performSelector:selector onObject:object];
}

- (void)reportAProblem:(NSString*)problem
               andFile:(NSString*)file
       performSelector:(SEL)selector
              onObject:(id)object
{
  __weak InfinitStateManager* weak_self = self;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     std::string username = "unknown";
     if (weak_self.current_user != nil && weak_self.current_user.length > 0)
       username = weak_self.current_user.UTF8String;
     InfinitDirectoryManager* d_manager = [InfinitDirectoryManager sharedInstance];
     std::vector<std::string> infinit_files = {
       d_manager.non_persistent_directory.UTF8String,
       d_manager.persistent_directory.UTF8String};
     return gap_send_user_report(manager.stateWrapper.state,
                                 username,
                                 problem.UTF8String,
                                 file.UTF8String,
                                 infinit_files);
   } performSelector:selector onObject:object];
}

#pragma mark - Metrics Reporting

- (void)sendMetricEvent:(NSString*)event
             withMethod:(NSString*)method
      andAdditionalData:(NSDictionary*)additional
{
  __weak InfinitStateManager* weak_self = self;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    if (additional)
    {
      return gap_send_generic_metric(manager.stateWrapper.state,
                                     event.UTF8String,
                                     method.UTF8String,
                                     [weak_self _stringDictionaryToMap:additional]);
    }
    else
    {
      return gap_send_generic_metric(manager.stateWrapper.state,
                                     event.UTF8String,
                                     method.UTF8String);
    }
  }];
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

- (std::unordered_map<std::string, std::string>)_stringDictionaryToMap:(NSDictionary*)dictionary
{
  std::unordered_map<std::string, std::string> res;
  for (NSString* key_ in dictionary.allKeys)
  {
    std::string key(key_.UTF8String);
    std::string value;
    if ([dictionary[key_] isKindOfClass:NSString.class])
      value = [dictionary[key_] UTF8String];
    else if ([dictionary[key_] isKindOfClass:NSNumber.class])
      value = [[dictionary[key_] stringValue] UTF8String];
    else
      value = "unknown";
    res[key] = value;
  }
  return res;
}

- (InfinitLinkTransaction*)_convertLinkTransaction:(surface::gap::LinkTransaction const&)transaction
{
  NSString* link = @"";
  if (transaction.link)
    link = [NSString stringWithUTF8String:transaction.link.get().c_str()];
  InfinitLinkTransaction* res =
    [[InfinitLinkTransaction alloc] initWithId:[self _numFromUint:transaction.id]
                                       meta_id:[self _nsString:transaction.meta_id]
                                        status:transaction.status
                                 sender_device:[self _nsString:transaction.sender_device_id]
                                          name:[self _nsString:transaction.name]
                                         mtime:transaction.mtime
                                          link:link
                                   click_count:[self _numFromUint:transaction.click_count]
                                       message:[self _nsString:transaction.message]
                                          size:@0];
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
                                       meta_id:[self _nsString:transaction.meta_id]
                                        status:transaction.status
                                        sender:[self _numFromUint:transaction.sender_id]
                                 sender_device:[self _nsString:transaction.sender_device_id]
                                     recipient:[self _numFromUint:transaction.recipient_id]
                              recipient_device:[self _nsString:transaction.recipient_device_id]
                                         files:files
                                         mtime:transaction.mtime
                                       message:[self _nsString:transaction.message]
                                          size:size
                                     directory:transaction.is_directory
                                      canceler:[self _nsString:transaction.canceler.user_id]];
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
                                               ghost:user.ghost
                                             meta_id:[self _nsString:user.meta_id]];
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

#pragma mark - Helpers

- (void)_clearModels
{
  [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_CLEAR_MODEL_NOTIFICATION
                                                      object:self
                                                    userInfo:nil];
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
  NSString* error = @"";
  if (!last_error.empty())
    error = [NSString stringWithUTF8String:last_error.c_str()];
  if (!status && !still_retrying)
    [InfinitStateManager sharedInstance].logged_in = NO;
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
