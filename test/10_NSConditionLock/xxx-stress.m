//
//  main.m
//  archiver-test
//
//  Created by Nat! on 19.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//

#ifdef __MULLE_OBJC__
# import <MulleFoundation/MulleFoundation.h>
#else
# import <Foundation/Foundation.h>
# pragma message( "Apple Foundation")
#endif


#define N_THREADS   16




@implementation NSConditionLock( Test)

- (void) runThread:(NSNumber *) argument
{
   NSInteger    value;
   int          i;
   int          threadno;

   threadno = [argument intValue];
   value    = (NSInteger) threadno;
   for( i = 0; i < 1000; i++)
   {
      [self lockWhenCondition:value];
      printf( "%d #%d: %ld\n",
               threadno,
               i,
               (long) [self condition]);
      [self unlockWithCondition:value + 1];
      value += N_THREADS;
   }
}


@end



int   main( int argc, const char * argv[])
{
   NSConditionLock   *lock;
   int               i;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   lock = [[[NSConditionLock alloc] initWithCondition:0] autorelease];
   printf( "0. %ld\n", [lock condition]);

   for( i = 1; i <= N_THREADS; i++)
      [NSThread detachNewThreadSelector:@selector( runThread:)
                               toTarget:lock
                             withObject:[NSNumber numberWithInt:i]];

   // all threads should be running now, lets go
   [lock lockWhenCondition:0];
   [lock unlockWithCondition:1];

   return( 0);
}
