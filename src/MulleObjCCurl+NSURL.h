#import "import.h"


#if defined( HAVE_LIB_MULLE_OBJC_CURL_FOUNDATION) && defined( HAVE_LIB_MULLE_OBJC_INET_FOUNDATION)

@interface MulleObjCCurl( NSURL)

- (NSData *) dataWithContentsOfURL:(NSURL *) url;
- (NSData *) dataWithContentsOfURL:(NSURL *) url
                     byPostingData:(NSData *) data;

@end

#endif
