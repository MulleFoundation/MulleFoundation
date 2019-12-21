#import "MulleObjCJSMNParser+MulleObjCCurlParser.h"

#import "import-private.h"


@implementation MulleObjCJSMNParser( MulleObjCCurlParser)

- (BOOL) curl:(MulleObjCCurl *) curl
   parseBytes:(void *) bytes
       length:(NSUInteger) length
{
   id              obj;
   NSMutableData   *data;

   if( ! _userInfo)
      _userInfo = [NSMutableData new];
   data = _userInfo;

   [data appendBytes:bytes
               length:length],
   obj = [self parseData:data];
   if( ! obj)
      return( [self isIncomplete]);

   [curl setUserInfo:obj];
   return( YES);
}


//
// the parsed result
//
- (id) parsedObjectWithCurl:(MulleObjCCurl *) curl
{
   id              obj;
   NSError         *error;
   NSMutableData   *data;

   data = _userInfo;
   obj  = [curl userInfo];
   if( ! obj)
   {
      if( [self isIncomplete])
      {
         error = [self errorWithName:@"truncation"
                                data:_userInfo
                               range:NSMakeRange( [data length], 0)];
         [NSError mulleSetCurrentError:error];
      }

      // keep userInfo around for inspection
      return( nil);
   }

   [self setUserInfo:nil];
   [curl setUserInfo:nil]; // get rid of temporary storage

   return( obj);
}

@end
