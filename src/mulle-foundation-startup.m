//
//  Foundation.m
//  MulleFoundation
//
//  Created by Nat! on 04.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//
#define _GNU_SOURCE

#import "import.h"

#import "version.h"
#import "mulle-foundation-startup-private.inc"


static void   bang( struct _mulle_objc_universe *universe,
                    struct mulle_allocator *allocator,
                    void *userinfo)
{
   struct _mulle_objc_universeconfiguration   config;

   memcpy( &config,
           mulle_objc_global_get_default_universeconfiguration(),
           sizeof( config));

   MulleFoundationBang( universe, allocator, &config);
}
