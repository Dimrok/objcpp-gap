//
//  InfinitStateManager.mm
//  Infinit
//
//  Created by Christopher Crone on 23/10/14.
//  Copyright (c) 2014 Christopher Crone. All rights reserved.
//

#import "InfinitStateManager.h"
#import "InfinitStateResult.h"
#import "InfinitStateWrapper.h"

#import "InfinitPeerTransaction.h"
#import "InfinitUser.h"
#import "InfinitUserManager.h"

#import <surface/gap/gap.hh>

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("iOS.StateManager");

// Block type to queue gap operation
typedef gap_Status(^gap_operation_t)(NSOperation*);

static InfinitStateManager* _manager_instance = nil;

@implementation InfinitStateManager
{
@private
  NSOperationQueue* _queue;

  NSTimer* _poll_timer;
  BOOL _polling; // Use boolean to guard polling as NSTimer valid is iOS 8.0+.
}

- (id)init
{
  if (self = [super init])
  {
    _queue = [[NSOperationQueue alloc] init];
    _queue.maxConcurrentOperationCount = 1;
  }
  return self;
}

- (void)dealloc
{
  _polling = NO;
  [_poll_timer invalidate];
  [_queue cancelAllOperations];
}

+ (instancetype)sharedInstance
{
  if (_manager_instance == nil)
    _manager_instance = [[InfinitStateManager alloc] init];
  return _manager_instance;
}

+ (void)startState
{
  [[InfinitStateManager sharedInstance] attachCallbacks];
}

- (void)stopState
{
  [_queue cancelAllOperations];
}

+ (void)stopState
{
  [[InfinitStateManager sharedInstance] stopState];
}

- (InfinitStateWrapper*)stateWrapper
{
  return [InfinitStateWrapper sharedInstance];
}

- (void)attachCallbacks
{
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
}

//- Gap Functions ----------------------------------------------------------------------------------

- (void)login:(NSString*)email
     password:(NSString*)password
performSelector:(SEL)selector
     onObject:(id)object
{
  __weak InfinitStateManager* weak_self = self;
  [self _addOperation:^gap_Status(NSOperation* op)
    {
      if (weak_self == nil)
        return gap_error;
      gap_Status res =
        gap_login(weak_self.stateWrapper.state, email.UTF8String, password.UTF8String);
      if (res == gap_ok)
      {
        weak_self.logged_in = YES;
        [weak_self startPolling];
      }
      return res;
    } performSelector:selector onObject:object withData:nil];
}

- (void)startPolling
{
  _polling = YES;
  _poll_timer = [NSTimer timerWithTimeInterval:2.0f
                                        target:self
                                      selector:@selector(poll)
                                      userInfo:nil
                                       repeats:YES];
  if ([_poll_timer respondsToSelector:@selector(tolerance)])
  {
    _poll_timer.tolerance = 5.0;
  }
  [[NSRunLoop mainRunLoop] addTimer:_poll_timer forMode:NSDefaultRunLoopMode];
}

- (void)poll
{
  if (!_polling)
    return;
  __weak InfinitStateManager* weak_self = self;
  [self _addOperation:^gap_Status(NSOperation*)
    {
      return gap_poll(weak_self.stateWrapper.state);
    }];
}

- (InfinitUser*)userById:(NSNumber*)user_id
{
  auto user = gap_user_by_id(self.stateWrapper.state, user_id.unsignedIntValue);
  return [self convertUser:user];
}

- (NSArray*)swaggers
{
  auto swaggers_ = gap_swaggers(self.stateWrapper.state);
  NSMutableArray* res = [NSMutableArray array];
  for (auto const& swagger: swaggers_)
  {
    [res addObject:[self convertUser:swagger]];
  }
  return res;
}

//- C++ to Obj-C Conversion ------------------------------------------------------------------------

- (NSString*)nsString:(std::string const&)string
{
  return [NSString stringWithUTF8String:string.c_str()];
}

- (NSNumber*)numFromId:(uint32_t)id_
{
  return [NSNumber numberWithUnsignedInt:id_];
}

- (InfinitPeerTransaction*)convertPeerTransaction:(surface::gap::PeerTransaction const&)transaction
{
  InfinitUser* sender =
    [[InfinitUserManager sharedInstance] userWithId:[self numFromId:transaction.sender_id]];
  InfinitUser* recipient =
    [[InfinitUserManager sharedInstance] userWithId:[self numFromId:transaction.recipient_id]];
  NSMutableArray* files = [NSMutableArray array];
  NSNumber* size = [NSNumber numberWithLongLong:transaction.total_size];
  for (auto const& file: transaction.file_names)
  {
    [files addObject:[self nsString:file]];
  }
  InfinitPeerTransaction* res =
    [[InfinitPeerTransaction alloc] initWithId:[NSNumber numberWithUnsignedInt:transaction.id]
                                        status:transaction.status
                                        sender:sender
                                     recipient:recipient
                                         files:files
                                         mtime:transaction.mtime
                                       message:[self nsString:transaction.message]
                                          size:size
                                     directory:transaction.is_directory];
  return res;
}

- (InfinitUser*)convertUser:(surface::gap::User const&)user
{
  InfinitUser* res = [[InfinitUser alloc] initWithId:[NSNumber numberWithUnsignedInt:user.id]
                                              status:user.status
                                            fullname:[self nsString:user.fullname]
                                              handle:[self nsString:user.handle]
                                             deleted:user.deleted
                                               ghost:user.ghost];
  return res;
}

//- Add Operation ----------------------------------------------------------------------------------

- (void)_addOperation:(gap_operation_t)operation
{
  __block NSBlockOperation* block_operation = [NSBlockOperation blockOperationWithBlock:^(void)
    {
      if (block_operation.isCancelled)
        return;
      operation(block_operation);
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
  __block NSBlockOperation* block_operation = [NSBlockOperation blockOperationWithBlock:^(void)
   {
     if (block_operation.isCancelled)
       return;
     gap_Status result = operation(block_operation);
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

//- Callback Functions -----------------------------------------------------------------------------

static
void
on_peer_transaction(surface::gap::PeerTransaction const& transaction)
{
  std::cerr << "xxx transaction: " << transaction << std::endl;
}

static
void
on_link_transaction(surface::gap::LinkTransaction const& transaction)
{
}

static
void
on_new_swagger(surface::gap::User const& user)
{
}

static
void
on_user_status(uint32_t user_id, bool status)
{
}

@end
