//
//  MulleFoundation.h
//  MulleFoundation
//
//  Copyright (c) 2018 Nat! - Mulle kybernetiK.
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
#define MULLE_FOUNDATION     "Mulle kybernetiK"


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

#import "version.h"

#import "_MulleFoundation-export.h"

// the forwarding method in this particular runtime
void   *__forward_mulle_objc_object_call( void *self,
                                          mulle_objc_methodid_t _cmd,
                                          void *_param);



#ifdef __has_include
# if __has_include( "_MulleFoundation-versioncheck.h")
#  include "_MulleFoundation-versioncheck.h"
# endif
#endif
