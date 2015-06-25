//
//  InfinitStateManager.mm
//  Infinit
//
//  Created by Christopher Crone on 23/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitStateManager.h"

#import "InfinitAccountsManager.h"
#import "InfinitAvatarManager.h"
#import "InfinitConnectionManager.h"
#import "InfinitCrashReporter.h"
#import "InfinitDevice.h"
#import "InfinitDeviceInformation.h"
#import "InfinitDirectoryManager.h"
#import "InfinitExternalAccountsManager.h"
#import "InfinitGhostCodeManager.h"
#import "InfinitLinkTransaction.h"
#import "InfinitLinkTransactionManager.h"
#import "InfinitPeerTransaction.h"
#import "InfinitPeerTransactionManager.h"
#import "InfinitStateWrapper.h"
#import "InfinitTemporaryFileManager.h"
#import "InfinitUser.h"
#import "InfinitUserManager.h"

#import <surface/gap/gap.hh>

#import "NSString+email.h"
#import "NSString+PhoneNumber.h"

#if TARGET_OS_IPHONE
# import <CoreTelephony/CTCarrier.h>
# import <CoreTelephony/CTTelephonyNetworkInfo.h>
# import <UIKit/UIImage.h>
#else
# import <AppKit/NSImage.h>
#endif

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.StateManager");

// Block type to queue gap operation
typedef gap_Status(^gap_operation_t)(InfinitStateManager*, NSOperation*);
typedef void(^gap_void_operation_t)(InfinitStateManager*, NSOperation*);

static InfinitStateManager* _manager_instance = nil;
static dispatch_once_t _instance_token = 0;
static NSNumber* _self_id = nil;
static NSString* _self_device_id = nil;
static NSString* _facebook_app_id = nil;

@interface InfinitStateManager ()

@property (nonatomic, readwrite) NSString* current_user;
@property (nonatomic, readwrite) dispatch_once_t meta_session_id_token;
@property (nonatomic, readonly) NSTimer* poll_timer;
@property (atomic, readwrite) BOOL polling; // Use boolean to guard polling as NSTimer valid is iOS 8.0+.
@property (nonatomic, readonly) NSOperationQueue* queue;

@end

@implementation InfinitStateManager

@synthesize encoded_meta_session_id = _encoded_meta_session_id;
@synthesize logged_in = _logged_in;

#pragma mark - Start

- (id)init
{
  NSCAssert(_manager_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
    _queue = [[NSOperationQueue alloc] init];
    self.queue.name = @"StateManagerQueue";
    self.queue.maxConcurrentOperationCount = 1;
    _current_user = nil;
  }
  return self;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _manager_instance = [[InfinitStateManager alloc] init];
  });
  return _manager_instance;
}

- (InfinitStateWrapper*)stateWrapper
{
  return [InfinitStateWrapper sharedInstance];
}

+ (void)startStateWithDownloadDir:(NSString*)download_dir
{
  [InfinitStateWrapper startStateWithInitialDownloadDir:download_dir];
  [[InfinitStateManager sharedInstance] _attachCallbacks];
  [InfinitCrashReporter sharedInstance];
  [InfinitConnectionManager sharedInstance];
}

+ (void)startState
{
  [InfinitStateManager startStateWithDownloadDir:nil];
}

