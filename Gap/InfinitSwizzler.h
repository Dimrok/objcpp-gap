//
//  InfinitSwizzler.h
//  Gap
//
//  Created by Christopher Crone on 28/07/15.
//
//

#if defined(DEBUG) || !TARGET_OS_IPHONE

# import <objc/runtime.h>

void
swizzle_class_selector(Class class, SEL original_sel, SEL swizzled_sel);

#endif
