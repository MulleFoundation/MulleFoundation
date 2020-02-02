#import "MulleObjCCurl+NSURL.h"

#import "import-private.h"


#if defined( HAVE_LIB_MULLE_OBJC_CURL_FOUNDATION) && defined( HAVE_LIB_MULLE_OBJC_INET_FOUNDATION)

@implementation MulleObjCCurl( NSURL)

- (NSData *) dataWithContentsOfURL:(NSURL *) url
{
   return( [self dataWithContentsOfURLString:[url absoluteString]]);
}


- (NSData *) dataWithContentsOfURL:(NSURL *) url
                     byPostingData:(NSData *) data;
{
   return( [self dataWithContentsOfURLString:[url absoluteString]
                               byPostingData:data]);
}

@end

#endif