+ (void)_startModelManagers
{
  [InfinitUserManager sharedInstance];
  [InfinitLinkTransactionManager sharedInstance];
  [InfinitPeerTransactionManager sharedInstance];
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
  if (gap_update_user_callback(self.stateWrapper.state, on_user_update) != gap_ok)
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
  if (gap_ghost_code_used_callback(self.stateWrapper.state, on_ghost_code_used) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach ghost code used callback", self.description.UTF8String);
  }
  if (gap_contact_joined_callback(self.stateWrapper.state, on_contact_joined) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach contact joined callback", self.description.UTF8String);
  }
  if (gap_external_accounts_changed_callback(
        self.stateWrapper.state, on_external_accounts_changed) != gap_ok)
  {
    ELLE_ERR("%s: unable to attach accounts changed callback", self.description.UTF8String);
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
  if (self.poll_timer)
  {
    [self.poll_timer invalidate];
    _poll_timer = nil;
  }
  self.queue.suspended = YES;
  [self.queue cancelAllOperations];
  _manager_instance = nil;
  _instance_token = 0;
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

- (NSString*)countryCode
{
#if TARGET_OS_IPHONE
  CTTelephonyNetworkInfo* network_info = [[CTTelephonyNetworkInfo alloc] init];
  CTCarrier* carrier = [network_info subscriberCellularProvider];
  return carrier.isoCountryCode.uppercaseString;
#else
  return nil;
#endif
}

- (NSString*)deviceLanguage
{
  return [NSLocale preferredLanguages].firstObject;
}

- (void)accountStatusForEmail:(NSString*)email
              completionBlock:(InfinitEmailAccountStatusBlock)completion_block
{
  [self _addOperationCustomResultBlock:^void(InfinitStateManager* manager, NSOperation* operation)
  {
    AccountStatus account_status;
    gap_Status status = gap_account_status_for_email(manager.stateWrapper.state,
                                                     email.UTF8String,
                                                     account_status);
    if (operation.cancelled)
      return;
    dispatch_async(dispatch_get_main_queue(), ^
    {
      if (completion_block)
        completion_block([InfinitStateResult resultWithStatus:status], email, account_status);
    });
  }];
}

- (gap_operation_t)operationRegisterFullname:(NSString*)fullname
                                       email:(NSString*)email
                                    password:(NSString*)password
{
  return ^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    gap_clean_state(manager.stateWrapper.state);
    [manager _clearSelf];
    [manager _startPolling];
    boost::optional<std::string> device_push_token;
    if (manager.push_token != nil && manager.push_token.length > 0)
      device_push_token = manager.push_token.UTF8String;
    boost::optional<std::string> country_code;
    if ([manager countryCode] != nil)
      country_code = std::string([manager countryCode].UTF8String);
    boost::optional<std::string> device_model;
    if ([InfinitDeviceInformation deviceModel].length)
      device_model = std::string([InfinitDeviceInformation deviceModel].UTF8String);
    boost::optional<std::string> device_name;
    if ([InfinitDeviceInformation deviceName].length)
      device_name = std::string([InfinitDeviceInformation deviceName].UTF8String);
    boost::optional<std::string> device_language;
    if ([manager deviceLanguage].length)
      device_language = std::string([manager deviceLanguage].UTF8String);
    gap_Status res = gap_register(manager.stateWrapper.state,
                                  fullname.UTF8String,
                                  email.UTF8String,
                                  password.UTF8String,
                                  device_push_token,
                                  country_code,
                                  device_model,
                                  device_name,
                                  device_language);
    if (res == gap_ok)
    {
      manager->_logged_in = YES;
      std::string self_email = gap_self_email(manager.stateWrapper.state);
      if (self_email.length() > 0)
        [manager setCurrent_user:[NSString stringWithUTF8String:self_email.c_str()]];
      else
        [manager setCurrent_user:email];
      [InfinitStateManager _startModelManagers];
      [[InfinitConnectionManager sharedInstance] setConnectedStatus:YES
                                                        stillTrying:NO
                                                          lastError:@""];
      [[InfinitCrashReporter sharedInstance] sendExistingCrashReport];
    }
    else
    {
      [manager _stopPolling];
    }
    return res;
  };
}

- (void)registerFullname:(NSString*)fullname
                   email:(NSString*)email
                password:(NSString*)password
         performSelector:(SEL)selector
                onObject:(id)object
{
  [self _addOperation:[self operationRegisterFullname:fullname email:email password:password]
      performSelector:selector
             onObject:object];
}

- (void)registerFullname:(NSString*)fullname
                   email:(NSString*)email
                password:(NSString*)password
         completionBlock:(InfinitStateCompletionBlock)completion_block
{
  [self _addOperation:[self operationRegisterFullname:fullname email:email password:password]
      completionBlock:completion_block];
}

- (void)plainInviteContact:(NSString*)contact
           completionBlock:(InfinitPlainInviteBlock)completion_block
{
  if (!contact.length)
    return;
  if (!contact.infinit_isEmail && !contact.infinit_isPhoneNumber)
  {
    if (completion_block)
      completion_block([InfinitStateResult resultWithStatus:gap_bad_request], nil, nil, nil);
  }
  [self _addOperationCustomResultBlock:^(InfinitStateManager* manager, NSOperation* operation)
  {
    surface::gap::PlainInvitation res;
    gap_Status status = gap_plain_invite_contact(manager.stateWrapper.state,
                                                 contact.UTF8String,
                                                 res);
    if (operation.isCancelled)
      return;
    dispatch_async(dispatch_get_main_queue(), ^
    {
      if (completion_block)
      {
        completion_block([InfinitStateResult resultWithStatus:status],
                         contact,
                         [manager _nsString:res.ghost_code],
                         [manager _nsString:res.ghost_profile_url]);
      }
    });
  }];
}

- (void)ghostCodeExists:(NSString*)code
        completionBlock:(InfinitGhostCodeExistsBlock)completion_block
{
  [self _addOperationCustomResultBlock:^(InfinitStateManager* manager, NSOperation* operation)
  {
    bool res = NO;
    gap_Status status = gap_check_ghost_code(manager.stateWrapper.state, code.UTF8String, res);
    if (operation.isCancelled)
      return;

    dispatch_async(dispatch_get_main_queue(), ^
    {
      if (completion_block)
        completion_block([InfinitStateResult resultWithStatus:status], code, res);
    });
  }];
}

- (void)useGhostCode:(NSString*)code
             wasLink:(BOOL)link
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    return gap_use_ghost_code(manager.stateWrapper.state, code.UTF8String, link);
  }];
}

