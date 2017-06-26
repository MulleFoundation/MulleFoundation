//
//  Foundation.h
//  Foundation
//
//  Created by Nat! on 02.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//

#define FOUNDATION_VERSION   ((0 << 20) | (0 << 8) | 1)

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
#define FOUNDATION_VERSION_MINOR  0
#define FOUNDATION_VERSION_PATCH  1


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


// MulleObjCStandardFoundation and MulleObjCInetFoundation.h are below OS
#import <MulleObjCStandardFoundation/MulleObjCStandardFoundation.h>


#if ! defined (__has_include)
# error "Congratulations. You're compiling without mulle-clang and you made it quite far"
#endif

//
// due to __has_include, the Foundation can be made bigger or smaller
// f.e. if you don't need MulleObjCExpatFoundation you can leave it out
//
// DNS resolving
#if __has_include(<MulleObjCAresFoundation/MulleObjCAresFoundation.h>)
# import <MulleObjCAresFoundation/MulleObjCAresFoundation.h>
#endif

// Sockets and stuff
#if __has_include(<MulleObjCCurlFoundation/MulleObjCCurlFoundation.h>)
# import <MulleObjCCurlFoundation/MulleObjCCurlFoundation.h>
#endif

// NSDecimal and friends
#if __has_include(<MulleObjCDecimalFoundation/MulleObjCDecimalFoundation.h>)
# import <MulleObjCDecimalFoundation/MulleObjCDecimalFoundation.h>
#endif

// XML
#if __has_include(<MulleObjCExpatFoundation/MulleObjCExpatFoundation.h>)
# import <MulleObjCExpatFoundation/MulleObjCExpatFoundation.h>
#endif

// Key Value Coding
#if __has_include(<MulleObjCKVCFoundation/MulleObjCKVCFoundation.h>)
#import <MulleObjCKVCFoundation/MulleObjCKVCFoundation.h>
#endif

// NSCalendar
#if __has_include(<MulleObjCICUFoundation/MulleObjCICUFoundation.h>)
# import <MulleObjCICUFoundation/MulleObjCICUFoundation.h>
#endif

// NSURL
#if __has_include(<MulleObjCInetFoundation/MulleObjCInetFoundation.h>)
#import <MulleObjCInetFoundation/MulleObjCInetFoundation.h>
#endif

// OS Specific classes
#if __has_include(<MulleObjCOSFoundation/MulleObjCOSFoundation.h>)
#import <MulleObjCOSFoundation/MulleObjCOSFoundation.h>
#endif

// the forwarding method in this particular runtime
void   *__forward_mulle_objc_object_call( void *self, mulle_objc_methodid_t _cmd, void *_param);

#import "MulleObjCLoader+Foundation.h"

