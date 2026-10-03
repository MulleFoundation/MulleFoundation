//
//  NSTask+Windows.m
//  MulleObjCOSFoundation
//
//  Copyright (c) 2026 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//
//  There used to be a hand-built command line, a wide string conversion, an
//  environment block, three CreatePipe, three SetHandleInformation, a
//  STARTUPINFO and a CreateProcessW, a WaitForSingleObject, a
//  GetExitCodeProcess and a lazy ntdll resolver in here. All of that is
//  mulle-spawn now, which does the same thing on POSIX, and all of the
//  *lifecycle* that used to follow it is `NSTask.m`, because there is nothing
//  Windows about it once the child is running.
//
//  What is left in this file is `launch`, which is the only part that differs
//  from the POSIX one: what the three standard streams are, how they are
//  passed on, and what the child must not be left holding.
//
//  The reference for what this has to keep doing is test/NSTask in
//  MulleObjCOSFoundation, and the plan is SPAWN-TASK-PLAN.md in mulle-spawn.
//
#import "import-private.h"

#import <MulleObjCOSBaseFoundation/NSTask-Private.h>

// std-c and dependencies
#include <windows.h>
#include <fcntl.h>
#include <io.h>
#include <errno.h>
#include <assert.h>
#include <string.h>

// mulle-spawn is a constituent of mulle-core and arrives with the Objective-C
// runtime's dependency on it, so the include is technically already there -- it
// is spelled out anyway, because nothing else in this file would tell a reader
// where mulle_spawn_* is from.
#include <mulle-spawn/mulle-spawn.h>


/*
 * The descriptor the child gets on one stream.
 *
 * This Windows Foundation keeps a HANDLE behind the descriptor accessors,
 * where POSIX keeps a descriptor number, and mulle-spawn's Windows backend
 * takes the CRT descriptor that `_get_osfhandle` understands -- which is the
 * shape POSIX hands over. `_open_osfhandle` is the bridge between the two.
 *
 * It *takes over* the handle it is given, and a descriptor that is closed
 * closes it, so the caller's handle is not the one handed across: it is
 * duplicated first and the duplicate is what sits at the end of the
 * descriptor. Nothing of the caller's is closed or re-flagged, and the
 * duplicate is closed again once the child has a copy of its own -- which is
 * exactly what `MULLE_SPAWN_DESCRIPTOR` promises.
 *
 * A handle that is absent, or is INVALID_HANDLE_VALUE, is EBADF: there would
 * be nothing to pass on.
 */
static int   childDescriptor( HANDLE handle)
{
   HANDLE     duplicate;
   intptr_t   fd;

   if( ! handle || handle == INVALID_HANDLE_VALUE)
   {
      errno = EBADF;
      return( -1);
   }

   if( ! DuplicateHandle( GetCurrentProcess(), handle,
                          GetCurrentProcess(), &duplicate,
                          0, TRUE, DUPLICATE_SAME_ACCESS))
      return( -1);

   fd = _open_osfhandle( (intptr_t) duplicate, _O_BINARY | _O_NOINHERIT);
   if( fd == -1)
   {
      CloseHandle( duplicate);
      return( -1);
   }

   return( (int) fd);
}


@implementation NSTask( Windows)

