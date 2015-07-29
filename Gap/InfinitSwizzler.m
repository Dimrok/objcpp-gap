//
//  InfinitSwizzler.m
//  Gap
//
//  Created by Christopher Crone on 28/07/15.
//
//

#ifdef DEBUG

# import "InfinitSwizzler.h"

void
swizzle_class_selector(Class class, SEL original_sel, SEL swizzled_sel)
{
  Method original_meth = class_getInstanceMethod(class, original_sel);
  Method swizzled_meth = class_getInstanceMethod(class, swizzled_sel);
  BOOL did_add = class_addMethod(class,
                                 original_sel,
                                 method_getImplementation(swizzled_meth),
                                 method_getTypeEncoding(swizzled_meth));
  if (did_add)
  {
    class_replaceMethod(class,
                        swizzled_sel,
                        method_getImplementation(original_meth),
                        method_getTypeEncoding(original_meth));
  }
  else
  {
    method_exchangeImplementations(original_meth, swizzled_meth);
  }
}

#endif
