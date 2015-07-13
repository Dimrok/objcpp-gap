//
//  InfinitLinkTransaction.m
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import "InfinitLinkTransaction.h"

#import "InfinitStateManager.h"
#import "InfinitAccountManager.h"

#undef check
#import <elle/log.hh>

ELLE_LOG_COMPONENT("Gap-ObjC++.LinkTransaction");

@interface InfinitLinkTransaction ()

@property (nonatomic, readonly) NSString* hash_str;
@property (nonatomic, readonly) NSString* meta_link;

@end

@implementation InfinitLinkTransaction

- (id)initWithId:(NSNumber*)id_
         meta_id:(NSString*)meta_id
          status:(gap_TransactionStatus)status
   sender_device:(NSString*)sender_device
            name:(NSString*)name
           mtime:(NSTimeInterval)mtime
            hash:(NSString*)hash
            link:(NSString*)link
     click_count:(NSNumber*)click_count
         message:(NSString*)message
            size:(NSNumber*)size
      screenshot:(BOOL)screenshot
{
  if (self = [super initWithId:id_
                       meta_id:meta_id
                        status:status
                         mtime:mtime
                       message:message
                          size:size
              sender_device_id:sender_device])
  {
    _name = name;
    _hash_str = hash;
    _meta_link = link;
    _click_count = click_count;
    _screenshot = screenshot;
  }
  return self;
}

- (void)updateWithTransaction:(InfinitLinkTransaction*)transaction
{
  [super updateWithTransaction:transaction];
  _hash_str = transaction->_hash_str;
  _meta_link = transaction.link;
  _name = transaction.name;
  _click_count = transaction.click_count;
  _screenshot = transaction.screenshot;
}

#pragma mark - General

- (NSString*)link
{
  InfinitAccountManager* manager = [InfinitAccountManager sharedInstance];
  if (manager.link_format.length && manager.custom_domain.length)
  {
    @try
    {
      return [NSString stringWithFormat:manager.link_format, manager.custom_domain, self.hash_str];
    }
    @catch (NSException* exception)
    {
      NSString* meta_id = self.meta_id.length ? self.meta_id : @"<nil>";
      ELLE_WARN("LinkTransaction(%s): unable to generate formatted link", meta_id.UTF8String);
    }
  }
  return self.meta_link;
}

- (BOOL)concerns_device
{
  return YES;
}

#pragma mark - Description

- (NSString*)description
{
  return [NSString stringWithFormat:@"<LinkTransaction %@ (%@): "
          "status: %@ "
          "sender device: %@ "
          "link: %@ "
          "name: %@ "
          "click count: %@ "
          "message: %@ "
          "%@ screenshot>",
          self.meta_id, self.id_, self.status_text, self.sender_device_id, self.link, self.name, self.click_count, self.message, self.screenshot ? @"is" : @"not"];
}

@end
