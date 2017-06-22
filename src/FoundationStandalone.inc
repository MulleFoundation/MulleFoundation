// default version asserter for Foundation code

#ifndef FOUNDATION_VERSION_ASSERT
static void   versionassert( struct _mulle_objc_universe *universe,
                            void *friend,
                            struct mulle_objc_loadversion *version)
{
   uint32_t   mask;

   mask = ~0U << 20;
   if( (version->foundation & mask) != (FOUNDATION_VERSION & mask))
      _mulle_objc_universe_raise_inconsistency_exception( universe,
          "mulle_objc_universe %p: foundation version set to %x "
          "but universe foundation is %x",
              universe,
              version->foundation,
              FOUNDATION_VERSION);
}

# define FOUNDATION_VERSION_ASSERT   versionassert
#endif

#include <MulleObjCStandardFoundation/MulleObjCFoundationStandalone.inc>