- (void)_ghostCodeUsedCallback:(std::string const&)code
                       success:(bool)success
                        reason:(std::string const&)reason
{
  [[InfinitGhostCodeManager sharedInstance] ghostCodeUsed:[self _nsString:code]
                                                  success:success 
                                                   reason:[self _nsString:reason]];
}

- (void)addFingerprint:(NSString*)fingerprint
{
  if (!fingerprint.length)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    return gap_add_fingerprint(manager.stateWrapper.state, fingerprint.UTF8String);
  }];
}

- (gap_operation_t)operationLogin:(NSString*)email
                         password:(NSString*)password
{
  return ^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    gap_clean_state(manager.stateWrapper.state);
    [manager _clearSelf];
    [manager _startPolling];
    boost::optional<std::string> device_push_token;
    if (manager.push_token.length)
      device_push_token = manager.push_token.UTF8String;
    boost::optional<std::string> country_code;
    if ([manager countryCode] != nil)
      country_code = std::string([manager countryCode].UTF8String);
    boost::optional<std::string> device_model;
    if ([InfinitDeviceInformation deviceModel].length)
      device_model = std::string([InfinitDeviceInformation deviceModel].UTF8String);
    boost::optional<std::string> device_name;
    if ([InfinitDeviceInformation deviceName].length)
      device_name = std::string([InfinitDeviceInformation deviceName].UTF8String);
    boost::optional<std::string> device_language;
    if ([manager deviceLanguage].length)
      device_language = std::string([manager deviceLanguage].UTF8String);
    gap_Status res = gap_login(manager.stateWrapper.state,
                               email.UTF8String,
                               password.UTF8String,
                               device_push_token,
                               country_code,
                               device_model,
                               device_name,
                               device_language);
    if (res == gap_ok)
    {
      manager->_logged_in = YES;
      std::string self_email = gap_self_email(manager.stateWrapper.state);
      if (self_email.length() > 0)
        [manager setCurrent_user:[NSString stringWithUTF8String:self_email.c_str()]];
      else
        [manager setCurrent_user:email];
      [InfinitStateManager _startModelManagers];
      [[InfinitConnectionManager sharedInstance] setConnectedStatus:YES
                                                        stillTrying:NO
                                                          lastError:@""];
      [[InfinitCrashReporter sharedInstance] sendExistingCrashReport];
    }
    else
    {
      [manager _stopPolling];
    }
    return res;
  };
}

- (void)login:(NSString*)email
     password:(NSString*)password
performSelector:(SEL)selector
     onObject:(id)object
{
  [self _addOperation:[self operationLogin:email password:password]
      performSelector:selector
             onObject:object];
}

- (void)login:(NSString*)email
     password:(NSString*)password
completionBlock:(InfinitStateCompletionBlock)completion_block
{
  [self _addOperation:[self operationLogin:email password:password]
      completionBlock:completion_block];
}

- (void)webLoginTokenWithCompletionBlock:(InfinitWebLoginTokenBlock)completion_block
{
  [self _addOperationCustomResultBlock:^void(InfinitStateManager* manager, NSOperation* operation)
  {
    std::string token;
    gap_Status status = gap_web_login_token(manager.stateWrapper.state, token);
    if (operation.isCancelled || !completion_block)
      return;
    completion_block([InfinitStateResult resultWithStatus:status], [manager _nsString:token]);
  }];
}

- (void)userRegisteredWithFacebookId:(NSString*)facebook_id
                     performSelector:(SEL)selector
                            onObject:(id)object
                            withData:(NSMutableDictionary*)data
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    bool registered;
    gap_Status status = gap_facebook_already_registered(manager.stateWrapper.state,
                                                        facebook_id.UTF8String,
                                                        registered);
    [data setObject:@(registered) forKey:@"registered"];
    return status;
  } performSelector:selector onObject:object withData:data];
}

- (void)userRegisteredWithFacebookId:(NSString*)facebook_id
                     completionBlock:(InfinitFacebookUserRegistered)completion_block
{
  [self _addOperationCustomResultBlock:^void(InfinitStateManager* manager, NSOperation* operation)
  {
    bool registered;
    gap_Status status = gap_facebook_already_registered(manager.stateWrapper.state,
                                                        facebook_id.UTF8String,
                                                        registered);
    if (operation.isCancelled)
      return;

    dispatch_async(dispatch_get_main_queue(), ^
    {
      if (completion_block)
        completion_block([InfinitStateResult resultWithStatus:status], registered);
    });
  }];
}

- (NSString*)facebookApplicationId
{
  if (_facebook_app_id == nil)
    _facebook_app_id = [NSString stringWithUTF8String:gap_facebook_app_id().c_str()];
  return _facebook_app_id;
}

