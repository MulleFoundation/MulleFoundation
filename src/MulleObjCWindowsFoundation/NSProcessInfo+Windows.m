/*
 *  MulleFoundation - the mulle-objc class library
 *
 *  NSProcessInfo+Windows.m is a part of MulleObjCOSFoundation
 *
 *  Copyright (C) 2024 Mulle kybernetiK.
 *  All rights reserved.
 *
 */

#import "import-private.h"

// other files in this library
#import "NSErrorWindows.h"
#import "NSFileManager+Windows.h"
#import "NSString+Windows.h"

// Windows headers
#include <windows.h>
#include <shellapi.h>
#include <mulle-utf/mulle-utf32.h>
#include <mulle-allocator/mulle-alloca.h>


static wchar_t   *createWideCString( NSString *string)
{
   NSUInteger   len;
   unichar      *utf32;
   wchar_t      *result;

   if( ! string)
      return( NULL);

   len    = [string length];
   result = mulle_malloc( (len + 1) * sizeof( wchar_t));

   if( len)
   {
      utf32 = mulle_malloc( len * sizeof( unichar));
      [string getCharacters:utf32
                      range:NSMakeRange( 0, len)];
      _mulle_utf32_convert_to_utf16( (mulle_utf32_t *) utf32, len, (mulle_utf16_t *) result);
      mulle_free( utf32);
   }
   result[ len] = 0;

   return( result);
}


@implementation NSProcessInfo( Windows)

@dependency NSProcessInfo;


- (NSInteger) processIdentifier
{
   MulleObjCSetWindowsErrorDomain();

   return( (int) GetCurrentProcessId());
}


- (NSString *) hostName
{
   return( @"localhost");
}


- (NSString *) operatingSystemName
{
   return( @"Windows");
}


- (NSString *) operatingSystemVersionString
{
   DWORD   version;

   version = GetVersion();
   return( [NSString stringWithFormat:@"Windows %lu.%lu",
                    (unsigned long) (version & 0xFF),
                    (unsigned long) ((version >> 8) & 0xFF)]);
}


- (NSUInteger) operatingSystem
{
   return( NSWindowsNTOperatingSystem);
}


- (NSArray *) arguments
{
   LPWSTR   *argv;
   int      argc;
   int      i;
   id       *objects;
   NSArray  *value;

   [_lock lock];
   if( ! _arguments)
   {
      argv = CommandLineToArgvW( GetCommandLineW(), &argc);
      if( ! argv)
      {
         [_lock unlock];
         MulleObjCThrowInternalInconsistencyException( @"CommandLineToArgvW failed: %lu",
                                                        GetLastError());
         return( nil);
      }

      objects = mulle_allocator_malloc( MulleObjCInstanceGetAllocator( self),
                                        argc * sizeof( id));
      for( i = 0; i < argc; i++)
      {
         objects[ i] = [[NSFileManager defaultManager]
                           stringWithFileSystemRepresentationUTF16:(mulle_utf16_t *) argv[ i]
                                                            length:wcslen( argv[ i])];
      }

      _arguments = [[NSArray alloc] initWithObjects:objects
                                              count:argc];

      mulle_allocator_free( MulleObjCInstanceGetAllocator( self), objects);
      LocalFree( argv);
   }
   value = [[_arguments retain] autorelease];
   [_lock unlock];

   return( value);
}


- (NSDictionary *) environment
{
   LPWCH                env;
   LPWCH                p;
   NSMutableDictionary  *dict;
   NSDictionary         *result;

   [_lock lock];
   if( ! _environment)
   {
      env = GetEnvironmentStringsW();
      if( ! env)
      {
         [_lock unlock];
         MulleObjCThrowInternalInconsistencyException( @"GetEnvironmentStringsW failed: %lu",
                                                        GetLastError());
         return( nil);
      }

      dict = [NSMutableDictionary new];

      for( p = env; *p; )
      {
         NSString   *line;
         NSString   *key;
         NSString   *value;
         NSRange    range;
         size_t     len;

         len  = wcslen( p);
         line = [[NSString alloc] mulleInitWithUTF16Characters:(mulle_utf16_t *) p
                                                        length:len];
         p   += len + 1;

         range = [line rangeOfString:@"="];
         if( range.length == 0)
         {
            [line release];
            continue;
         }

         key   = [[line substringToIndex:range.location] retain];
         value = [[line substringFromIndex:range.location + 1] retain];
         [line release];

         [dict mulleSetRetainedObject:value
                         forCopiedKey:key];
      }

      FreeEnvironmentStringsW( env);

      _environment = [dict copy];
      [dict release];
   }
   result = [[_environment retain] autorelease];
   [_lock unlock];

   return( result);
}


#pragma mark - Executable Path

static void   unlazyExecutablePath( NSProcessInfo *self)
{
   wchar_t    buf[ MAX_PATH + 1];
   DWORD      len;
   size_t     charlen;
   NSString   *path;

   len = GetModuleFileNameW( NULL, buf, MAX_PATH);
   if( ! len || len == MAX_PATH)
      MulleObjCThrowInternalInconsistencyException( @"can't get executable path from GetModuleFileNameW (%lu)", GetLastError());

   charlen = wcslen( buf);
   path    = [[NSString alloc] mulleInitWithUTF16Characters:(mulle_utf16_t *) buf
                                                      length:charlen];
   // Convert to Unix format for NSString path methods
   self->_executablePath = [[path mulleUnixFileSystemString] retain];
   [path release];
}


- (NSString *) _executablePath
{
   NSString   *value;

   [_lock lock];
   if( ! (id) _executablePath)
      unlazyExecutablePath( self);
   value = [[_executablePath retain] autorelease];
   [_lock unlock];

   return( value);
}


#pragma mark - processName

- (NSString *) processName
{
   NSString   *s;

   s = [self _executablePath];
   s = [s lastPathComponent];
   return( s);
}


- (void) setProcessName:(NSString *) name
{
   MULLE_C_UNUSED( name);
   // Windows doesn't support changing the process name at runtime
   // This is a no-op, like on Linux
}


- (void) mulleSetEnvironmentValue:(NSString *) value
                           forKey:(NSString *) key
{
   NSMutableDictionary   *dict;
   wchar_t               *wideKey;
   wchar_t               *wideValue;

   NSParameterAssert( key);
   if( ! key)
      return;

   MulleObjCSetWindowsErrorDomain();

   [_lock lock];
   {
      dict      = [NSMutableDictionary dictionaryWithDictionary:[self environment]];
      wideKey   = createWideCString( key);
      if( ! wideKey)
      {
         [_lock unlock];
         return;
      }

      wideValue = value ? createWideCString( value) : NULL;

      if( ! SetEnvironmentVariableW( wideKey, wideValue))
      {
         DWORD   error = GetLastError();

         if( wideValue)
            mulle_free( wideValue);
         mulle_free( wideKey);
         [_lock unlock];
         MulleObjCThrowInternalInconsistencyException( @"SetEnvironmentVariableW failed: %lu", error);
      }

      if( wideValue)
         mulle_free( wideValue);
      mulle_free( wideKey);

      if( value)
         [dict setObject:value
                  forKey:key];
      else
         [dict removeObjectForKey:key];

      [_environment autorelease];
      _environment = [dict copy];
   }
   [_lock unlock];
}

@end