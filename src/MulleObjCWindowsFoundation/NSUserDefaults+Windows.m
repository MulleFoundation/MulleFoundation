//
//  NSUserDefaults+Windows.m
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
#import "import-private.h"

#import "NSErrorWindows.h"

// other libraries of MulleObjCOSBaseFoundation
#import <MulleObjCOSBaseFoundation/NSDictionary+OSBase.h>
#import <MulleObjCOSBaseFoundation/NSFileManager.h>
#import <MulleObjCOSBaseFoundation/NSPathUtilities.h>
#import <MulleObjCOSBaseFoundation/NSString+OSBase.h>
#import <MulleObjCOSBaseFoundation/NSUserDefaults.h>

// std-c and dependencies
#include <windows.h>
#include <unistd.h>


#define MULLE_USERDEFAULTS_VALUE  "defaults"


//
// The registry value stores a serialized property list (binary).
// Serialization goes through a scratch file, keeping this file free of
// any property list library dependency.
//
static NSString   *scratchPath( void)
{
   return( [NSTemporaryDirectory() stringByAppendingPathComponent:
              [NSString stringWithFormat:@"mulle-defaults-%d.plist", (int) getpid()]]);
}


static NSData   *serializeDomain( NSDictionary *domain)
{
   NSData     *data;
   NSString   *path;

   data = nil;
   path = scratchPath();

   if( [domain writeToFile:path
                atomically:NO])
      data = [NSData dataWithContentsOfFile:path];

   [[NSFileManager defaultManager] removeItemAtPath:path
                                              error:NULL];
   return( data);
}


static NSDictionary   *deserializeDomain( NSData *data)
{
   NSDictionary   *dictionary;
   NSString       *path;

   dictionary = nil;
   path       = scratchPath();

   if( [data writeToFile:path
              atomically:NO])
      dictionary = [NSDictionary dictionaryWithContentsOfFile:path];

   [[NSFileManager defaultManager] removeItemAtPath:path
                                              error:NULL];
   return( dictionary);
}


@implementation NSUserDefaults( Windows)

@dependency NSUserDefaults( Persistent);


- (BOOL) _loadPersistentDomain:(NSMutableDictionary *) domain
{
   HKEY            key;
   NSDictionary    *dictionary;
   NSData          *data;
   NSString        *keyPath;
   DWORD           size;
   DWORD           type;
   LONG            rc;
   void            *bytes;

   MulleObjCSetWindowsErrorDomain();

   keyPath = [NSString stringWithFormat:@"Software\\%@", [self _defaultsIdentifier]];

   rc = RegOpenKeyExA( HKEY_CURRENT_USER, [keyPath UTF8String], 0, KEY_READ, &key);
   if( rc != ERROR_SUCCESS)
      return( NO);

   size = 0;
   type = 0;
   rc   = RegQueryValueExA( key, MULLE_USERDEFAULTS_VALUE, NULL, &type, NULL, &size);
   if( rc != ERROR_SUCCESS || ! size)
   {
      RegCloseKey( key);
      return( NO);
   }

   bytes = mulle_malloc( size);
   rc    = RegQueryValueExA( key, MULLE_USERDEFAULTS_VALUE, NULL, &type, bytes, &size);
   RegCloseKey( key);

   if( rc != ERROR_SUCCESS)
   {
      mulle_free( bytes);
      return( NO);
   }

   data       = [NSData dataWithBytes:bytes
                               length:size];
   mulle_free( bytes);

   dictionary = deserializeDomain( data);
   if( ! dictionary)
      return( NO);

   [domain addEntriesFromDictionary:dictionary];
   return( YES);
}


- (BOOL) _savePersistentDomain:(NSDictionary *) domain
{
   HKEY          key;
   NSData        *data;
   NSString      *keyPath;
   DWORD         disposition;
   LONG          rc;

   MulleObjCSetWindowsErrorDomain();

   keyPath = [NSString stringWithFormat:@"Software\\%@", [self _defaultsIdentifier]];

   rc = RegCreateKeyExA( HKEY_CURRENT_USER, [keyPath UTF8String], 0, NULL, 0,
                         KEY_WRITE, NULL, &key, &disposition);
   if( rc != ERROR_SUCCESS)
      return( NO);

   if( ! [domain count])
      RegDeleteValueA( key, MULLE_USERDEFAULTS_VALUE);
   else
   {
      data = serializeDomain( domain);
      if( ! data)
      {
         RegCloseKey( key);
         return( NO);
      }

      RegSetValueExA( key, MULLE_USERDEFAULTS_VALUE, 0, REG_BINARY,
                      [data bytes], (DWORD) [data length]);
   }

   RegCloseKey( key);
   return( YES);
}

@end
