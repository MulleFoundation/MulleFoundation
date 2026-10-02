//
//  NSLocale+Linux.m
//  MulleObjCOSFoundation
//
//  Copyright (c) 2016 Nat! - Mulle kybernetiK.
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
#define _GNU_SOURCE

#import "import-private.h"

// other files in this library

// other libraries of MulleObjCPosixFoundation
#import <MulleObjCPosixFoundation/NSLocale+Posix-Private.h>

// std-c and dependencies
#include <locale.h>
#include <langinfo.h>
#include <string.h>
#include <stdlib.h>


// The locale the environment asks for: LC_ALL beats LC_CTYPE beats LANG.
// An empty value is not a locale, it means "unset".
//
// Whether the name can actually be instantiated is decided by
// -initWithLocaleIdentifier:, which is the one place that spends a
// newlocale() on it. Validating the name here with a second newlocale() just
// duplicated that work and threw the result away - and it was not even
// equivalent, because it only asked for LC_CTYPE while the constructor asks
// for every category. A name the OS has no data for now keeps being the
// identifier (exactly like an explicit -initWithLocaleIdentifier: does) and
// only its *values* fall back to "C".
static NSString   *mulle_locale_environment_identifier( void)
{
   char   *s;

   s = getenv( "LC_ALL");
   if( ! s || ! *s)
      s = getenv( "LC_CTYPE");
   if( ! s || ! *s)
      s = getenv( "LANG");
   if( ! s || ! *s)
      return( @"C");

   return( [NSString stringWithCString:s]);
}


// maps the (POSIX) CONV_ codes onto their nl_langinfo counterpart
static int   mulle_locale_conv_nl_item( int code)
{
   switch( code)
   {
   case CONV_DECIMAL_POINT       : return( RADIXCHAR);
   case CONV_THOUSANDS_SEPERATOR : return( THOUSEP);
   case CONV_CURRENCY_SYMBOL     : return( CRNCYSTR);
   case CONV_INT_CURRENCY_SYMBOL : return( INT_CURR_SYMBOL);
   }
   return( -1);
}


static NSString   *mulle_locale_conv_info( int code, locale_t xlocale)
{
   char     buf[ 64];
   char     *s;
   size_t   len;
   int      item;

   item = mulle_locale_conv_nl_item( code);
   if( item == -1)
      return( nil);

   s = nl_langinfo_l( item, xlocale);
   if( ! s)
      return( nil);

   // CRNCYSTR is prefixed by a sign character that is not part of the symbol
   if( code == CONV_CURRENCY_SYMBOL && (s[ 0] == '-' || s[ 0] == '+'))
      ++s;

   // INT_CURR_SYMBOL is padded with a blank
   len = strlen( s);
   while( len && (s[ len - 1] == ' ' || s[ len - 1] == '\t'))
      --len;

   if( len >= sizeof( buf))
      return( [NSString stringWithCString:s]);

   memcpy( buf, s, len);
   buf[ len] = 0;
   return( [NSString stringWithCString:buf]);
}


@implementation NSLocale (Linux)

@dependency NSLocale( Posix);

+ (NSString *) systemLocalePath
{
   // how can we get this reliably ?
   return( @"/usr/share/i18n/locales");
}


+ (instancetype) _systemLocale
{
   return( [[[NSLocale alloc] initWithLocaleIdentifier:mulle_locale_environment_identifier()] autorelease]);
}


+ (instancetype) _currentLocale
{
   return( [[[NSLocale alloc] initWithLocaleIdentifier:mulle_locale_environment_identifier()] autorelease]);
}


- (id) _localeInfoForKey:(id) key
{
   struct mulle_locale_key_info   info;
   char                           *s;

   s    = NULL;
   info = mulle_locale_map_string_key_to_local_key( key);

   switch( info.type)
   {
   case IDENTIFIER_INFO :
      return( _identifier);

   case CONV_INFO :
      return( mulle_locale_conv_info( info.code, _xlocale));

   case LANG_INFO  :
      s = nl_langinfo_l( info.code, _xlocale);
      return( s ? [NSString stringWithCString:s] : nil);
   }
   return( nil);
}

@end