- (gap_operation_t)operationFacebookConnect:(NSString*)facebook_token
                                      email:(NSString*)email;
{
  return ^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    gap_clean_state(manager.stateWrapper.state);
    [manager _clearSelf];
    [manager _startPolling];
    boost::optional<std::string> preferred_email;
    if (email && email.length > 0)
      preferred_email = email.UTF8String;
    boost::optional<std::string> device_push_token;
    if (manager.push_token && manager.push_token.length > 0)
      device_push_token = manager.push_token.UTF8String;
    boost::optional<std::string> country_code;
    if ([manager countryCode] != nil)
      country_code = std::string([manager countryCode].UTF8String);
    boost::optional<std::string> device_model;
    if ([InfinitDeviceInformation deviceModel].length)
      device_model = std::string([InfinitDeviceInformation deviceModel].UTF8String);
    boost::optional<std::string> device_name;
    if ([InfinitDeviceInformation deviceName].length)
      device_name = std::string([InfinitDeviceInformation deviceName].UTF8String);
    boost::optional<std::string> device_language;
    if ([manager deviceLanguage].length)
      device_language = std::string([manager deviceLanguage].UTF8String);
    gap_Status res = gap_facebook_connect(manager.stateWrapper.state,
                                          facebook_token.UTF8String,
                                          preferred_email,
                                          device_push_token,
                                          country_code,
                                          device_model,
                                          device_name,
                                          device_language);
    if (res == gap_ok)
    {
      manager->_logged_in = YES;
      std::string self_email = gap_self_email(manager.stateWrapper.state);
      if (self_email.length() > 0)
        [manager setCurrent_user:[NSString stringWithUTF8String:self_email.c_str()]];
      else if (email.length > 0)
        [manager setCurrent_user:email];
      else
        [manager setCurrent_user:@"unknown facebook"];
      [InfinitStateManager _startModelManagers];
      [[InfinitConnectionManager sharedInstance] setConnectedStatus:YES
                                                        stillTrying:NO
                                                          lastError:@""];
      [[InfinitCrashReporter sharedInstance] sendExistingCrashReport];
    }
    else
    {
      [manager _stopPolling];
    }
    return res;
  };
}

- (void)facebookConnect:(NSString*)facebook_token
           emailAddress:(NSString*)email
        performSelector:(SEL)selector
               onObject:(id)object
{
  [self _addOperation:[self operationFacebookConnect:facebook_token email:email]
      performSelector:selector
             onObject:object];
}

- (void)facebookConnect:(NSString*)facebook_token
           emailAddress:(NSString*)email
        completionBlock:(InfinitStateCompletionBlock)completion_block
{
  [self _addOperation:[self operationFacebookConnect:facebook_token email:email]
      completionBlock:completion_block];
}

- (void)addFacebookAccount:(NSString*)facebook_token
{
  if (!facebook_token.length)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    return gap_add_facebook_account(manager.stateWrapper.state, facebook_token.UTF8String);
  }];
}

- (void)cancelAllOperationsExcluding:(NSOperation*)exclude
{
  for (NSOperation* operation in _queue.operations)
  {
    if (![operation isEqual:exclude])
      [operation cancel];
  }
}

- (gap_operation_t)operationLogout
{
  return ^gap_Status(InfinitStateManager* manager, NSOperation* operation)
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:INFINIT_WILL_LOGOUT_NOTIFICATION
                                                        object:nil];
    [manager cancelAllOperationsExcluding:operation];
    [manager _clearSelfAndModel:YES];
    [manager _stopPolling];
    manager->_logged_in = NO;
    manager->_encoded_meta_session_id = nil;
    manager.meta_session_id_token = 0;
    gap_Status res = gap_logout(manager.stateWrapper.state);
    return res;
  };
}

- (void)logoutPerformSelector:(SEL)selector
                     onObject:(id)object
{
  [self _addOperation:[self operationLogout] performSelector:selector onObject:object];
}

- (void)logoutWithCompletionBlock:(InfinitStateCompletionBlock)completion_block
{
  [self _addOperation:[self operationLogout] completionBlock:completion_block];
}

- (NSString*)encoded_meta_session_id
{
  dispatch_once(&_meta_session_id_token, ^
  {
    std::string res;
    gap_Status status = gap_session_id(self.stateWrapper.state, res);
    if (status == gap_ok)
    {
      _encoded_meta_session_id =
        [[self _nsString:res] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    else
    {
      self.meta_session_id_token = 0;
    }
  });
  return _encoded_meta_session_id;
}

#pragma mark - Local Contacts

- (void)uploadContacts:(NSArray*)contacts_
       completionBlock:(InfinitStateCompletionBlock)completion_block
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    if (!manager.logged_in)
      return gap_not_logged_in;
    std::vector<AddressBookContact> contacts;
    for (NSDictionary* contact_ in contacts_)
    {
      AddressBookContact contact;
      contact.phone_numbers = [manager _strVectorFromNSArray:contact_[@"phone_numbers"]];
      contact.email_addresses = [manager _strVectorFromNSArray:contact_[@"email_addresses"]];
      contacts.push_back(contact);
    }
    return gap_upload_address_book(manager.stateWrapper.state, contacts);
  } completionBlock:completion_block];
}

#pragma mark - Device

