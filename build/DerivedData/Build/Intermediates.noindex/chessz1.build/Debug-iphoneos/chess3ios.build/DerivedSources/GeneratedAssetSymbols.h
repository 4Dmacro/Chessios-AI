#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "chessicon120" asset catalog image resource.
static NSString * const ACImageNameChessicon120 AC_SWIFT_PRIVATE = @"chessicon120";

/// The "chessicon152" asset catalog image resource.
static NSString * const ACImageNameChessicon152 AC_SWIFT_PRIVATE = @"chessicon152";

/// The "chessicon24" asset catalog image resource.
static NSString * const ACImageNameChessicon24 AC_SWIFT_PRIVATE = @"chessicon24";

#undef AC_SWIFT_PRIVATE
