/*
 *  MulleFoundation - the mulle-objc class library
 *
 *  NSLocale+Windows.m is a part of MulleObjCOSFoundation
 *
 *  Copyright (C) 2024 Mulle kybernetiK.
 *  All rights reserved.
 *
 */

#import "import-private.h"

// Windows headers
#include <windows.h>


// Windows has no localeconv/locale_t. Where POSIX would ask the LC_NUMERIC or
// LC_MONETARY category for all of it at once, Windows asks for a single
// LOCALE_S* item of a named locale. Note that only keys that genuinely need
// the OS are answered here. Everything that follows from the identifier
// (languageCode, countryCode, scriptCode, collatorIdentifier,
// measurementSystem, usesMetricSystem) is answered platform independently.
static NSString   *mulle_windows_locale_info_string( WCHAR *localeName, LCTYPE type)
{
   WCHAR   buf[ 128];
   int     length;

   length = GetLocaleInfoEx( localeName, type, buf, (int) (sizeof( buf) / sizeof( WCHAR)));
   if( length <= 0)
      return( nil);

   // the returned length includes the terminating null character
   return( [[[NSString alloc] mulleInitWithUTF16Characters:(mulle_utf16_t *) buf
                                                  length:(NSUInteger) (length - 1)] autorelease]);
}


// NSLocale identifiers are POSIX shaped ("de_DE.utf8", "zh_Hans_CN@euro"),
// GetLocaleInfoEx wants a Windows name ("de-DE", "zh-Hans-CN"). "C" and
// "POSIX" are the invariant locale, which Windows spells as the empty name.
static void   mulle_windows_locale_name( NSString *identifier, WCHAR *name, size_t count)
{
   char     *s;
   size_t   i;
   size_t   j;

   name[ 0] = 0;
   if( count < 2 || ! identifier)
      return;

   if( [identifier isEqualToString:@"C"] || [identifier isEqualToString:@"POSIX"])
      return;

   s = [identifier UTF8String];
   if( ! s)
      return;

   // drop the ".codeset" and the "@modifier", they have no Windows equivalent
   for( i = j = 0; s[ i] && j + 1 < count; i++)
   {
      if( s[ i] == '.' || s[ i] == '@')
         break;
      name[ j++] = (s[ i] == '_') ? L'-' : (WCHAR) (unsigned char) s[ i];
   }
   name[ j] = 0;
}


// LOCALE_ENUMPROCEX wants an int return value, not a BOOL
static int CALLBACK   collect_locale_name( LPWSTR name, DWORD flags, LPARAM userInfo)
{
   NSMutableArray   *identifiers;
   NSString         *identifier;

   identifiers = (NSMutableArray *) (void *) userInfo;
   identifier  = [[[NSString alloc] mulleInitWithUTF16Characters:(mulle_utf16_t *) name
                                                         length:wcslen( name)] autorelease];
   if( [identifier length])
      [identifiers addObject:identifier];

   return( YES);
}


@implementation NSLocale( Windows)


// GetSystemDefaultLocaleName and GetUserDefaultLocaleName have the same
// signature. They answer Windows locale names ("de-DE"), the same shape as
// +availableLocaleIdentifiers produces.
static NSLocale   *makeLocaleWithWindowsLocaleName( int (WINAPI *get)( LPWSTR, int), NSString *fallback)
{
   WCHAR      localeName[ LOCALE_NAME_MAX_LENGTH];
   NSString   *identifier;

   if( ! get( localeName, LOCALE_NAME_MAX_LENGTH))
      return( [[[NSLocale alloc] initWithLocaleIdentifier:fallback] autorelease]);

   identifier = [[[NSString alloc] mulleInitWithUTF16Characters:(mulle_utf16_t *) localeName
                                                         length:wcslen( localeName)] autorelease];
   return( [[[NSLocale alloc] initWithLocaleIdentifier:identifier] autorelease]);
}


// The system default, the same distinction Linux and BSD draw from the
// process wide (global) versus the thread locale.
+ (instancetype) _systemLocale
{
   return( makeLocaleWithWindowsLocaleName( GetSystemDefaultLocaleName, @"C"));
}


// The user's current locale, which an application may not have overridden.
+ (instancetype) _currentLocale
{
   return( makeLocaleWithWindowsLocaleName( GetUserDefaultLocaleName, @"C"));
}


// There is no "locale -a" on Windows, EnumSystemLocalesEx( LOCALE_WINDOWS) is
// its equivalent. The names are Windows names ("de-DE"), the same shape that
// +_currentLocale produces.
+ (NSArray *) availableLocaleIdentifiers
{
   NSMutableArray   *identifiers;

   identifiers = [NSMutableArray array];
   @autoreleasepool
   {
      EnumSystemLocalesEx( collect_locale_name,
                           LOCALE_WINDOWS,
                           (LPARAM) (void *) identifiers,
                           NULL);
   }
   return( [[identifiers copy] autorelease]);
}


- (instancetype) initWithLocaleIdentifier:(NSString *) name
{
   if( ! name)
   {
      [self release];
      return( nil);
   }

   _identifier = [name copy];
   _keyValues  = [NSMutableDictionary new];
   _lock       = [NSLock new];

   // -objectForKey: fills _keyValues lazily, so it is only accessed under
   // _lock. Tell TAO that the dictionary may be messaged from any thread
   // (it has no real thread affinity).
   [_keyValues mulleSetThreadSafe:YES];

   // The keys that follow from the identifier need no Win32 call, precompute
   // them so -objectForKey: answers them without taking _lock.
   [self _setupDerivedLocaleValues:nil];

   return( self);
}


- (void) dealloc
{
   [_identifier release];
   [_keyValues release];
   [_derivedValues release];
   [_lock release];

   [super dealloc];
}


// Only the keys that need a Win32 call are answered here. The platform
// agnostic part of NSLocale answers the identifiers derived keys.
- (id) _localeInfoForKey:(id) key
{
   WCHAR   localeName[ LOCALE_NAME_MAX_LENGTH];

   if( ! [key isKindOfClass:[NSString class]])
      return( nil);

   mulle_windows_locale_name( _identifier, localeName, LOCALE_NAME_MAX_LENGTH);

   // these come from the LC_NUMERIC and LC_MONETARY categories on POSIX
   if( [key isEqualToString:NSLocaleDecimalSeparator])
      return( mulle_windows_locale_info_string( localeName, LOCALE_SDECIMAL));

   if( [key isEqualToString:NSLocaleGroupingSeparator])
      return( mulle_windows_locale_info_string( localeName, LOCALE_STHOUSAND));

   if( [key isEqualToString:NSLocaleCurrencySymbol])
      return( mulle_windows_locale_info_string( localeName, LOCALE_SCURRENCY));

   // int_curr_symbol is the ISO 4217 code, which is what NSLocaleCurrencyCode
   // documents. Windows wants LOCALE_SINTLSYMBOL for that.
   if( [key isEqualToString:NSLocaleCurrencyCode])
      return( mulle_windows_locale_info_string( localeName, LOCALE_SINTLSYMBOL));

   return( nil);
}


@end
