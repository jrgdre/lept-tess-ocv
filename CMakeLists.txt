# Find out what build environment cmake sees and store it in some temporary
# files, so the build script can read the findings back.
#
# (c)2020 Medical Data Solutions GmbH
# License: MIT (s. License.md)
#
# authors:
#   jrgdre  "Joerg Drechsler, Medical Data Solutions GmbH"
#
# versions:
#   1.0.0 2020-03-26 jrgdre "initial release, working MSVC 19 dynamic linking"

cmake_minimum_required( VERSION 3.15 )
project( build_environment_check )

cmake_host_system_information( RESULT OS_NAME QUERY OS_NAME )
cmake_host_system_information( RESULT OS_RELEASE QUERY OS_RELEASE )
cmake_host_system_information( RESULT OS_PLATFORM QUERY OS_PLATFORM )
file( WRITE ./.tmp/__BUILD_CPU                  ${CMAKE_HOST_SYSTEM_PROCESSOR} )
file( WRITE ./.tmp/__BUILD_OS                   ${OS_NAME}                     )
file( WRITE ./.tmp/__BUILD_OS_RELEASE           ${OS_RELEASE}                  )
file( WRITE ./.tmp/__BUILD_OS_PLATFORM          ${OS_PLATFORM}                 )
file( WRITE ./.tmp/__BUILD_CXX_COMPILER_ID      ${CMAKE_CXX_COMPILER_ID}       )
file( WRITE ./.tmp/__BUILD_CXX_COMPILER_VERSION ${CMAKE_CXX_COMPILER_VERSION}  )

find_path( GL_INCLUDE_DIR NAMES gl/GL.h PATH $ENV{INCLUDE} )
file( WRITE ./.tmp/__GL_INCLUDE_DIR ${GL_INCLUDE_DIR} )