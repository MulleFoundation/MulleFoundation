/*
 *  MulleFoundation - the mulle-objc class library
 *
 *  NSConditionLock.h is a part of MulleFoundation
 *
 *  Copyright (C) 2011 Nat!, Mulle kybernetiK.
 *  All rights reserved.
 *
 *  Coded by Nat!
 *
 *  $Id$
 *
 */
#import "import.h"


//
// You use a NSConditionLock to synchronize threads. The actual workload
// inside the lock should be **extremely** minimal as other threads may
// deadlock otherwise in lockWhenCondition:beforeDate:. To protect
// datastructures use a regular lock in conjunction with NSConditionLock.
//
// NSCondition is the OS interface and this makes things easier. It is a
// bit confusing that the integer value, that is basically the actual
// value being locked is also called condition. Also note that this is not
// really a NSLock but a synchronization tool, Depending on how things are
// setup two threads that wait for the same condition may run!
//
@interface NSConditionLock : NSCondition <NSLocking>
{
   mulle_atomic_pointer_t   _currentCondition;
}

- (instancetype) initWithCondition:(NSInteger) condition;

- (NSInteger) condition;

- (void) lockWhenCondition:(NSInteger) condition;

// this contrary to the documentation will NOT call
// -lockWhenCondition:beforeDate:. Instead its like lockWhenCondition
// but using tryLock to immediately bail if unsuccessful
- (BOOL) tryLockWhenCondition:(NSInteger) condition;
- (void) unlockWithCondition:(NSInteger) condition;

// this will not deadlock
- (BOOL) lockWhenCondition:(NSInteger) condition
                beforeDate:(NSDate *) limit;

//
- (BOOL) lockBeforeDate:(NSDate *) limit;


// this does the more common idiom
// of pthread_mutex_lock  pthread_cond_waittimed
// this may deadlock though, the time out is for sending the condition
// not the holding of the lock
- (BOOL) mulleLockWhenCondition:(NSInteger) value
                     beforeDate:(NSDate *) date;

@end

