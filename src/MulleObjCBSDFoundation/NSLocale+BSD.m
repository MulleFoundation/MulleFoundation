//
//  NSLocale+BSD.m
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
#import "import-private.h"

// other files in this library
#import <MulleObjCPosixFoundation/NSLocale+Posix-Private.h>

// std-c and dependencies
#include <langinfo.h>
#include <xlocale.h>


static id    mulle_localeconv_value( locale_t locale, int code)
{
   struct lconv   *conv;

   conv = localeconv_l( locale);
   if( ! conv)
      return( NULL);

   return( mulle_locale_lconv_value( conv, code));
}


static NSString   *queryLocaleName( int mask, locale_t base)
{
   char   *c_name;

   c_name = (char *) querylocale( mask, base);

   return( c_name ? [NSString stringWithCString:c_name] : nil);
}


@implementation NSLocale( BSD)

@dependency NSLocale( Posix);


static id   newLocaleByQuery( Class self, locale_t base)
{
   NSString  *name;

   name = queryLocaleName( LC_ALL_MASK, base);
   if( ! name)
      return( nil);

   return( [[self alloc] initWithLocaleIdentifier:name]);
}


+ (NSString *) systemLocalePath
{
   return( @"/usr/share/locale");
}


+ (instancetype) _systemLocale
{
   return( [newLocaleByQuery( self, LC_GLOBAL_LOCALE) autorelease]);
}


+ (instancetype) _currentLocale
{
   return( [newLocaleByQuery( self, NULL) autorelease]);
}


// Only keys that genuinely need a querylocale() / localeconv() call are
// answered here. The language, script, variant and collation identifier
// follow from the identifier alone (a locale keeps the identifier it was
// created with even when the OS has no data for it and falls back to "C"),
// so they are answered platform independently by NSLocale.
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

   case LANG_INFO  :
      s = nl_langinfo_l( info.code, _xlocale);
      return( s ? [NSString stringWithCString:s] : nil);

   case CONV_INFO :
      return( mulle_localeconv_value( _xlocale, info.code));
   }
   return( nil);
}

@end