- (void)updateDeviceName:(NSString*)name_
                   model:(NSString*)model_
                      os:(NSString*)os_
         completionBlock:(InfinitStateCompletionBlock)completion_block
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    if (!manager.logged_in)
      return gap_not_logged_in;
    boost::optional<std::string> name;
    if (name_.length)
      name = std::string(name_.UTF8String);
    boost::optional<std::string> model;
    if (model_.length)
      model = std::string(model_.UTF8String);
    boost::optional<std::string> os;
    if (os_.length)
      os = std::string(os_.UTF8String);
    return gap_update_device(manager.stateWrapper.state, name, model, os);
  } completionBlock:completion_block];
}

#pragma mark - Polling

- (void)_startPolling
{
  if (self.polling)
    return;
  self.polling = YES;
  _poll_timer = [NSTimer timerWithTimeInterval:1.0f
                                        target:self
                                      selector:@selector(_poll)
                                      userInfo:nil
                                       repeats:YES];
  if ([self.poll_timer respondsToSelector:@selector(tolerance)])
  {
    self.poll_timer.tolerance = 1.0f;
  }
  [[NSRunLoop mainRunLoop] addTimer:self.poll_timer forMode:NSDefaultRunLoopMode];
}

- (void)_stopPolling
{
  self.polling = NO;
  if (self.poll_timer)
    [self.poll_timer invalidate];
  _poll_timer = nil;
}

- (void)_poll
{
  if (!self.polling)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    if (!manager.polling)
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
  {
    ELLE_ERR("%s: asked for user that doesn't exist: %s",
             self.description.UTF8String, [NSThread callStackSymbols].description.UTF8String);
    return nil;
  }
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
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager.logged_in)
       return gap_not_logged_in;
     return gap_favorite(manager.stateWrapper.state, user.id_.unsignedIntValue);
   }];
}

- (void)removeFavorite:(InfinitUser*)user
{
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
  {
    NSNumber* fetched_id = [self _numFromUint:gap_self_id(self.stateWrapper.state)];
    if (fetched_id.unsignedIntValue == 0)
    {
      ELLE_ERR("%s: got null_id when fetching self from state", self.description.UTF8String);
      return fetched_id;
    }
    _self_id = fetched_id;
  }
  return _self_id;
}

- (NSString*)self_device_id
{
  if (_self_device_id == nil)
    _self_device_id = [self _nsString:gap_self_device_id(self.stateWrapper.state)];
  return _self_device_id;
}

- (INFINIT_IMAGE*)avatarForUserWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return nil;
  void* gap_data;
  size_t size;
  gap_Status status = gap_avatar(self.stateWrapper.state, id_.unsignedIntValue, &gap_data, &size);
  INFINIT_IMAGE* res = nil;
  if (status == gap_ok && size > 0)
  {
    NSData* data = [[NSData alloc] initWithBytes:gap_data length:size];
#if TARGET_OS_IPHONE
    res = [UIImage imageWithData:data];
#else
    res = [[NSImage alloc] initWithData:data];
#endif
  }
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
                     withMessage:(NSString*)message_
                    isScreenshot:(BOOL)screenshot
{
  if (!self.logged_in)
    return nil;
  NSString* message = message_;
  if (message == nil)
    message = @"";
  uint32_t res = gap_create_link_transaction(self.stateWrapper.state,
                                             [self _filesVectorFromNSArray:files],
                                             message.UTF8String,
                                             screenshot);
  return [self _numFromUint:res];
}

- (void)deleteTransactionWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    return gap_delete_transaction(manager.stateWrapper.state, id_.unsignedIntValue);
  }];
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
  NSArray* sorted_files =
    [files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  std::vector<std::string> files_ = [self _filesVectorFromNSArray:sorted_files];
  if ([recipient isKindOfClass:InfinitUser.class])
  {
    InfinitUser* user = recipient;
    res = gap_send_files(self.stateWrapper.state,
                         user.id_.unsignedIntValue,
                         files_,
                         message.UTF8String);
  }
  else if ([recipient isKindOfClass:InfinitDevice.class])
  {
    InfinitDevice* device = recipient;
    InfinitUser* me = [InfinitUserManager sharedInstance].me;
    std::string device_id(device.id_.UTF8String);
    res = gap_send_files(self.stateWrapper.state,
                         me.id_.unsignedIntValue,
                         files_,
                         message.UTF8String,
                         device_id);
  }
  else if ([recipient isKindOfClass:NSString.class])
  {
    NSString* email = recipient;
    res = gap_send_files(self.stateWrapper.state,
                         email.UTF8String,
                         files_,
                         message.UTF8String);
  }
  return [self _numFromUint:res];
}

- (NSNumber*)sendFiles:(NSArray*)files
           toRecipient:(InfinitUser*)recipient
              onDevice:(NSString*)device_id
           withMessage:(NSString*)message
{
  if (!self.logged_in)
    return nil;
  uint32_t res = 0;
  std::string device_id_(device_id.UTF8String);
  NSArray* sorted_files =
    [files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  res = gap_send_files(self.stateWrapper.state,
                       recipient.id_.unsignedIntValue,
                       [self _filesVectorFromNSArray:sorted_files],
                       message.UTF8String,
                       device_id_);
  return [self _numFromUint:res];
}

- (void)acceptTransactionWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    return gap_accept_transaction(manager.stateWrapper.state, id_.unsignedIntValue);
  }];
}

