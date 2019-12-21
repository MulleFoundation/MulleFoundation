#import "MulleObjCCurl+NSURL.h"

#import "import-private.h"


#if defined( HAVE_LIB_MULLEOBJCJSMNFOUNDATION) && defined( HAVE_LIB_MULLEOBJCINETFOUNDATION)

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
