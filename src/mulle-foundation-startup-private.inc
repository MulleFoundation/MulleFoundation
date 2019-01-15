#import <MulleObjCStandardFoundation/private/mulle-foundation-universeconfiguration-private.h>

// default version asserter for Foundation code

#ifndef FOUNDATION_VERSION_ASSERT
static void   versionassert( struct _mulle_objc_universe *universe,
                             void *friend,
                             struct mulle_objc_loadversion *version)
{
   uint32_t   mask;

   mask = ~0U << 20;
   if( (version->foundation & mask) != (MULLE_FOUNDATION_VERSION & mask))
      mulle_objc_universe_fail_inconsistency( universe,
          "mulle_objc_universe %p: foundation version set to %x "
          "but universe foundation is %x",
              universe,
              version->foundation,
              MULLE_FOUNDATION_VERSION);
}

# define FOUNDATION_VERSION_ASSERT   versionassert
#endif


#include <MulleObjCStandardFoundation/private/mulle-foundation-startup-private.inc>


static inline void   MulleFoundationBang( struct _mulle_objc_universe *universe,
                                          struct mulle_allocator *allocator,
                                          struct _mulle_objc_universeconfiguration *config)
{
   MulleObjCStandardFoundationBang( universe, allocator, config);
}