- (void)rejectTransactionWithId:(NSNumber*)id_
{
  if (!self.logged_in)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    return gap_reject_transaction(manager.stateWrapper.state, id_.unsignedIntValue);
  }];
}

#pragma mark - Connection Status

- (void)setNetworkConnectionStatus:(InfinitNetworkStatuses)status
{
  bool connected = false;
#if TARGET_OS_IPHONE
  if (status == InfinitNetworkStatusReachableViaLAN ||
      status == InfinitNetworkStatusReachableViaWWAN)
#else
  if (status == InfinitNetworkStatusReachableViaLAN)
#endif
  {
    connected = true;
  }
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    return gap_internet_connection(manager.stateWrapper.state, connected);
  }];
}

#pragma mark - Devices

- (NSArray*)devices
{
  if (!self.logged_in)
    return nil;
  std::vector<surface::gap::Device const*> devices_;
  gap_Status status = gap_devices(self.stateWrapper.state, devices_);
  NSMutableArray* res = [NSMutableArray array];
  if (status == gap_ok)
  {
    for (auto const& device: devices_)
      [res addObject:[self _convertDevice:device]];
  }
  return res;
}

#pragma mark - External Accounts

- (void)_externalAccountsChanged:(std::vector<ExternalAccount const*>)accounts
{
  NSMutableArray* res = [NSMutableArray array];
  for (auto account_: accounts)
  {
    InfinitExternalAccount* account = [self _convertExternalAccount:*account_];
    if (account)
      [res addObject:account];
  }
  [[InfinitExternalAccountsManager sharedInstance] accountsUpdated:res];
}

#pragma mark - Features

- (NSDictionary*)features
{
  if (!self.logged_in)
    return nil;
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
      [manager _updateUser:res];
      data[kInfinitUserId] = [manager _numFromUint:res.id];
    }
    return gap_ok;
  } performSelector:selector onObject:object withData:data];
}

- (void)userByEmail:(NSString*)email
    performSelector:(SEL)selector
           onObject:(id)object
           withData:(NSMutableDictionary*)data
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     if (!manager.logged_in)
       return gap_not_logged_in;
     surface::gap::User res;
     gap_Status status = gap_user_by_email(manager.stateWrapper.state, email.UTF8String, res);
     if (status == gap_ok)
     {
       [manager _updateUser:res];
       data[kInfinitUserId] = [manager _numFromUint:res.id];
     }
     else
     {
       data[kInfinitUserId] = @0;
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
       [manager _updateUser:res];
       data[kInfinitUserId] = [manager _numFromUint:res.id];
     }
     else
     {
       data[kInfinitUserId] = @0;
     }
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
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    std::string username = "unknown";
    if (manager.current_user != nil && manager.current_user.length > 0)
      username = manager.current_user.UTF8String;
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
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
   {
     std::string username = "unknown";
     if (manager.current_user != nil && manager.current_user.length > 0)
       username = manager.current_user.UTF8String;
     std::vector<std::string> files;
     if (file && [[NSFileManager defaultManager] fileExistsAtPath:file])
       files.push_back(file.UTF8String);
     return gap_send_user_report(manager.stateWrapper.state,
                                 username,
                                 problem.UTF8String,
                                 files);
   } performSelector:selector onObject:object];
}

#pragma mark - Metrics Reporting

- (void)sendMetricEvent:(NSString*)event
             withMethod:(NSString*)method
      andAdditionalData:(NSDictionary*)additional_
{
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    std::unordered_map<std::string, std::string> additional = {};
    if (additional_)
      additional = [manager _stringDictionaryToMap:additional_];
    return gap_send_generic_metric(manager.stateWrapper.state,
                                   event.UTF8String,
                                   method.UTF8String,
                                   additional);
  }];
}

- (void)sendMetricInviteSent:(BOOL)success
                        code:(NSString*)code
                      method:(gap_InviteMessageMethod)method
                  failReason:(NSString*)fail_reason_
{
  if (!code.length)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    std::string fail_reason = fail_reason_.length ? std::string(fail_reason_.UTF8String) : "";
    return gap_invitation_message_sent_metric(manager.stateWrapper.state,
                                              success,
                                              code.UTF8String,
                                              method,
                                              fail_reason);
  }];
}

- (void)sendMetricGhostSMSSent:(BOOL)success
                          code:(NSString*)code
                    failReason:(NSString*)fail_reason_
{
  if (!code.length)
    return;
  [self _addOperation:^gap_Status(InfinitStateManager* manager, NSOperation*)
  {
    std::string fail_reason = fail_reason_.length ? std::string(fail_reason_.UTF8String) : "";
    return gap_invitation_message_sent_metric(manager.stateWrapper.state,
                                              success,
                                              code.UTF8String,
                                              gap_invite_message_native,
                                              fail_reason);
  }];
}

