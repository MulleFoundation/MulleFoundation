cmake_minimum_required (VERSION 3.0)

project (Foundation)


# need expat
#
# https://stackoverflow.com/questions/10860366/how-do-i-link-expat-into-a-project
#
include( FindEXPAT)
find_package(EXPAT 2.0 REQUIRED)

#include( FindICU)
#find_package(ICU 4.4 REQUIRED)


set( CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_SOURCE_DIR}/mulle-configuration/cmake)
message( STATUS "CMAKE_MODULE_PATH is ${CMAKE_MODULE_PATH}")
message( STATUS "CMAKE_BUILD_TYPE is ${CMAKE_BUILD_TYPE}")

set( MULLE_LANGUAGE "ObjC")

if( "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  include( Debug)
else()
  include( Release)
endif()


include( CMakeSourcesAndHeaders.txt)
include( CMakeDependencies.txt)


# set BUILD_SHARED_LIBS to "ON" to create a shared library

add_library( Foundation
${SOURCES}
${PUBLIC_HEADERS}
${PRIVATE_HEADERS}
CMakeDependencies.txt
CMakeSourcesAndHeaders.txt
)

target_link_libraries( Foundation
${BEGIN_ALL_LOAD}
${OBJC_DEPENDENCY_LIBRARIES}
${C_DEPENDENCY_LIBRARIES}
${END_ALL_LOAD}
${OS_SPECIFIC_LIBARIES}
)
#${ICU_LIBRARIES}



message( STATUS "OBJC_DEPENDENCY_NAMES is ${OBJC_DEPENDENCY_NAMES}")

# runs in build dir
add_custom_command( TARGET Foundation
   POST_BUILD
   COMMAND ${DEPENDENCIES_DIR}/bin/mulle-objc-create-dependencies-inc -v
           -o ${CMAKE_SOURCE_DIR}/src/dependencies.inc -
           ${OBJC_DEPENDENCY_NAMES}
)

set( PUBLIC_HEADERS
${PUBLIC_HEADERS}
"CMakeDependencies.txt"
"src/dependencies.inc"
)



if( APPLE AND BUILD_SHARED_LIBS)
   set_target_properties( Foundation PROPERTIES
FRAMEWORK TRUE
FRAMEWORK_VERSION A
# MACOSX_FRAMEWORK_IDENTIFIER "com.mulle-kybernetik.Foundation"
# VERSION "0.0.0"
# SOVERSION  "0.0.0"
PUBLIC_HEADER "${PUBLIC_HEADERS}"
PRIVATE_HEADER "${PRIVATE_HEADERS}"
RESOURCE "${RESOURCES}"
)
   install( TARGETS Foundation DESTINATION "Frameworks")
else()
   install( TARGETS Foundation DESTINATION "lib")
   install( FILES ${PUBLIC_HEADERS} DESTINATION "include/Foundation")
   install( FILES ${RESOURCES} DESTINATION "share/Foundation")
endif()

