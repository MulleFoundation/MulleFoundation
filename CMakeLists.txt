#
# You rarely need to edit this file. To add or remove files in your
# project edit the "src" folders contents and run `mulle-sde reflect`
#
#
# A convenient way to add a new source file is:
#    mulle-sde add src/foo.m
#
cmake_minimum_required( VERSION 3.13)

project( MulleFoundation VERSION 0.29.0 LANGUAGES C)

set( MULLE_PROJECT_TYPE "Library")
set( PROJECT_VERSION  0.29.0)

### mulle-sde environment

# add cmake module paths to search path
list( INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake/share")
list( INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake/reflect")
list( INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include( Environment)


include_directories( src)

include( Files)

# include( IDESupport OPTIONAL)


# Add the platform-specific constituent sources to the build.
# The patternfiles keep each platform's files out of the reflect-generated
# generic SOURCES/STAGE2_SOURCES/PUBLIC_HEADERS, so we join the matching
# ones here for the platform we are building for.
#
# Dependency chain:  OSBase <- Posix <- Linux / BSD <- Darwin / FreeBSD
#                    OSBase <- Windows
#
set( PLATFORM_SOURCES)
set( PLATFORM_STAGE2_SOURCES)
set( PLATFORM_HEADERS)

if( WIN32)
   list( APPEND PLATFORM_SOURCES ${WINDOWS_SOURCES})
   list( APPEND PLATFORM_STAGE2_SOURCES ${WINDOWS_STAGE2_SOURCES})
   list( APPEND PLATFORM_HEADERS ${WINDOWS_HEADERS})
else()
   list( APPEND PLATFORM_SOURCES ${POSIX_SOURCES})
   list( APPEND PLATFORM_STAGE2_SOURCES ${POSIX_STAGE2_SOURCES})
   list( APPEND PLATFORM_HEADERS ${POSIX_HEADERS})

   if( APPLE)
      # Darwin runs atop BSD + Posix
      list( APPEND PLATFORM_SOURCES ${BSD_SOURCES} ${DARWIN_SOURCES})
      list( APPEND PLATFORM_STAGE2_SOURCES ${BSD_STAGE2_SOURCES} ${DARWIN_STAGE2_SOURCES})
      list( APPEND PLATFORM_HEADERS ${BSD_HEADERS} ${DARWIN_HEADERS})
   elseif( CMAKE_SYSTEM_NAME MATCHES "FreeBSD")
      # FreeBSD runs atop BSD + Posix
      list( APPEND PLATFORM_SOURCES ${BSD_SOURCES} ${FREEBSD_SOURCES})
      list( APPEND PLATFORM_STAGE2_SOURCES ${BSD_STAGE2_SOURCES} ${FREEBSD_STAGE2_SOURCES})
      list( APPEND PLATFORM_HEADERS ${BSD_HEADERS} ${FREEBSD_HEADERS})
   elseif( CMAKE_SYSTEM_NAME MATCHES "BSD|DragonFly")
      list( APPEND PLATFORM_SOURCES ${BSD_SOURCES})
      list( APPEND PLATFORM_STAGE2_SOURCES ${BSD_STAGE2_SOURCES})
      list( APPEND PLATFORM_HEADERS ${BSD_HEADERS})
   else()
      # Linux, Android, and other generic UNIX use the Linux layer
      list( APPEND PLATFORM_SOURCES ${LINUX_SOURCES})
      list( APPEND PLATFORM_STAGE2_SOURCES ${LINUX_STAGE2_SOURCES})
      list( APPEND PLATFORM_HEADERS ${LINUX_HEADERS})
   endif()
endif()

list( APPEND SOURCES ${PLATFORM_SOURCES})
list( APPEND STAGE2_SOURCES ${PLATFORM_STAGE2_SOURCES})
list( APPEND PUBLIC_HEADERS ${PLATFORM_HEADERS})

# INSTALL_PUBLIC_HEADERS was already finalized from PUBLIC_HEADERS by
# include( Files) above (which runs Headers.cmake) - i.e. before this platform
# block appends PLATFORM_HEADERS to PUBLIC_HEADERS. So the append above does not
# reach the exported/installed header set on its own. Fold PLATFORM_HEADERS into
# INSTALL_PUBLIC_HEADERS here too, otherwise the umbrella's unconditional
# platform #imports (e.g. <MulleObjCPosixFoundation/...>) are missing from
# ${CMAKE_BINARY_DIR}/include and an add_subdirectory() consumer cannot compile
# the umbrella. Keeping this in CMakeLists.txt lets Headers.cmake stay stock.
list( APPEND INSTALL_PUBLIC_HEADERS ${PLATFORM_HEADERS})
list( REMOVE_DUPLICATES INSTALL_PUBLIC_HEADERS)

unset( PLATFORM_SOURCES)
unset( PLATFORM_STAGE2_SOURCES)
unset( PLATFORM_HEADERS)

unset( SUB_PROJECT_NAMES)
file( GLOB SUB_PROJECT_PATHS src/Mulle*)

foreach( SUB_PROJECT_PATH ${SUB_PROJECT_PATHS})
   if( IS_DIRECTORY "${SUB_PROJECT_PATH}")
      get_filename_component( SUB_PROJECT_NAME "${SUB_PROJECT_PATH}" NAME)
      list( APPEND SUB_PROJECT_NAMES "${SUB_PROJECT_NAME}")
      message( STATUS "SUB_PROJECT_NAME = ${SUB_PROJECT_NAME}")
   endif()
endforeach()
set( SUB_PROJECT_NAMES ${SUB_PROJECT_NAMES} CACHE INTERNAL "sub-project names")


if( HEADER_PHASE)
   #
   # need to install like the embedded subprojects would
   #
   unset(REMAINING_PUBLIC_HEADERS)
   foreach( TMP_HEADER ${INSTALL_PUBLIC_HEADERS};${PUBLIC_GENERIC_HEADERS})
      get_filename_component( TMP_PROJECT_NAME "${TMP_HEADER}" DIRECTORY)
      get_filename_component( TMP_PROJECT_NAME "${TMP_PROJECT_NAME}" NAME)
      list( FIND SUB_PROJECT_NAMES "${TMP_PROJECT_NAME}" TMP_INDEX)
      # can't stay as a symlink, otherwise symlinks get installed which
      # fail, as they are relative
      file( REAL_PATH "${TMP_HEADER}" TMP_HEADER)
      if( NOT( "${TMP_INDEX}" EQUAL -1))
         install( FILES ${TMP_HEADER} DESTINATION "include/${TMP_PROJECT_NAME}")
      else()
         list( APPEND REMAINING_PUBLIC_HEADERS "${TMP_HEADER}")
      endif()
   endforeach()

   unset(REMAINING_PRIVATE_HEADERS)
   foreach( TMP_HEADER ${INSTALL_PRIVATE_HEADERS};${PRIVATE_GENERIC_HEADERS})
      get_filename_component( TMP_PROJECT_NAME "${TMP_HEADER}" DIRECTORY)
      get_filename_component( TMP_PROJECT_NAME "${TMP_PROJECT_NAME}" NAME)
      list( FIND SUB_PROJECT_NAMES "${TMP_PROJECT_NAME}" TMP_INDEX)
      # can't stay as a symlink, otherwise symlinks get installed which
      # fail, as they are relative
      file( REAL_PATH "${TMP_HEADER}" TMP_HEADER)
      if( NOT( "${TMP_INDEX}" EQUAL -1))
         install( FILES ${TMP_HEADER} DESTINATION "include/${TMP_PROJECT_NAME}")
      else()
         list( APPEND REMAINING_PRIVATE_HEADERS "${TMP_HEADER}")
      endif()
   endforeach()

   install( FILES ${REMAINING_PUBLIC_HEADERS}  DESTINATION "include/${PROJECT_NAME}")
   install( FILES ${REMAINING_PRIVATE_HEADERS} DESTINATION "include/${PROJECT_NAME}")
   install( FILES ${INSTALL_CMAKE_INCLUDES}    DESTINATION "include/${PROJECT_NAME}/cmake")

   # short cut out
   if( NOT COMPILE_PHASE AND NOT LINK_PHASE)
      return()
   endif()
endif()

if( LINK_PHASE)
   include( Dependencies OPTIONAL)
endif()

include( Library)

# use LIBRARY_COMPILE_TARGET for compiler options
target_compile_definitions( "${LIBRARY_COMPILE_TARGET}" PUBLIC)
target_compile_options( "${LIBRARY_COMPILE_TARGET}" PUBLIC)

#
# The sub-projects above are amalgamated: their sources are compiled straight
# into this library. Each one marks its exported symbols with
# <SUB_PROJECT>_GLOBAL / <SUB_PROJECT>_GLOBAL_VAR, and those expand to
# dllexport only while that sub-project's own <SUB_PROJECT>_BUILD is defined.
#
# A standalone build of a sub-project defines it (Library.cmake derives it from
# the project name), so on its own the sub-project is fine. Here it was missing,
# so the vendored headers declared their globals as dllimport - inside the very
# library that defines them. On Windows a reference to such a global then goes
# through an import thunk and libMulleFoundation.dll ends up importing symbols
# it also defines. llvm-mingw refuses to export those: they disappear from both
# the export table and the .dll.a, and consumers (think MulleScion) fail with
#
#    undefined symbol: __declspec(dllimport) NSFileTypeDirectory
#
# Derive the identifier with the same snakeCaseString() rule the sub-project's
# own .mulle/etc/env/environment-project.sh uses, so a newly vendored
# sub-project is covered without maintaining a list here.
#
if( LIBRARY_COMPILE_TARGET)
   foreach( SUB_PROJECT_NAME ${SUB_PROJECT_NAMES})
      snakeCaseString( "${SUB_PROJECT_NAME}" SUB_PROJECT_IDENTIFIER)
      string( TOUPPER "${SUB_PROJECT_IDENTIFIER}" SUB_PROJECT_UPCASE_IDENTIFIER)
      if( NOT "${SUB_PROJECT_UPCASE_IDENTIFIER}" STREQUAL "${LIBRARY_UPCASE_IDENTIFIER}")
         message( STATUS "Amalgamating sub-project ${SUB_PROJECT_NAME} as ${SUB_PROJECT_UPCASE_IDENTIFIER}_BUILD")
         target_compile_definitions( "${LIBRARY_COMPILE_TARGET}" PRIVATE "${SUB_PROJECT_UPCASE_IDENTIFIER}_BUILD")
         if( LIBRARY_STAGE2_TARGET)
            target_compile_definitions( "${LIBRARY_STAGE2_TARGET}" PRIVATE "${SUB_PROJECT_UPCASE_IDENTIFIER}_BUILD")
         endif()
      endif()
   endforeach()
   unset( SUB_PROJECT_IDENTIFIER)
   unset( SUB_PROJECT_UPCASE_IDENTIFIER)
endif()

# use LIBRARY_LINK_TARGET for linker options
if( LINK_PHASE)
   target_link_options( "${LIBRARY_LINK_TARGET}" PUBLIC)

   #
   # CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS (DLL_EXPORT_ALL) is a no-op for the
   # llvm-mingw toolchain: the option is only implemented for MS linkers. What
   # happens instead is that the MinGW linker exports every defined symbol by
   # default, but it stops doing so as soon as anything is explicitly
   # dllexport'ed - which the block above now does. Ask for the full export
   # surface explicitly, otherwise symbols that are still declared bare
   # (mulle_windows_tm_get_time, NSGlobalDomain, NSLog, ...) would lose their
   # export by the mere act of adding those defines.
   #
   if( (WIN32 OR MINGW) AND NOT MSVC AND BUILD_SHARED_LIBS)
      target_link_options( "${LIBRARY_LINK_TARGET}" PRIVATE "-Wl,--export-all-symbols")
   endif()

   #
   # The idea is this is for non mulle-sde consumers to get the dependency
   # to mulle-core right. In shared lib configuration this is not necessary
   # Headers may still be a problem though
   # MEMO: should we do this in Library.cmake unconditionally ?
   if( NOT BUILD_SHARED_LIBS AND MULLE_TRANSITIVE_LINK_LIBRARIES)
      target_link_libraries( "${LIBRARY_LINK_TARGET}" PUBLIC
               ${ALL_LOAD_DEPENDENCY_LIBRARIES}
               ${DEPENDENCY_LIBRARIES}
               ${DEPENDENCY_FRAMEWORKS}
               ${OPTIONAL_DEPENDENCY_LIBRARIES}
               ${OPTIONAL_DEPENDENCY_FRAMEWORKS}
               ${OS_SPECIFIC_LIBRARIES}
               ${OS_SPECIFIC_FRAMEWORKS})
   endif()

   # Automatic force-loading is intentionally disabled for external CMake
   # consumers. They decide explicitly which libraries to link and how to
   # force-load them. The former implementation is retained below for
   # reference.
   #
   # if( NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
   #    set( SELF_ALL_LOAD_LIBRARY "$<TARGET_FILE:${LIBRARY_LINK_TARGET}>")
   #    CreateForceAllLoadList( SELF_ALL_LOAD_LIBRARY
   #                            SELF_FORCE_ALL_LOAD_OPTIONS
   #                            SELF_LEFTOVER_ALL_LOAD_OPTIONS)
   #    target_link_options( "${LIBRARY_LINK_TARGET}" INTERFACE
   #       ${SELF_FORCE_ALL_LOAD_OPTIONS})
   #    unset( SELF_ALL_LOAD_LIBRARY)
   #    unset( SELF_FORCE_ALL_LOAD_OPTIONS)
   #    unset( SELF_LEFTOVER_ALL_LOAD_OPTIONS)
   # endif()
endif()

include( InstallLibrary)

# Install the API TOC of each constituent library.
# clib flattens paths to basename, so "asset/dox/api/toc/index.md" arrives as
# "src/<name>/index.md" and legacy "asset/dox/TOC.md" as "src/<name>/TOC.md".
# Always install into the canonical path mulle-sde api expects.
if( LINK_PHASE)
   foreach( SUB_PROJECT_NAME ${SUB_PROJECT_NAMES})
      set( SUB_ASSETS_TOC "${CMAKE_CURRENT_SOURCE_DIR}/src/${SUB_PROJECT_NAME}/index.md")
      if( NOT EXISTS "${SUB_ASSETS_TOC}")
         set( SUB_ASSETS_TOC "${CMAKE_CURRENT_SOURCE_DIR}/src/${SUB_PROJECT_NAME}/TOC.md")
      endif()
      if( EXISTS "${SUB_ASSETS_TOC}")
         message( STATUS "Installing API TOC from ${SUB_PROJECT_NAME}")
         install( FILES "${SUB_ASSETS_TOC}"
                  DESTINATION "share/${SUB_PROJECT_NAME}/dox/api/toc"
                  RENAME "index.md"
                  PERMISSIONS OWNER_WRITE OWNER_READ
                              GROUP_READ
                              WORLD_READ)
      endif()
   endforeach()
endif()

if( LINK_PHASE)
   include( AddSubdirectorySupport)
   include( FindPackageSupport)
endif()


include( FinalOutput OPTIONAL)