#pragma mark - Proxy

- (void)setProxy:(gap_ProxyType)type
            host:(NSString*)host
            port:(UInt16)port
        username:(NSString*)username
        password:(NSString*)password
{
  gap_set_proxy(self.stateWrapper.state, type, host.UTF8String, port,
                username.UTF8String, password.UTF8String);
}

- (void)unsetProxy:(gap_ProxyType)type
{
  gap_unset_proxy(self.stateWrapper.state, type);
}

#pragma mark - Download Directory

- (void)setDownloadDirectory:(NSString*)download_dir
                    fallback:(BOOL)fallback
{
  gap_set_output_dir(self.stateWrapper.state, download_dir.UTF8String, fallback);
}

#pragma mark - Conversions

- (InfinitDevice*)_convertDevice:(surface::gap::Device const*)device
{
  InfinitDevice* res = [[InfinitDevice alloc] initWithId:[self _nsString:device->id.repr()]
                                                    name:[self _nsString:device->name]
                                                      os:[self _nsStringOptional:device->os]
                                                   model:[self _nsStringOptional:device->model]];
  return res;
}

- (std::vector<std::string>)_strVectorFromNSArray:(NSArray*)array
{
  std::vector<std::string> res;
  for (NSString* element in array)
  {
    if (element.length)
      res.push_back(element.UTF8String);
  }
  return res;
}

- (std::vector<std::string>)_filesVectorFromNSArray:(NSArray*)array
{
  std::vector<std::string> res;
  for (NSString* element in array)
  {
    if (element.length)
      res.push_back(element.fileSystemRepresentation);
  }
  return res;
}

- (NSString*)_nsString:(std::string const&)string
{
  if (string.length())
    return [NSString stringWithUTF8String:string.c_str()];
  return @"";
}

- (NSString*)_nsStringOptional:(boost::optional<std::string>)optional
{
  if (optional)
    return [self _nsString:optional.get()];
  return @"";
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
  NSNumber* size = [NSNumber numberWithUnsignedLong:transaction.size];
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
                                          size:size
                                    screenshot:transaction.screenshot];
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
  if (user.id == gap_null())
    return [InfinitUser initNullUser];
  InfinitUser* res = [[InfinitUser alloc] initWithId:[self _numFromUint:user.id]
                                              status:user.status
                                            fullname:[self _nsString:user.fullname]
                                              handle:[self _nsString:user.handle]
                                             swagger:user.swagger
                                             deleted:user.deleted
                                               ghost:user.ghost
                                           ghostCode:[self _nsString:user.ghost_code]
                                  ghostInvitationURL:[self _nsString:user.ghost_invitation_url]
                                             meta_id:[self _nsString:user.meta_id]
                                         phoneNumber:[self _nsString:user.phone_number]];
  return res;
}

- (InfinitExternalAccount*)_convertExternalAccount:(ExternalAccount const&)account
{
  return [InfinitExternalAccount accountOfType:[self _nsString:account.type]
                                withIdentifier:[self _nsString:account.id]];
}

#pragma mark - Operations

- (void)_addOperation:(gap_operation_t)operation
{
  [self _addOperation:operation performSelector:NULL onObject:nil withData:nil];
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
  __weak typeof(self) weak_self = self;
  __block NSBlockOperation* block_operation = [NSBlockOperation blockOperationWithBlock:^(void)
   {
     InfinitStateManager* strong_self = weak_self;
     if (!strong_self)
       return;
     if (block_operation.isCancelled)
     {
       ELLE_LOG("%s: cancelled operation: %s.%s",
                self.description.UTF8String,
                [object description].UTF8String,
                NSStringFromSelector(selector).UTF8String);
       return;
     }
     gap_Status result = operation(strong_self, block_operation);
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
     if (object && selector)
     {
       [object performSelectorOnMainThread:selector
                                withObject:operation_result
                             waitUntilDone:NO];
     }
   }];
  [_queue addOperation:block_operation];
}

- (void)_addOperation:(gap_operation_t)operation
      completionBlock:(InfinitStateCompletionBlock)completion_block
{
  [self _addOperation:operation withData:nil completionBlock:completion_block];
}

- (void)_addOperation:(gap_operation_t)operation
             withData:(id)data
      completionBlock:(InfinitStateCompletionBlock)completion_block
{
  __weak typeof(self) weak_self = self;
  __block NSBlockOperation* block_operation = [NSBlockOperation blockOperationWithBlock:^(void)
  {
    InfinitStateManager* strong_self = weak_self;
    if (!strong_self)
      return;
    if (block_operation.isCancelled)
    {
      ELLE_LOG("%s: cancelled operation", self.description.UTF8String);
      return;
    }
    gap_Status result = operation(strong_self, block_operation);
    InfinitStateResult* operation_result = [[InfinitStateResult alloc] initWithStatus:result
                                                                              andData:data];
    if (block_operation.isCancelled)
    {
      ELLE_LOG("%s: cancelled operation", self.description.UTF8String);
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^
    {
      if (completion_block)
        completion_block(operation_result);
    });
  }];
  [_queue addOperation:block_operation];
}

