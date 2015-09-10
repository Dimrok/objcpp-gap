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
static dispatch_once_t _instance_token = 0;
static NSString* _service_name = @"Infinit";

@implementation InfinitKeychain

#pragma mark - Init

- (id)init
{
  NSCAssert(_instance == nil, @"Use the sharedInstance");
  if (self = [super init])
  {}
  return self;
}

+ (instancetype)sharedInstance
{
  dispatch_once(&_instance_token, ^
  {
    _instance = [[InfinitKeychain alloc] init];
  });
  return _instance;
}

#pragma mark - Keychain Operations

- (BOOL)addPassword:(NSString*)password
         forAccount:(NSString*)account
{
  if (!account.length || !password.length)
    return NO;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  dict[(__bridge id)kSecValueData] = [self encodeString:password];
  CFDictionaryRef dict_ref = (__bridge_retained CFDictionaryRef)dict;
  OSStatus status = SecItemAdd(dict_ref, NULL);
  CFRelease(dict_ref);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to add item: %d", (int)status);
#else
    NSLog(@"Unable to add item: %@",
          (__bridge_transfer NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return NO;
  }
  return YES;
}

- (BOOL)credentialsForAccountInKeychain:(NSString*)account
{
  if (!account.length)
    return NO;
  if ([self passwordForAccount:account] == nil)
    return NO;
  return YES;
}

- (NSString*)passwordForAccount:(NSString*)account
{
  if (!account.length)
    return nil;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  dict[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  dict[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
  CFTypeRef result = NULL;
  CFDictionaryRef dict_ref = (__bridge_retained CFDictionaryRef)dict;
  OSStatus status = SecItemCopyMatching(dict_ref, &result);
  CFRelease(dict_ref);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to find password for account (%@): %d", account, (int)status);
#else
    NSLog(@"Unable to find password for account (%@): %@",
          account, (__bridge_transfer NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return nil;
  }
  return [self decodeString:result];
}

- (BOOL)removeAccount:(NSString*)account
{
  if (!account.length)
    return NO;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  CFDictionaryRef dict_ref = (__bridge_retained CFDictionaryRef)dict;
  OSStatus status = SecItemDelete(dict_ref);
  CFRelease(dict_ref);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to delete keychain entry for account (%@): %d", account, (int)status);
#else
    NSLog(@"Unable to delete keychain entry for account (%@): %@",
          account, (__bridge_transfer NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return NO;
  }
  return YES;
}

- (BOOL)updatePassword:(NSString*)password
            forAccount:(NSString*)account
{
  if (!account.length || !password.length)
    return NO;
  NSMutableDictionary* dict = [self keychainDictionaryForAccount:account];
  CFDictionaryRef dict_ref = (__bridge_retained CFDictionaryRef)dict;
  NSDictionary* update_dict = @{(__bridge id)kSecValueData: [self encodeString:password]};
  CFDictionaryRef update_dict_ref = (__bridge_retained CFDictionaryRef)update_dict;
  OSStatus status = SecItemUpdate(dict_ref, update_dict_ref);
  CFRelease(dict_ref);
  CFRelease(update_dict_ref);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to update password for account (%@): %d", account, (int)status);
#else
    NSLog(@"Unable to update password for account (%@): %@",
          account, (__bridge_transfer NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return NO;
  }
  return YES;
}

- (NSString*)passwordForProxyAccount:(NSString*)account
                            protocol:(NSString*)protocol
                                host:(NSString*)host
                                port:(UInt16)port
{
  if (!account.length)
    return nil;
  NSMutableDictionary* dict =
    [self keychainDictionaryForProxyAccount:account protocol:protocol host:host port:port];
  dict[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  dict[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
  CFTypeRef result = NULL;
  CFDictionaryRef dict_ref = (__bridge_retained CFDictionaryRef)dict;
  OSStatus status = SecItemCopyMatching(dict_ref, &result);
  CFRelease(dict_ref);
  if (status != errSecSuccess)
  {
#if TARGET_OS_IPHONE
    NSLog(@"Unable to find password for account (%@) server (%@): %d", account, host, (int)status);
#else
    NSLog(@"Unable to find password for account (%@) server (%@): %@",
          account, host, (__bridge_transfer NSString*)SecCopyErrorMessageString(status, NULL));
#endif
    return nil;
  }
  return [self decodeString:result];
}

#pragma mark - Helpers

- (NSString*)decodeString:(CFTypeRef)data
{
  return [[NSString alloc] initWithData:(__bridge_transfer NSData*)data
                               encoding:NSUTF8StringEncoding];
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
  };
  return [res mutableCopy];
}

- (NSMutableDictionary*)keychainDictionaryForProxyAccount:(NSString*)account_
                                                 protocol:(NSString*)protocol
                                                     host:(NSString*)host
                                                     port:(UInt16)port

{
  NSString* account = account_.lowercaseString;
  CFTypeRef protocol_ref = [self proxyProtocolAttrFromString:protocol];
  NSDictionary* res = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassInternetPassword,
#if TARGET_OS_IPHONE
    (__bridge id)kSecAttrAccount: [self encodeString:account],
    (__bridge id)kSecAttrServer: [self encodeString:host],
#else
    (__bridge id)kSecAttrAccount: account,
    (__bridge id)kSecAttrServer: host,
#endif
    (__bridge id)kSecAttrProtocol: (__bridge id)protocol_ref,
    (__bridge id)kSecAttrPort: @(port),
  };
  return [res mutableCopy];
}

- (CFTypeRef)proxyProtocolAttrFromString:(NSString*)string_
{
  NSString* string = string_.lowercaseString;
  if ([string isEqualToString:@"http"])
    return kSecAttrProtocolHTTPProxy;
  if ([string isEqualToString:@"https"])
    return kSecAttrProtocolHTTPS;
  if ([string isEqualToString:@"socks"])
    return kSecAttrProtocolSOCKS;
  return kSecAttrProtocolSOCKS;
}

@end
