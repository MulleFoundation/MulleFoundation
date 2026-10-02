### If you want to edit this, copy it from cmake/share to cmake. It will be
### picked up in preference over the one in cmake/share. And it will not get
### clobbered with the next upgrade.

if( NOT __INSTALL_CMAKE_INCLUDE__CMAKE__)
   set( __INSTALL_CMAKE_INCLUDE__CMAKE__ ON)

   if( MULLE_TRACE_INCLUDE)
      message( STATUS "# Include \"${CMAKE_CURRENT_LIST_FILE}\"" )
   endif()

   option( MULLE_TRANSITIVE_SOURCE_INCLUDE
           "Propagate source include directories to add_subdirectory consumers"
           ON)

   # we never copy our headers, because they are already nicely layed out
   if( MULLE_USE_TRANSITIVE_SOURCE_INCLUDE)
      target_include_directories( "${LIBRARY_LINK_TARGET}" INTERFACE
         $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>)
    endif()

endif()
