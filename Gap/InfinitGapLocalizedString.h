//
//  Header.h
//  Gap
//
//  Created by Christopher Crone on 05/05/15.
//
//

#ifndef Gap_InfinitGapLocalizedString_h
# define Gap_InfinitGapLocalizedString_h

#define GapLocalizedString(key, comment) \
[[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:@"Gap_Localizable"]

#endif