//
//  NSNotificationCenter+Debug.m
//  Gap
//
//  Created by Christopher Crone on 01/06/15.
//
//

#if DEBUG

# import "NSNotificationCenter+Debug.h"

# import "InfinitSwizzler.h"
# import "InfinitThreadSafeDictionary.h"

# import <objc/runtime.h>

static dispatch_once_t _load_token = 0;
static InfinitThreadSafeDictionary* _observer_map;

@implementation NSNotificationCenter (infinit_Debug)

+ (void)load
{
  dispatch_once(&_load_token, ^
  {
    SEL original_add_observer_sel = @selector(addObserver:selector:name:object:);
    SEL swizzled_add_observer_sel = @selector(infinit_addObserver:selector:name:object:);
    swizzle_class_selector(self.class, original_add_observer_sel, swizzled_add_observer_sel);

    SEL original_post_sel = @selector(postNotificationName:object:userInfo:);
    SEL swizzled_post_sel = @selector(infinit_postNotificationName:object:userInfo:);
    swizzle_class_selector(self.class, original_post_sel, swizzled_post_sel);
    _observer_map =
      [InfinitThreadSafeDictionary dictionaryWithName:@"io.Infinit.NSNotificationCenter-Observers"
                                       withNilSupport:YES];
    SEL original_remove_observer_name_sel = @selector(removeObserver:name:object:);
    SEL swizzled_remove_observer_name_sel = @selector(infinit_removeObserver:name:object:);
    swizzle_class_selector(self.class,
                           original_remove_observer_name_sel, swizzled_remove_observer_name_sel);
    SEL original_remove_observer_sel = @selector(removeObserver:);
    SEL swizzled_remove_observer_sel = @selector(infinit_removeObserver:);
    swizzle_class_selector(self.class, original_remove_observer_sel, swizzled_remove_observer_sel);
  });
}

- (NSArray*)observersForNotificationWithName:(NSString*)name
{
  return _observer_map[name];
}

# pragma mark - Swizzled

- (void)infinit_addObserver:(id)observer
                   selector:(SEL)aSelector
                       name:(NSString*)aName
                     object:(id)anObject
{
  [self infinit_addObserver:observer selector:aSelector name:aName object:anObject];
  NSMutableArray* observers = _observer_map[aName];
  if (!observers)
    observers = [NSMutableArray array];
  __weak id weak_observer = observer;
  [observers addObject:weak_observer];
  _observer_map[aName] = observers;
}

- (void)infinit_postNotificationName:(NSString*)aName
                              object:(id)anObject
                            userInfo:(NSDictionary*)aUserInfo
{
  [self infinit_postNotificationName:aName object:anObject userInfo:aUserInfo];
  if ([aName rangeOfString:@"INFINIT"].location != NSNotFound)
  {
    for (id observer in _observer_map[aName])
    {
      if (observer == nil)
        NSLog(@"WARNING: nil observer when posting %@, will cause production crash", aName);
    }
  }
}

- (void)infinit_removeObserver:(id)observer
                          name:(NSString*)aName
                        object:(id)anObject
{
  [self infinit_removeObserver:observer name:aName object:anObject];
  if (aName == nil)
    return;
  NSMutableArray* observers = _observer_map[aName];
  [observers removeObject:observer];
  if (observers.count == 0)
    [_observer_map removeObjectForKey:aName];
}

- (void)infinit_removeObserver:(id)observer
{
  [self infinit_removeObserver:observer];
  NSMutableArray* empty = [NSMutableArray array];
  for (NSString* name in _observer_map.allKeys)
  {
    NSMutableArray* observers = _observer_map[name];
    if ([observers containsObject:observer])
    {
      [observers removeObject:observer];
      if (observers.count == 0)
        [empty addObject:name];
    }
  }
  for (NSString* name in empty)
    [_observer_map removeObjectForKey:name];
}

@end

#endif
