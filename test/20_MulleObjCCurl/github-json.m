#import <MulleFoundation/MulleFoundation.h>


static NSString  *URL = @"https://api.github.com/users/mulle-nat/orgs";


int   main( int argc, const char * argv[])
{
   MulleObjCCurl         *curl;
   MulleObjCJSMNParser   *parser;
   id                    plist;
   NSError               *error;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   curl   = [MulleObjCCurl object];
   parser = [MulleObjCJSMNParser object];

   [curl setParser:parser];
   [curl setRequestHeaders:@{
                              @"Accept" : @"application/vnd.github.v3+json",
                              @"User-Agent": @"Awesome-Octocat-App"  // :=)
                            }];
   // for testing turn off https certi checks, which are not ez
   // crossplatform wise
   [curl setOptions:@{
                       @"CURLOPT_SSL_VERIFYPEER": @(NO),
                       @"CURLOPT_SSL_VERIFYHOST": @(NO)
                     }];

   plist = [curl parseContentsOfURLString:URL];
   if( ! plist)
   {
      error = [NSError mulleCurrentErrorWithDomain:MulleObjCCurlErrorDomain];
      fprintf( stderr, "%s\n", [[error description] UTF8String]);
      return( 1);
   }

   printf( "%s\n", [[plist description] UTF8String]);
   return( 0);
}
