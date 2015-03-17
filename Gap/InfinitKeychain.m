//
//  InfinitKeychain.m
//  Infinit
//
//  Created by Christopher Crone on 14/01/15.
//  Copyright (c) 2015 Infinit. All rights reserved.
//

#import "InfinitKeychain.h"

#import <Security/Security.h>

static InfinitKeychain* _instance = nil;
static NSString* _service_name = @"Infinit";

@implementation InfinitKeychain

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {
  }
  return self;
}

+ (instancetype)sharedInstance
{
  if (_instance == nil)
    _instance = [[InfinitKeychain alloc] init];
  return _instance;
}

#pragma mark - Keychain Operations

- (BOOL)addPassword:(NSString*)password
         forAccount:(NSString*)account
{
  if (account == nil || account.length == 0)
    return NO;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  dict[(__bridge id)kSecValueData] = [self encodeString:password];
  OSStatus status = SecItemAdd((__bridge_retained CFDictionaryRef)dict, NULL);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to add item: %d", (int)status);
#else
    NSLog(@"Unable to add item: %@", (__bridge NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return NO;
  }
  return YES;
}

- (BOOL)credentialsForAccountInKeychain:(NSString*)account
{
  if (account == nil || account.length == 0)
    return NO;
  if ([self passwordForAccount:account] == nil)
    return NO;
  return YES;
}

- (NSString*)passwordForAccount:(NSString*)account
{
  if (account == nil || account.length == 0)
    return nil;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  dict[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  dict[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
  CFTypeRef result = NULL;
  OSStatus status = SecItemCopyMatching((__bridge_retained CFDictionaryRef)dict, &result);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to find password for account (%@): %d", account, (int)status);
#else
    NSLog(@"Unable to find password for account (%@): %@",
          account, (__bridge NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return nil;
  }
  return [self decodeString:result];
}

- (BOOL)removeAccount:(NSString*)account
{
  if (account == nil || account.length == 0)
    return NO;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  OSStatus status = SecItemDelete((__bridge_retained CFDictionaryRef)dict);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to delete keychain entry for account (%@): %d", account, (int)status);
#else
    NSLog(@"Unable to delete keychain entry for account (%@): %@",
          account, (__bridge NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return NO;
  }
  return YES;
}

- (BOOL)updatePassword:(NSString*)password
            forAccount:(NSString*)account
{
  if (account == nil || account.length == 0)
    return NO;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  NSDictionary* update_dict = @{(__bridge id)kSecValueData: [self encodeString:password]};
  OSStatus status = SecItemUpdate((__bridge_retained CFDictionaryRef)dict,
                                  (__bridge_retained CFDictionaryRef)update_dict);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to update password for account (%@): %d", account, (int)status);
#else
    NSLog(@"Unable to update password for account (%@): %@",
          account, (__bridge NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return NO;
  }
  return YES;
}

- (NSString*)passwordForInternetAccount:(NSString*)account
                               protocol:(NSString*)protocol
                                   host:(NSString*)host
                                   port:(UInt16)port
{
  if (account == nil || account.length == 0)
    return nil;
  NSMutableDictionary* dict =
    [self keychainDictionaryForInternetAccount:account protocol:protocol host:host port:port];
  dict[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  dict[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
  CFTypeRef result = NULL;
  OSStatus status = SecItemCopyMatching((__bridge_retained CFDictionaryRef)dict, &result);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to find password for account (%@) server (%@): %d", account, host, (int)status);
#else
    NSLog(@"Unable to find password for account (%@) server (%@): %@",
          account, host, (__bridge NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return nil;
  }
  return [self decodeString:result];
}

#pragma mark - Helpers

- (NSString*)decodeString:(CFTypeRef)data
{
  return [[NSString alloc] initWithData:(__bridge NSData*)data encoding:NSUTF8StringEncoding];
}

- (id)encodeString:(NSString*)string
{
  return [string dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSMutableDictionary*)keychainDictionaryForAccount:(NSString*)account_
{
  NSString* account = account_.lowercaseString;
  NSDictionary* res = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
#if TARGET_OS_IPHONE
    (__bridge id)kSecAttrGeneric: [self encodeString:account],
    (__bridge id)kSecAttrAccount: [self encodeString:account],
    (__bridge id)kSecAttrService: [self encodeString:_service_name],
#else
// Historically, SecKeychainFindGenericPassword was used on OS X. This appears to not use the
// kSecAttrGeneric attribute. Leaving this out therefore ensures backwards compatibility with stored
// passwords.
    (__bridge id)kSecAttrAccount: account,
    (__bridge id)kSecAttrService: _service_name,
#endif
    (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly
  };
  return [res mutableCopy];
}

- (NSMutableDictionary*)keychainDictionaryForInternetAccount:(NSString*)account_
                                                    protocol:(NSString*)protocol_
                                                        host:(NSString*)host
                                                        port:(UInt16)port

{
  NSString* account = account_.lowercaseString;
  NSString* protocol = protocol_.lowercaseString;
  NSDictionary* res = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassInternetPassword,
#if TARGET_OS_IPHONE
    (__bridge id)kSecAttrAccount: [self encodeString:account],
    (__bridge id)kSecAttrProtocol: [self encodeString:protocol],
    (__bridge id)kSecAttrServer: [self encodeString:host],
#else
    (__bridge id)kSecAttrAccount: account,
    (__bridge id)kSecAttrProtocol: protocol,
    (__bridge id)kSecAttrServer: host,
#endif
    (__bridge id)kSecAttrPort: @(port),
    (__bridge id)kSecAttrAuthenticationType: (__bridge id)kSecAttrAuthenticationTypeDefault,
    (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly
  };
  return [res mutableCopy];
}

@end
