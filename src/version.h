/*
 *  (c) 2018 nat 
 *
 *  version:  major, minor, patch
 */
#define MULLE_FOUNDATION_VERSION  ((0 << 20) | (7 << 8) | 56)


static inline unsigned int   Mulle_Foundation_get_version_major( void)
{
   return( MULLE_FOUNDATION_VERSION >> 20);
}


static inline unsigned int   Mulle_Foundation_get_version_minor( void)
{
   return( (MULLE_FOUNDATION_VERSION >> 8) & 0xFFF);
}


static inline unsigned int   Mulle_Foundation_get_version_patch( void)
{
   return( MULLE_FOUNDATION_VERSION & 0xFF);
}
