//
//  InfinitLinkTransaction.m
//  Gap
//
//  Created by Christopher Crone on 13/11/14.
//
//

#import "InfinitLinkTransaction.h"

#import "InfinitStateManager.h"

@implementation InfinitLinkTransaction

- (id)initWithId:(NSNumber*)id_
         meta_id:(NSString*)meta_id
          status:(gap_TransactionStatus)status
   sender_device:(NSString*)sender_device
            name:(NSString*)name
           mtime:(NSTimeInterval)mtime
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
    _link = link;
    _click_count = click_count;
    _screenshot = screenshot;
  }
  return self;
}

- (void)updateWithTransaction:(InfinitLinkTransaction*)transaction
{
  [super updateWithTransaction:transaction];
  _link = transaction.link;
  _name = transaction.name;
  _click_count = transaction.click_count;
  _screenshot = transaction.screenshot;
}

#pragma mark - General

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
