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
          status:(gap_TransactionStatus)status
   sender_device:(NSString*)sender_device
            name:(NSString*)name
           mtime:(NSTimeInterval)mtime
            link:(NSString*)link
     click_count:(NSNumber*)click_count
         message:(NSString*)message
            size:(NSNumber*)size
{
  if (self = [super initWithId:id_
                        status:status
                         mtime:mtime
                       message:message
                          size:size
              sender_device_id:sender_device])
  {
    _name = name;
    _link = link;
    _click_count = click_count;
  }
  return self;
}

- (void)updateWithTransaction:(InfinitLinkTransaction*)transaction
{
  [super updateWithTransaction:transaction];
  _link = [transaction.link copy];
  _click_count = [transaction.click_count copy];
}

#pragma mark - Description

- (NSString*)description
{
  return [NSString stringWithFormat:@"%@: %@", self.id_, [self statusText]];
}

@end