- (void) launch
{
   struct mulle_spawn_options   options;
   struct mulle_spawn_handle    *handle;
   NSString                     *converted;
   char                         **argv;
   char                         **arguments;
   void                         *envAllocation;
   char                         *path;
   char                         *directory;
   NSUInteger                   argc;
   NSUInteger                   i;
   int                          descriptors[ 3];
   int                          rval;
   int                          err;

   if( _status != _NSTaskIsIdle)
      MulleObjCThrowInvalidArgumentException( @"Task already launched");

   if( ! _launchPath)
      MulleObjCThrowInvalidArgumentException( @"No launch path set");

   /*
    * A Foundation path here is /c/... and the child means C:\... by it, so the
    * launch path and the directory go through the conversion the rest of this
    * port does -- in both cases once, here at the boundary.
    */
   converted = [_launchPath mulleWindowsFileSystemString];
   path      = (char *) [converted UTF8String];
   argc      = [_arguments count];

   argv             = mulle_malloc( (argc + 2) * sizeof( char *));
   argv[ 0]         = path;
   argv[ argc + 1]  = NULL;

   assert( sizeof( id) == sizeof( char *));
   arguments = &argv[ 1];
   [_arguments getObjects:(id *) arguments];
   for( i = 0; i < argc; i++)
      arguments[ i] = (char *) [(id) arguments[ i] UTF8String];

   directory = _directoryPath
               ? (char *) [[_directoryPath mulleWindowsFileSystemString] UTF8String]
               : NULL;

   mulle_spawn_options_init( &options);
   options.env       = mulleNSTaskEnvironmentStrings( _environment, &envAllocation);
   options.directory = directory;

   /*
    * `interrupt` on Windows is Ctrl+Break aimed at the child's own process
    * group, and a child that shares this one cannot be aimed at without
    * signalling this process too. So the group is asked for here -- without
    * it there is no way to interrupt a child, which is what the old
    * "interrupt means terminate" was standing in for.
    */
   options.new_process_group = 1;

   /*
    * CreateProcessW hands the child every inheritable handle in this process,
    * and NSPipe makes both of its ends inheritable. For stdin that matters:
    * if the child also gets the end the parent writes on, its own read never
    * finds EOF. Naming the ends the child must *not* have, and marking them
    * non-inheritable, is how the old port did it too.
    *
    * It is not put back afterwards: mulle-spawn duplicates what it is given
    * and makes the duplicate inheritable itself, so a pipe that is passed on
    * again later does not need the flag.
    */
   if( [_standardInput isKindOfClass:[NSPipe class]])
      SetHandleInformation( (HANDLE) (intptr_t) [_standardInput _fileDescriptorForWriting],
                            HANDLE_FLAG_INHERIT, 0);
   if( [_standardOutput isKindOfClass:[NSPipe class]])
      SetHandleInformation( (HANDLE) (intptr_t) [_standardOutput _fileDescriptorForReading],
                            HANDLE_FLAG_INHERIT, 0);
   if( [_standardError isKindOfClass:[NSPipe class]])
      SetHandleInformation( (HANDLE) (intptr_t) [_standardError _fileDescriptorForReading],
                            HANDLE_FLAG_INHERIT, 0);

   /*
    * The child reads its stdin where the caller writes, and writes its stdout
    * and stderr where the caller reads.
    */
   descriptors[ 0] = descriptors[ 1] = descriptors[ 2] = -1;

   if( _standardInput)
      descriptors[ 0] = childDescriptor( (HANDLE) (intptr_t) [_standardInput _fileDescriptorForReading]);
   if( _standardOutput)
      descriptors[ 1] = childDescriptor( (HANDLE) (intptr_t) [_standardOutput _fileDescriptorForWriting]);
   if( _standardError)
      descriptors[ 2] = childDescriptor( (HANDLE) (intptr_t) [_standardError _fileDescriptorForWriting]);

   if( ( _standardInput  && descriptors[ 0] == -1)
    || ( _standardOutput && descriptors[ 1] == -1)
    || ( _standardError  && descriptors[ 2] == -1))
   {
      err = errno;

      for( i = 0; i < 3; i++)
         if( descriptors[ i] != -1)
            _close( descriptors[ i]);
      mulle_free( envAllocation);
      mulle_free( argv);

      errno = err;
      MulleObjCThrowInvalidArgumentException( @"%@ could not pass on its standard streams (%s)",
                                              self, strerror( err));
   }

   if( descriptors[ 0] != -1)
   {
      options.in_mode       = MULLE_SPAWN_DESCRIPTOR;
      options.in_descriptor = descriptors[ 0];
   }
   if( descriptors[ 1] != -1)
   {
      options.out_mode       = MULLE_SPAWN_DESCRIPTOR;
      options.out_descriptor = descriptors[ 1];
   }
   if( descriptors[ 2] != -1)
   {
      options.err_mode       = MULLE_SPAWN_DESCRIPTOR;
      options.err_descriptor = descriptors[ 2];
   }

   handle = mulle_malloc( sizeof( struct mulle_spawn_handle));
   rval   = mulle_spawn_open_with_options( handle, argv, &options);
   err    = errno;

   for( i = 0; i < 3; i++)
      if( descriptors[ i] != -1)
         _close( descriptors[ i]);

   mulle_free( envAllocation);
   mulle_free( argv);

   /*
    * A child that could not be started at all is not a launch that succeeded
    * and a task that reports exit 1: the caller is told, and `errno` says why.
    */
   if( rval == -1)
   {
      mulle_free( handle);

      errno = err;
      MulleObjCThrowInvalidArgumentException( @"%@ could not launch \"%@\" (%s)",
                                              self, _launchPath, strerror( err));
   }

   _pid        = (int) handle->pid;
   _taskHandle = handle;
   _status     = _NSTaskIsRunning;

   /*
    * The child has its own copies of these now, and the parent still holding
    * the child's end of a pipe is what keeps `readDataToEndOfFile` from ever
    * finding EOF. Only a pipe's end is given up: a descriptor of the caller's
    * own -- a file, say -- stays the caller's, exactly as mulle-spawn's
    * descriptor mode promises.
    */
   if( [_standardInput isKindOfClass:[NSPipe class]])
      [[_standardInput fileHandleForReading] closeFile];
   if( [_standardOutput isKindOfClass:[NSPipe class]])
      [[_standardOutput fileHandleForWriting] closeFile];
   if( [_standardError isKindOfClass:[NSPipe class]])
      [[_standardError fileHandleForWriting] closeFile];
}

@end