- (void)_addOperationCustomResultBlock:(gap_void_operation_t)operation
{
  __weak typeof(self) weak_self = self;
  __block NSBlockOperation* block_operation = [NSBlockOperation blockOperationWithBlock:^(void)
  {
    InfinitStateManager* strong_self = weak_self;
    if (!strong_self)
      return;
    if (block_operation.isCancelled)
    {
      ELLE_LOG("%s: cancelled operation", self.description.UTF8String);
      return;
    }
    operation(strong_self, block_operation);
    if (block_operation.isCancelled)
    {
      ELLE_LOG("%s: cancelled operation", self.description.UTF8String);
      return;
    }
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
  @try
  {
    NSString* error = @"";
    if (!last_error.empty())
      error = [NSString stringWithUTF8String:last_error.c_str()];
    if (!status && !still_retrying)
    {
      InfinitStateManager* manager = [InfinitStateManager sharedInstance];
      manager->_logged_in = NO;
      manager->_meta_session_id_token = 0;
      manager->_encoded_meta_session_id = nil;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)),
                     dispatch_get_main_queue(), ^
      {
        [[InfinitStateManager sharedInstance] _clearSelfAndModel:YES];
      });
    }
    [[InfinitConnectionManager sharedInstance] setConnectedStatus:status
                                                      stillTrying:still_retrying
                                                        lastError:error];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_connection_callback exception: %s", e.description.UTF8String);
    @throw e;
  }
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
  @try
  {
    [[InfinitStateManager sharedInstance] _peerTransactionUpdated:transaction];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_peer_transaction exception: %s", e.description.UTF8String);
    @throw e;
  }
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
  @try
  {
    [[InfinitStateManager sharedInstance] _linkTransactionUpdated:transaction];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_link_transaction exception: %s", e.description.UTF8String);
    @throw e;
  }
}

- (void)_updateUser:(surface::gap::User const&)user_
{
  InfinitUser* user = [self _convertUser:user_];
  [[InfinitUserManager sharedInstance] updateUser:user];
}

static
void
on_user_update(surface::gap::User const& user)
{
  @try
  {
    [[InfinitStateManager sharedInstance] _updateUser:user];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_user_update exception: %s", e.description.UTF8String);
    @throw e;
  }
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
  @try
  {
    [[InfinitStateManager sharedInstance] _userWithId:user_id statusUpdated:status];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_user_status exception: %s", e.description.UTF8String);
    @throw e;
  }
}

- (void)_userDeleted:(uint32_t)user_id
{
  [[InfinitUserManager sharedInstance] userDeletedWithId:[self _numFromUint:user_id]];
}

static
void
on_deleted_favorite(uint32_t user_id)
{
  @try
  {
    [[InfinitStateManager sharedInstance] _userDeleted:user_id];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_deleted_favorite exception: %s", e.description.UTF8String);
    @throw e;
  }
}

static
void
on_deleted_swagger(uint32_t user_id)
{
  @try
  {
    [[InfinitStateManager sharedInstance] _userDeleted:user_id];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_deleted_swagger exception: %s", e.description.UTF8String);
    @throw e;
  }
}

- (void)_contactJoined:(uint32_t)user_id
               contact:(std::string const&)contact
{
  [[InfinitUserManager sharedInstance] contactJoined:[self _numFromUint:user_id]
                                             contact:[self _nsString:contact]];
}

static
void
on_contact_joined(uint32_t user_id, std::string const& contact)
{
  @try
  {
    [[InfinitStateManager sharedInstance] _contactJoined:user_id contact:contact];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_contact_joined exception: %s", e.description.UTF8String);
    @throw e;
  }
}

- (void)_gotAvatarForUserWithId:(uint32_t)user_id
{
  [[InfinitAvatarManager sharedInstance] gotAvatarForUserWithId:[self _numFromUint:user_id]];
}

static
void
on_avatar(uint32_t user_id)
{
  @try
  {
    [[InfinitStateManager sharedInstance] _gotAvatarForUserWithId:user_id];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_avatar exception: %s", e.description.UTF8String);
    @throw e;
  }
}

static
void
on_ghost_code_used(std::string const& code, bool succeeded, std::string const& reason)
{
  @try
  {
    [[InfinitStateManager sharedInstance] _ghostCodeUsedCallback:code
                                                         success:succeeded 
                                                          reason:reason];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_ghost_code_used exception: %s", e.description.UTF8String);
    @throw e;
  }
}

static
void
on_accounts_changed(std::vector<Account const*> accounts)
{
  @try
  {
    [[InfinitStateManager sharedInstance] _externalAccountsChanged:accounts];
  }
  @catch (NSException* e)
  {
    ELLE_ERR("on_external_accounts_changed exception: %s", e.description.UTF8String);
    @throw e;
  }
}

@end
