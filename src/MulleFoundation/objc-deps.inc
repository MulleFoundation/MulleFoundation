      { @selector( MulleObjCDeps), @selector( MulleObjCArchiverFoundation) },
      { @selector( MulleObjCDeps), @selector( MulleObjCOSBaseFoundation) },

// platform specific Foundations
#ifdef _WIN32
      { @selector( MulleObjCDeps), @selector( MulleObjCWindowsFoundation) },
#else
      { @selector( MulleObjCDeps), @selector( MulleObjCPosixFoundation) },
# ifdef __linux__
      { @selector( MulleObjCDeps), @selector( MulleObjCLinuxFoundation) },
# else
#  if defined(__APPLE__)  || defined(__FreeBSD__)   || defined(__OpenBSD__) \
   || defined(__NetBSD__) || defined(__DragonFly__)
      { @selector( MulleObjCDeps), @selector( MulleObjCBSDFoundation) },
#   if defined(__APPLE__)
      { @selector( MulleObjCDeps), @selector( MulleObjCDarwinFoundation) },
#   endif
#  endif
# endif
#endif

// optionally include decimal foundation, when published
#ifdef __has_include
# if __has_include(<MulleObjCDecimalFoundation/MulleObjCDecimalFoundation.h>)
      { @selector( MulleObjCDeps), @selector( MulleObjCDecimalFoundation) },
# endif
#endif
