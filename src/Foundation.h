//
//  Foundation.h
//  Foundation
//
//  Created by Nat! on 02.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//

#define FOUNDATION_VERSION   ((0 << 20) | (13 << 8) | 0)

// this specifies the "vendor" and also announces it
// known values:
//
//    * "Mulle kybernetiK"
//    * "Codeon Gmbh"
//    * "Community"
//
#define MULLE_FOUNDATION     "Mulle kybernetiK"

// must be kept like this, this is how the compiler reads it
// only code that includes the foundation header will get the
// benefit of version checking at runtime!

#define FOUNDATION_VERSION_MAJOR  0
#define FOUNDATION_VERSION_MINOR  13
#define FOUNDATION_VERSION_PATCH  0


#if TRACE_INCLUDE
# pragma message( "Using the MulleFoundation")
#endif

//
// https://stackoverflow.com/questions/142508/how-do-i-check-os-with-a-preprocessor-directive
//
#if defined( __MACH__)
#else
# ifdef __linux__
# else
#  ifdef __FreeBSD__
#  else
#   ifdef  __unix__
#   else
#    ifdef _WIN32
#    else
#     error "unknown OS"
#    endif
#   endif
#  endif
# endif
#endif




#if ! defined (__has_include)
# error "Congratulations. You're compiling without mulle-clang and you made it quite far"
#endif

#import "import.h"


#import "MulleObjCLoader+Foundation.h"

// the forwarding method in this particular runtime
void   *__forward_mulle_objc_object_call( void *self,
                                          mulle_objc_methodid_t _cmd,
                                          void *_param);


