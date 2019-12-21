#import "import.h"


#if defined( HAVE_LIB_MULLEOBJCCURLFOUNDATION) && defined( HAVE_LIB_MULLEOBJCINETFOUNDATION)

@interface MulleObjCCurl( NSURL)

- (NSData *) dataWithContentsOfURL:(NSURL *) url;
- (NSData *) dataWithContentsOfURL:(NSURL *) url
                     byPostingData:(NSData *) data;

@end

#endif
