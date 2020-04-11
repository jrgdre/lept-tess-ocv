#!/bin/bash -e

## Leptonica, Tesseract, OpenCV build
# Tries to build all packages and the dependencies from the most recent stable
# release master commits in there git repositories (if exists).
#
# prerequisites:
#   - git
#   - sed
#   - grep
#   - cmake
#   - curl
#   - a c/c++ compiler
#   - nasm
#   - pkg-config
#   - python 2 (optional)
#   - you need to define the PYTHON3 environment variable, that points to your
#     python 3 binary (optional)
#
# usage:
#   s. ReadMe.md
#
# (c)2020 Medical Data Solutions GmbH
# License: MIT (s. License.md)
#
# todo:
#   - gcc Windows
#   - LLVM Windows
#   - Linux
#   - OSX
#
# authors:
#   jrgdre  "Joerg Drechsler, Medical Data Solutions GmbH"
#
# versions:
#   2.0.0 2020-04-11 jrgdre "add viz<-vtk<-freeglut, MSVC 19 static linking"
#   1.0.0 2020-03-26 jrgdre "initial release, working MSVC 19 dynamic linking"


## based on:
# - https://docs.opencv.org/master/d3/d52/tutorial_windows_install.html
# - http://www.sk-spell.sk.cx/building-tesseract-and-leptonica-with-cmake-and-clang-on-windows

## ===================
##  support functions
## ===================

## Add additional compiler definitions to a project
# $1 project source directory
# $2[] array of compiler definitions to add
add_compiler_definitions() {
    local project=${1}
    local comp_defs_list_name=$2[@]
    local comp_defs=("${!comp_defs_list_name}")
    local defaults=(\
        "-MP " \
        "-MT " \
        "-D_CRT_SECURE_NO_WARNINGS " \
        "-DLZMA_API_STATIC " \
        "-DLIBARCHIVE_STATIC " \
        "-DFREEGLUT_STATIC " \
        "-DOPJ_STATIC" \
    )
    local codefs="${defaults[@]} ${comp_defs[@]}"
    local cmake_file="${src}/CMakeLists.txt"
    local lno=`cat ${cmake_file} | grep -ne "project("| cut -f1 -d:`
    echo "-- adding definitions to ${project} ( ${codefs} )"
    sed -i "
        # match one-liners project declarations
        /project\s*(.*)/ {
            a \
            add_definitions( ${codefs} )
        }

        # match multi-liners project declarations
        /project\s*(.*)/ !{
            /project\s*(/ {
                N
                :loop
                /)/ !{
                    N
                    b loop
                }
                /)/ {
                    a \
                    add_definitions( ${codefs} )
                }
            }
        }
    " ${cmake_file}
}

## Add additional linkes search directories to a projects
# $1 project source directory
add_link_directories() {
    local ldirs="${LIB_INSTALL_DIR}"
    # posix -> windows
    ldirs=$(sed 's|^/\([a-z,A-Z]\)/|\1:/|' <<< ${ldirs})

    local cmake_file="${src}/CMakeLists.txt"
    echo "-- adding to the linker search path ${project} ( ${ldirs} )"
    sed -i "
        # match one-liners project declarations
        /project\s*(.*)/ {
            a \
    link_directories( ${ldirs} )
        }

        # match multi-liners project declarations
        /project\s*(.*)/ !{
            /project\s*(/ {
                N
    :loop
                /)/ !{
                    N
                    b loop
                }
                /)/ {
                    a \
    link_directories( ${ldirs} )
                }
            }
        }
    " ${cmake_file}
}

## find out what we are building on and with
# sets global variables:
# - CPU
# - CXX_COMPILER_ID
# - CXX_COMPILER_VERSION
# - OS
# - OS_PLATFORM
# - OS_RELEASE
check_environment() {
    mkdir -p ./.tmp
    cd ./.tmp
    cmake ..
    CPU=`cat __BUILD_CPU`
    CXX_COMPILER_ID=`cat __BUILD_CXX_COMPILER_ID`
    CXX_COMPILER_VERSION=`cat __BUILD_CXX_COMPILER_VERSION`
    OS=`cat __BUILD_OS`
    OS_PLATFORM=`cat __BUILD_OS_PLATFORM`
    OS_RELEASE=`cat __BUILD_OS_RELEASE`
    cd ..
    echo "cleaning-up ./.tmp"
    rm -rf ./.tmp
}

## clean-up all downloads, build and install files and start from scratch
clean_all() {
    if [ ${SRC_DIR} == ${REPO_DIR} ]; then
        echo "I'm asked to delete ${REPO_DIR}"
        echo "That doesn't sound right. I'm _not_ going to do that!"
        echo "Please check the script. Something is wrong."
        exit 1
    fi
    rm -rf ${SRC_DIR}
    clean_build_and_install
}

## clean-up build and install files
clean_build_and_install() {
    if [ ${OUT_DIR} != ${REPO_DIR} ]; then
        rm -rf ${OUT_DIR}
    else
        rm -rf ${BUILD_DIR}
        rm -rf ${INSTALL_DIR}
    fi
}

## Build a project that supports CMake
# $1 project name
cmake_build() {
    local project=${1}
    echo " "
    echo "building ${project} in ${BUILD_DIR}/${project} ..."
    echo " "
    pushd ${BUILD_DIR}/${project}
        cmake --build ${BUILD_DIR}/${project} \
            --config ${BUILD_TYPE} \
            --target install
    popd
    reset ${project} # revert all changes to the project source repository
}

## Configure a project that supports CMake
# $1     project name
# $2     source directory
# $3[]   array of additional cmake parameters
# $4[][] array of additional libraries (s. e.g. zlib for structure)
# $5[]   array of additional compiler parameters
cmake_configure() {
    local project=${1}
    local src=${2}
    local params_list_name=
    local params_list=
    local targets_libs_array_name=
    local targets_libs_array=
    local comp_defs_name=
    local comp_defs=
    echo " "
    echo "configuring ${project} in ${src} ..."
    echo " "
    ## patch CMakeList.txt
    replace_cmake_version ${src} # inject cmake_minimum_required(VERSION ...
    # extract the additional parameters, from ${3[]}
    if [ ! -z ${3} ]; then
        params_list_name=$3[@]
        params=("${!params_list_name}")
    fi
    cmake_params_get "${project}" params # sets CMAKE_PARAMS
    # extract additional libraries for the different targets from ${4[][]}
    if [ ! -z ${4} ]; then
        targets_libs_array_name=$4[@]
        targets_libs_array=("${!targets_libs_array_name}")
        targets_add_libraries "${src}" targets_libs_array
    fi
    if [ ! -z ${5} ]; then
        comp_defs_list_name=$5[@]
        comp_defs=("${!comp_defs_list_name}")
        add_link_directories "${src}"
        add_compiler_definitions "${src}" comp_defs
    fi
    # configure
    mkdir -p ${BUILD_DIR}/${project}
    pushd ${BUILD_DIR}/${project}
        if [  ! -z ${GENERATOR}  ]; then
            cmake ${src} -G "${GENERATOR}" ${CMAKE_PARAMS}
        else
            cmake ${src} ${CMAKE_PARAMS}
        fi
    popd
}

## produce the string of configuration parameters for cmake_configure
# This function sets the global CMAKE_PARAMS variable.
# $1 project name
# $2[] array of additional parameters
cmake_params_get() {
    CMAKE_PARAMS=""
    local project=${1}
    local module_paths="${REPO_DIR}/cmake/"
    echo "-- CMAKE_MODULE_PATH=${module_paths} "
    local prefix_paths="${SRC_DIR}/${project}/\;${BUILD_DIR}/${project}/\;${INSTALL_DIR}/\;${LIB_INSTALL_DIR}/"
    echo "-- CMAKE_PREFIX_PATH=${prefix_paths}"
    local conf=(\
        "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded " \
        "-DCMAKE_C_CREATE_STATIC_LIBRARY=ON " \
        "-DCMAKE_CXX_CREATE_STATIC_LIBRARY=ON " \
        "-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} " \
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY " \
        "-DCMAKE_EXE_LINKER_FLAGS=/NODEFAULTLIB:LIBCMT " \
        "-DBUILD_SHARED_LIBS=OFF " \
        "-Wno-deprecated " \
        "-Wno-dev " \
        "-DCMAKE_MODULE_PATH=${module_paths} " \
        "-DCMAKE_PREFIX_PATH=${prefix_paths} " \
    )
    if [ ! -z ${2} ]; then
        # extract the additional parameters, from the named array
        local name=$2[@]
        local arg_list=("${!name}")
        local args=${arg_list[@]}
        if [ ${#args} -gt 0 ]; then
            echo "-- adding cmake parameters ( ${args} )"
        fi
    else
        local args=
    fi
    conf+=( "${args}" )
    CMAKE_PARAMS="${conf[@]}"
}

## create the source, build and install directories
create_common_directories() {
    if [  ! -d "${REPO_DIR}/src"  ]; then
        mkdir -p "src"
    fi
    if [  ! -d "${BUILD_DIR}"  ]; then
        mkdir -p "${BUILD_DIR}"
    fi
    if [  ! -d "${INSTALL_DIR}"  ]; then
        mkdir -p "${INSTALL_DIR}"
    fi
    if [  ! -d "${BIN_INSTALL_DIR}"  ]; then
        mkdir -p "${BIN_INSTALL_DIR}"
    fi
    if [  ! -d "${INC_INSTALL_DIR}"  ]; then
        mkdir -p "${INC_INSTALL_DIR}"
    fi
    if [  ! -d "${LIB_INSTALL_DIR}"  ]; then
        mkdir -p "${LIB_INSTALL_DIR}"
    fi
}

## debug print the values of all global variables
debug_print_global_vars() {
    echo "CPU                  = ${CPU}"
    echo "OS                   = ${OS}"
    echo "OS_PLATFORM          = ${OS_PLATFORM}"
    echo "OS_RELEASE           = ${OS_RELEASE}"
    echo "PROJECT              = ${PROJECT}"
    echo "INITIAL_BUILD        = ${INITIAL_BUILD}"
    echo "CLEAN_BUILD          = ${CLEAN_BUILD}"
    echo "UPDATE_REPOS         = ${UPDATE_REPOS}"
    echo "GENERATOR            = ${GENERATOR}"
    echo "BUILD_TYPE           = ${BUILD_TYPE}"
    echo "CXX_COMPILER_ID      = ${CXX_COMPILER_ID}"
    echo "CXX_COMPILER_VERSION = ${CXX_COMPILER_VERSION}"
    echo "REPO_DIR             = ${REPO_DIR}"
    echo "INSTALL_DIR          = ${INSTALL_DIR}"
}

## initialize directory tree
# sets global variables:
# - REPO_DIR
# - SRC_DIR
# - OUT_DIR
# - BUILD_DIR
# - INSTALL_DIR
# - BIN_INSTALL_DIR
# - INC_INSTALL_DIR
# - LIB_INSTALL_DIR
define_common_directories() {
    REPO_DIR=$(pwd)
    SRC_DIR=${REPO_DIR}/src
    OUT_DIR=${REPO_DIR}
    if [  ! -z ${OS}  ]; then
        OUT_DIR=${OUT_DIR}/${OS}
    fi
    if [  ! -z ${PROJECT}  ]; then
        OUT_DIR=${OUT_DIR}-${PROJECT}
    fi
    if [  ! -z ${CPU}  ]; then
        OUT_DIR=${OUT_DIR}-${CPU}
    fi
    if [  ! -z ${BUILD_TYPE}  ]; then
        OUT_DIR=${OUT_DIR}-${BUILD_TYPE}
    fi
    BUILD_DIR=${OUT_DIR}/build
    INSTALL_DIR=${OUT_DIR}/install
    BIN_INSTALL_DIR=${INSTALL_DIR}/bin
    INC_INSTALL_DIR=${INSTALL_DIR}/include
    LIB_INSTALL_DIR=${INSTALL_DIR}/lib
}

## clone or pull a repository
# Since we lock the repos to a specific commit, we assume that existing repos
# are at this commit.
# - We alway clone non-exiting repos.
# - We only pull exiting repos, if UPDATE_REPOS is true.
# params:
# $1 project name
# $2 remote reporsitory to pull
# $3 branch to pull
# $4 ref to switch to (optional)
git_clone_pull() {
    local project=${1}
    local repo=${2}
    local branch=${3}
    local ref=${4}
    echo " "
    echo "checking ${project} repository"
    echo " "
    pushd ${SRC_DIR}
        # clone / pull
        if [ ! -d "${project}" ]; then
            git clone ${repo} --branch ${branch}
        else
            if [ ${UPDATE_REPOS} = true ]; then
                pushd ${SRC_DIR}/${project}
                    echo "pulling ${project}"
                    git pull ${repo}
                popd
            fi
        fi
        # switch to a specific commit, if specified
        if [ ! -z ${ref} ]; then
            pushd $SRC_DIR/${project}
                git switch --detach ${ref}
            popd
        fi
    popd
}

## initialize the values of all global variables
init_global_vars() {
    CPU=""
    OS=""
    OS_PLATFORM=""
    OS_RELEASE=""
    PROJECT=""
    INITIAL_BUILD=false
    CLEAN_BUILD=false
    UPDATE_REPOS=false
    GENERATOR=""
    BUILD_TYPE=Release
    CXX_COMPILER_ID=""
    CXX_COMPILER_VERSION=""
    REPO_DIR=""
    INSTALL_DIR=""
}

## parse the command line arguments for the script
# may set gobal variables:
# - ARCH
# - BUILD_TYPE
# - CLEAN_BUILD
# - GENERATOR
# - INITIAL_BUILD
# - OS
# - PROJECT
# - UPDATE_REPOS
parse_command_line() {
    while [ ! -z ${#} ]; do
        case "${1}" in
            -h|--help)
                echo "Leptonica, Tesseract, OpenCV build script"
                echo "(c)2020 Medical Data Solutions GmbH, MIT license"
                echo " "
                echo "${SCRIPT_NAME} [options]"
                echo " "
                echo "options:"
                echo "-h, --help                        show this brief help"
                echo "-o, --os <operating-system>       override OS the build is for"
                echo "-p, --project <project-name>      give it a name do differentiate projects"
                echo "-g, --generator <CMAKE_GENERATOR> override the default CMAKE_GENERATOR"
                echo "-a, --arch <platform-name>        define an architecture for CMAKE_GENERATOR (if supported by generator)"
                echo "-b, --build <CMAKE_BUILD_TYPE>    override the default CMAKE_BUILD_TYPE (Release)"
                echo "-c, --clean                       remove all intermediate files of a previous build before building"
                echo "-i, --initial                     remove all source and intermediate files and start from scratch"
                echo "-u, --update                      clone- / pull- update all repositories"
                exit 0
                ;;
            -a|--arch)
                shift
                if [ ! -z ${#} ]; then
                    ARCH=${1}
                else
                    echo "no architecture specified, remove switch for default architecture"
                fi
                shift
                ;;
            -b|--build)
                shift
                if [ ! -z ${#} ]; then
                    BUILD_TYPE=${1}
                else
                    echo "no build-type specified"
                fi
                shift
                ;;
            -c|--clean)
                CLEAN_BUILD=true
                shift
                ;;
            -g|--generator)
                shift
                if [ ! -z $# ]; then
                    echo "GENERATOR set to ${1}"
                    GENERATOR=${1}
                else
                    echo "no generator specified, remove switch for platform default generator"
                fi
                shift
                ;;
            -i|--initial)
                INITIAL_BUILD=true
                shift
                ;;
            -o|--os)
                shift
                if [ ! -z ${#} ]; then
                    OS=${1}
                else
                    echo "no operating system specified, remove switch to omit"
                fi
                shift
                ;;
            -p|--project)
                shift
                if [ ! -z ${#} ]; then
                    PROJECT=${1}
                else
                    echo "no project name specified, remove switch to omit"
                fi
                shift
                ;;
            -u|--update)
                UPDATE_REPOS=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
}

## make popd shut up
# from https://stackoverflow.com/questions/25288194/dont-display-pushd-popd-stack-across-several-bash-scripts-quiet-pushd-popd
popd () {
    command popd "${@}" > /dev/null
}

## make pushd shut up
# from https://stackoverflow.com/questions/25288194/dont-display-pushd-popd-stack-across-several-bash-scripts-quiet-pushd-popd
pushd () {
    command pushd "${@}" > /dev/null
}

## Replace the VERSION specified in cmake_minimum_required for a project
# We use this to set a number of CMake policies we need at there NEW behaviour.
# params:
# $1 CMakeLists.txt directory
replace_cmake_version() {
    local src=${1}
    sed -i 's|cmake_minimum_required*|cmake_minimum_required(VERSION 3.17 FATAL_ERROR) # was |' \
        ${src}/CMakeLists.txt

}

## Reset a project's source repository to the reference provided
# $1 project
reset() {
    local project=${1}
    pushd "${SRC_DIR}/${project}"
        git reset --hard > /dev/null
    popd
}

## Add libraries for a CMake target
# Search for a CMakeList.txt in the project's source and source sub-directories
# for an target_link_libraries() or add_executable() command for the target
# given and append or add the target_link_libraries entries with the additional
# libraries for the target.
# $1   projects source directory
# $2   cmake target
# $3[] array of libraries to add
target_add_libraries() {
    local abbort=false
    local src=${1}
    local cmake_target=${2}
    local libs_array_name=$3[@]
    local libs_array=("${!libs_array_name}")
    local cmake_file=
    pushd ${src}
        cmake_file=`grep --include=CMakeLists.txt -rile "target_link_libraries\s*(\s*${cmake_target}" || true`
        if [ ! -z "${cmake_file}" ]; then
            echo "-- adding libraries to ${cmake_file} ${cmake_target} ( ${libs_array[@]} )"
            sed -i "
                # match one-liners executable declarations
                /target_link_libraries\s*(\s*${cmake_target}.*)/ {
                    a \
                    target_link_libraries( ${cmake_target} ${libs_array[@]} )
                }

                # match multi-liners executable declarations
                /target_link_libraries\s*(\s*${cmake_target}.*)/ !{
                    /target_link_libraries\s*(\s*${cmake_target}/ {
                        N
                        :loop
                        /)/ !{
                            N
                            b loop
                        }
                        /)/ {
                            a \
                            target_link_libraries( ${cmake_target} ${libs_array[@]} )
                        }
                    }
                }
            " ${cmake_file}
        else
            cmake_file=`grep --include=CMakeLists.txt -rile "add_executable\s*(\s*${cmake_target}" || true`
            if [ ! -z "${cmake_file}" ]; then
                echo "-- adding libraries to ${cmake_file} ${cmake_target} ( ${libs_array[@]} )"
                sed -i "
                    # match one-liners executable declarations
                    /add_executable\s*(\s*${cmake_target}.*)/ {
                        a \
                        target_link_libraries( ${cmake_target} ${libs_array[@]} )
                    }

                    # match multi-liners executable declarations
                    /add_executable\s*(\s*${cmake_target}.*)/ !{
                        /add_executable\s*(\s*${cmake_target}/ {
                            N
                            :loop
                            /)/ !{
                                N
                                b loop
                            }
                            /)/ {
                                a \
                                target_link_libraries( ${cmake_target} ${libs_array[@]} )
                            }
                        }
                    }
                " ${cmake_file}
            else
                echo "target ${cmake_target} not found"
                abbort=true
            fi
        fi
    popd
    if [ ${abbort} = true ]; then
        exit 1
    fi
}

## Add libraries to the CMake targets
# Be aware that:
# - any '_M_' sequence in a target name will be replaced with the '-' character
# We use this escape sequence to build a valid identifiers from target names
# that otherwise would be invalid for variable names.
# $1     projects source directory
# $2[][] array of targets and libraries to add
targets_add_libraries() {
    local src=${1}
    local targets_libs=
    if [ ! -z ${2} ]; then
        # extract the list names, from the named array
        local array_name=$2[@]
        local array=("${!array_name}")
        local cmake_targets=${array[@]}
        for cmake_target in ${cmake_targets[@]}; do
            targets_libs=("${!cmake_target}")
            cmake_target=`sed "s|_M_|-|g" <<< "${cmake_target}"`
            target_add_libraries "${src}" "${cmake_target}" targets_libs
        done
    fi
}

## =========================
##  package build functions
## =========================

## freeglut 3.2.1
freeglut() {
    # We made our own GIT repository, from sourforge's freeglut-3.2.1.tar.gz.
    git_clone_pull "freeglut" \
        https://github.com/jrgdre/freeglut.git master \
        e37c881cba87b7caf6b2096bdd0db506bd36d47c
    local cm_params=(\
        "-DFREEGLUT_BUILD_STATIC_LIBS=ON " \
        "-DFREEGLUT_BUILD_SHARED_LIBS=OFF " \
        "-DFREEGLUT_BUILD_DEMOS=OFF " \
    )
    local libs=()
    local c_flags
    # We have to disable the HAVE_XPARSEGEOMETRY test, for it returns wrong
    # results running under Windows<-bash<-MSVC
    sed -i "/CHECK_FUNCTION_EXISTS(*XParseGeometry/ a\
    set(HAVE_XPARSEGEOMETRY OFF)" "${SRC_DIR}/freeglut/CMakeLists.txt"
    cmake_configure "freeglut" "${SRC_DIR}/freeglut" cm_params libs c_flags
    cmake_build "freeglut"
}

## giflib 5.1.2
giflib() {
    git_clone_pull "giflib" \
        https://github.com/xbmc/giflib.git master \
        7e74d92d318ed865e6775b3b05b0cf5c6a39bc20
    local cm_params=()
    local libs=()
    local c_flags=()
    cmake_configure "giflib" "${SRC_DIR}/giflib" cm_params libs c_flags
    cmake_build "giflib"
}

## jbigkit 2.1
jbigkit() {
    git_clone_pull "jbigkit" \
        https://github.com/zdenop/jbigkit.git master \
        d91c6455c5e4d7f63df3fe02165f3ed6d8617920
    local cm_params=()
    local tstcodec=( "libcmt" )
    local tstcodec85=( "libcmt" )
    local pbmtojbg=( "libcmt" )
    local jbgtopbm85=( "libcmt" )
    local jbgtopbm=( "libcmt" )
    local pbmtojbg85=( "libcmt" )
    local libs=( tstcodec tstcodec85 pbmtojbg jbgtopbm85 jbgtopbm pbmtojbg85 )
    local c_flags=()
    cmake_configure "jbigkit" "${SRC_DIR}/jbigkit" cm_params libs c_flags
    cmake_build "jbigkit"
}

## leptonica 1.79.0
# wants:
#   - zlib
#   - png
#   - jpeg
#   - openjpeg
#   - tiff
#   - gif
#   - webp
#   - pkconfig
leptonica() {
    git_clone_pull "leptonica" \
        https://github.com/DanBloomberg/leptonica.git master \
        002843bdf81ef4018fdf0f5c53262bbeab2b0fdc
    # if [ "$CXX_COMPILER_ID" = "MSVC" ]; then
    #     ## patch CMakeLists.txt
    #     # fix: enable MSVC /MT build
    #     mv $SRC_DIR/leptonica/CMakeLists.txt $SRC_DIR/leptonica/CMakeLists.org
    #     sed 's|cmake_minimum_required(VERSION 2.8.11|cmake_minimum_required(VERSION 3.17|' \
    #         $SRC_DIR/leptonica/CMakeLists.org \
    #         > $SRC_DIR/leptonica/CMakeLists.tmp0
    #     echo "cmake_policy( SET CMP0091 NEW )" \
    #         >> $SRC_DIR/leptonica/CMakeLists.txt
    #     echo 'set( CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded" )' \
    #         >> $SRC_DIR/leptonica/CMakeLists.txt
    #     cat $SRC_DIR/leptonica/CMakeLists.tmp0 >> $SRC_DIR/leptonica/CMakeLists.txt
    #     # fix leptonica-1.79.0.lib: lzma and opj functions static decoration
    #     mv $SRC_DIR/leptonica/CMakeLists.txt $SRC_DIR/leptonica/CMakeLists.tmp1
    #     sed "s|add_definitions(-D_CRT_SECURE_NO_WARNINGS)|add_definitions(-D_CRT_SECURE_NO_WARNINGS -DLZMA_API_STATIC -DOPJ_STATIC)|" \
    #         $SRC_DIR/leptonica/CMakeLists.tmp1 > $SRC_DIR/leptonica/CMakeLists.txt
    #     rm -f $SRC_DIR/leptonica/CMakeLists.tmp0
    #     rm -f $SRC_DIR/leptonica/CMakeLists.tmp1
    # fi
    local cm_params=( "-DSW_BUILD=OFF" "-DBUILD_PROG=ON" )
    local libs=()
    local c_flags=()
    sed -i 's/target_link_libraries\s*(\s*${target}/target_link_libraries( ${target} liblzma libjbig openjp2 /' \
        "${SRC_DIR}/leptonica/prog/CMakeLists.txt"
    cmake_configure "leptonica" "${SRC_DIR}/leptonica" cm_params libs c_flags
    sed -i "/#\s*define\s*HAVE_FMEMOPEN/d" \
        "${BUILD_DIR}\leptonica\src\config_auto.h"
    cmake_build "leptonica"
    # if [ "$CXX_COMPILER_ID" = "MSVC" ]; then
    #     # undo changes to repository
    #     rm $SRC_DIR/leptonica/CMakeLists.txt
    #     mv $SRC_DIR/leptonica/CMakeLists.org \
    #     $SRC_DIR/leptonica/CMakeLists.txt
    # fi
}

## libarchive 3.4.2
# wants:
# - zlib
# - lzma
# - zstd
# - DENABLE_WERROR=OFF or compiling with VS2019 currently fails
libarchive() {
    git_clone_pull "libarchive" \
        https://github.com/libarchive/libarchive.git master \
        3288ebb0353beb51dfb09d444dedbe9235ead53d
    local zstd_inc="-DZSTD_INCLUDE_DIR=${INC_INSTALL_DIR}"
    local zstd_lib="-DZSTD_LIBRARY=${LIB_INSTALL_DIR}/zstd_static.lib"
    local cm_params=(\
        "${zstd_inc} " \
        "${zstd_lib} " \
        "-DENABLE_WERROR=OFF " \
    )
    local libs=()
    local c_flags
    cmake_configure "libarchive" "${SRC_DIR}/libarchive" cm_params libs c_flags
    cmake_build "libarchive"
    # fix some things, so CMake 3.17 uses the static lib
    rm -f $LIB_INSTALL_DIR/archive.lib
    rm -f $BIN_INSTALL_DIR/archive.dll
    mv $LIB_INSTALL_DIR/archive_static.lib $LIB_INSTALL_DIR/archive.lib
}

## libjpeg-turbo 2.0.4
libjpeg-turbo() {
    local ref=166e34213e4f4e2363ce058a7bcc69fd03e38b76
    git_clone_pull "libjpeg-turbo" \
        https://github.com/libjpeg-turbo/libjpeg-turbo.git master ${ref}
    local cm_params=(\
        "-DENABLE_SHARED=OFF " \
        "-DENABLE_STATIC=ON " \
        "-DWITH_12BIT=ON " \
    )
    # We have to escape the '-'' character, because this would lead to invalid
    # identifiers.
    # We use '_M_' as the escape sequence. '_M_' will be substituted with '-' by
    # targets_add_libraries().
    local cjpeg_M_static=( "libcmt" )
    local djpeg_M_static=( "libcmt" )
    local jpegtran_M_static=( "libcmt" )
    local md5cmp=( "libcmt" )
    local rdjpgcom=( "libcmt" )
    local wrjpgcom=( "libcmt" )
    local libs=(\
        cjpeg_M_static \
        djpeg_M_static \
        jpegtran_M_static \
        md5cmp \
        rdjpgcom \
        wrjpgcom \
    )
    local c_flags=()
    cmake_configure "libjpeg-turbo" "${SRC_DIR}/libjpeg-turbo" \
        cm_params libs c_flags
    cmake_build "libjpeg-turbo"
}

## libpng 1.6.37
# wants:
#   - zlib
libpng() {
    git_clone_pull "libpng" \
        https://github.com/glennrp/libpng.git master \
        a40189cf881e9f0db80511c382292a5604c3c3d1
        local cm_params=(\
            "-DPNG_SHARED=OFF " \
            "-DPNG_STATIC=ON " \
            "-DPNG_TESTS=OFF " \
        )
        local libs=()
        local c_flags=()
    cmake_configure "libpng" "${SRC_DIR}/libpng" cm_params libs c_flags
    cmake_build "libpng"
}

## libtiff 4.1.0 (round 1: without webp support)
# wants:
#   - zlib
#   - lzma
#   - zstd
#   - jbikit
#   - libjpeg-turbo
#   - openjpeg
#   - webp          (not available yet, see downstream)
#   - glut
#
# jpeg 8/12 bit (MSVC: don't know, how to get this working,
#     "tif_jpeg_12.c(12,12): error C2006: '#include': expected "FILENAME" or <FILENAME>")
#
libtiff() {
    git_clone_pull "libtiff" \
        https://gitlab.com/libtiff/libtiff.git master \
        e0d707dc1524d8c0e20f03396f234e0f1b07b3f4
    if [ "$CXX_COMPILER_ID" = "MSVC" ]; then
        # iptcutil.obj : error LNK2019: unresolved external symbol strncasecmp referenced in function convertHTMLcodes
        # we exclude this contribution from the build
        sed -i 's/^add_subdirectory(iptcutil)/# add_subdirectory(iptcutil)/' \
            $SRC_DIR/libtiff/contrib/CMakeLists.txt
    fi
    local cm_params=(\
        "-DGLUT_ROOT_PATH=$SRC_DIR/freeglut/ " \
        "-DOPENGL_LIBRARY_DIR=$LIB_INSTALL_DIR/ " \
        "-Djpeg12=OFF " \
    )
    local addtiffo=( "libcmt" )
    local ascii_tag=( "libcmt" )
    local custom_dir=( "libcmt" )
    local defer_strile_loading=( "libcmt" )
    local defer_strile_writing=( "libcmt" )
    local fax2ps=( "libcmt" )
    local fax2tiff=( "libcmt" )
    local long_tag=( "libcmt" )
    local pal2rgb=( "libcmt" )
    local ppm2tiff=( "libcmt" )
    local raw_decode=( "libcmt" )
    local raw2tiff=( "libcmt" )
    local rewrite=( "libcmt" )
    local rgb2ycbcr=( "libcmt" )
    local short_tag=( "libcmt" )
    local strip_rw=( "libcmt" )
    local testtypes=( "libcmt" )
    local thumbnail=( "libcmt" )
    local tiff_M_rgb=( "libcmt" )
    local tiff2bw=( "libcmt" )
    local tiff2pdf=( "libcmt" )
    local tiff2ps=( "libcmt" )
    local tiff2rgba=( "libcmt" )
    local tiff_M_bi=( "libcmt" )
    local tiffcmp=( "libcmt" )
    local tiffcp=( "libcmt" )
    local tiffcrop=( "libcmt" )
    local tiffdither=( "libcmt" )
    local tiff_M_grayscale=( "libcmt" )
    local tiffdump=( "libcmt" )
    local tiffinfo=( "libcmt" )
    local tiffmedian=( "libcmt" )
    local tiff_M_palette=( "libcmt" )
    local tiffset=( "libcmt" )
    local tiffsplit=( "libcmt" )
    local libs=(\
        addtiffo \
        ascii_tag \
        custom_dir \
        defer_strile_loading \
        defer_strile_writing \
        fax2ps \
        fax2tiff \
        long_tag \
        pal2rgb \
        ppm2tiff \
        raw_decode
        raw2tiff \
        rewrite \
        rgb2ycbcr \
        short_tag \
        strip_rw \
        testtypes \
        thumbnail \
        tiff_M_rgb \
        tiff2bw \
        tiff2pdf \
        tiff2ps \
        tiff2rgba \
        tiff_M_bi \
        tiffcmp \
        tiffcp \
        tiffcrop \
        tiffdither \
        tiffdump \
        tiff_M_grayscale \
        tiffinfo \
        tiffmedian \
        tiff_M_palette \
        tiffset \
        tiffsplit \
    )
    local c_flags=()
    cmake_configure "libtiff" "${SRC_DIR}/libtiff" cm_params libs c_flags
    cmake_build "libtiff"
}

## libwebp 1.1.0
# wants:
#   - zlib
#   - png
#   - jpeg
#   - tiff
#   - gif
#   - zstd
#   - glut
# We also build the apps, otherwise leptonica can not find a couple of
# dependencies.
libwebp() {
    git_clone_pull "libwebp" \
        https://chromium.googlesource.com/webm/libwebp master \
        340cdc5f649630d535be0a659f5fd33b3aff15e9
    local cm_params=(\
        "-DGLUT_ROOT_PATH=$SRC_DIR/freeglut/ " \
        "-DOPENGL_LIBRARY_DIR=$LIB_INSTALL_DIR/ " \
    )
    local anim_diff=( "libcmt" )
    local anim_dump=( "libcmt" )
    local cwebp=( "libcmt" )
    local dwebp=( "libcmt" )
    local get_disto=( "liblzma libjbig" )
    local gif2webp=( "libcmt" )
    local img2webp=( "liblzma libjbig" )
    local webp_quality=( "libcmt" )
    local webpinfo=( "libcmt" )
    local webpmux=( "libcmt" )
    local libs=(\
        anim_diff \
        anim_dump \
        cwebp \
        dwebp \
        get_disto \
        gif2webp \
        img2webp \
        webp_quality \
        webpinfo \
        webpmux \
    )
    local c_flags=()
    cmake_configure "libwebp" "${SRC_DIR}/libwebp" cm_params libs c_flags
    # We have to disable the HAVE__BUILTIN_BSWAPXX manually, since the test
    # returns wrong results running under Windows<-bash<-MSVC
    sed -i "s/#define HAVE_BUILTIN_BSWAP16 1/#undef HAVE_BUILTIN_BSWAP16/" \
        "${BUILD_DIR}/libwebp/src/webp/config.h"
    sed -i "s/#define HAVE_BUILTIN_BSWAP32 1/#undef HAVE_BUILTIN_BSWAP32/" \
        "${BUILD_DIR}/libwebp/src/webp/config.h"
    sed -i "s/#define HAVE_BUILTIN_BSWAP64 1/#undef HAVE_BUILTIN_BSWAP64/" \
        "${BUILD_DIR}/libwebp/src/webp/config.h"
    cmake_build "libwebp"
}

## opencv 4.2.0
# wants:
#   - python 2 and 3, with numpy
#   - jni
#   - jpeg
#   - libjpeg-turbo
#   - openjpeg
#   - tiff
#   - zlib
#   - vtk
#   - tesseract
#   - blas      (not yet supported by build script)
#   - lapack    (not yet supported by build script)
#   - eigen     (not yet supported by build script)
opencv() {
    git_clone_pull "opencv" \
        https://github.com/opencv/opencv.git master \
        bda89a6469aa79ecd8713967916bd754bff1d931
    local cm_params=(\
        "-DENABLE_CXX11=ON " \
        "-DOPENCV_EXTRA_MODULES_PATH=$SRC_DIR/opencv_contrib/modules " \
        "-DBUILD_PERF_TESTS:BOOL=OFF " \
        "-DBUILD_TESTS:BOOL=OFF " \
        "-DBUILD_DOCS:BOOL=OFF " \
        "-DWITH_CUDA:BOOL=OFF " \
        "-DEXECUTABLE_OUTPUT_PATH=$INSTALL_DIR/bin " \
        "-DPYTHON3_EXECUTABLE=$PYTHON3/python " \
        "-DBUILD_TIFF=OFF " \
    )
    local libs=()
    local c_flags=()
    sed -i '
        /if\s*(\s*TARGET gen_opencv_python_source/ {
            :loop
            /set\s*(\s*deps\s*${OPENCV_MODULE_${the_module}_DEPS}/ !{
                N
                b loop
            }
            /set\s*(\s*deps\s*${OPENCV_MODULE_${the_module}_DEPS}/ {
                s/set\s*(\s*deps\s*${OPENCV_MODULE_${the_module}_DEPS}/set(deps ${OPENCV_MODULE_${the_module}_DEPS} libjbig liblzma/
            }
        }
    ' "${SRC_DIR}/opencv/modules/python/common.cmake"
    sed -i '
        s/ocv_target_link_libraries\s*(\s*${the_target}\s*${APP_MODULES}/ocv_target_link_libraries(${the_target} ${APP_MODULES} libcmt libjbig liblzma/
    ' "${SRC_DIR}/opencv/apps/CMakeLists.txt"
    sed -i '
        s/ocv_target_link_libraries\s*(\s*${the_target}\s*quirc/ocv_target_link_libraries(${the_target} quirc libcmt/
    ' "${SRC_DIR}/opencv/modules/objdetect/CMakeLists.txt"
    sed -i '
        /ocv_target_link_libraries(${the_module} PRIVATE ${OPENCV_LINKER_LIBS} ${OPENCV_HAL_LINKER_LIBS} ${IPP_LIBS} ${ARGN})/ {
            a\
            ocv_target_link_libraries(${the_module} libcmt libjbig liblzma)
        }
    ' "${SRC_DIR}/opencv/cmake/OpenCVModule.cmake"
    cmake_configure "opencv" "${SRC_DIR}/opencv" cm_params libs c_flags
    cmake_build "opencv"
}

## opencv_contrib 4.2.0
opencv_contrib() {
    git_clone_pull "opencv_contrib" \
        https://github.com/opencv/opencv_contrib.git master \
        65abc7090dedc84bbedec4dfd143f0340e52114f
}

## openjpeg 2.3.1 (provides JPEG 2000)
# wants:
#   - zlib
#   - png
#   - tiff
#   - lcms
# We have them build from the thrid-party modules provided, by this package.
openjpeg() {
    git_clone_pull "openjpeg" \
        https://github.com/uclouvain/openjpeg.git master \
        57096325457f96d8cd07bd3af04fe81d7a2ba788
    local cm_params=(\
        "-DBUILD_THIRDPARTY=ON " \
    )
    local libs=()
    # We have to add the libraries "manually", since this package uses
    # a loop for all the programs and not the program names explicitly.
    echo "-- adding libraries to openjpeg's exe targets ( libcmt )"
    sed -i 's|target_link_libraries(${exe} ${OPENJPEG_LIBRARY_NAME}|target_link_libraries(${exe} ${OPENJPEG_LIBRARY_NAME} libcmt|' \
        "${SRC_DIR}/openjpeg/src/bin/jp2/CMakeLists.txt"
    local c_flags=()
    cmake_configure "openjpeg" "${SRC_DIR}/openjpeg" cm_params libs c_flags
    cmake_build "openjpeg"
    # clen-up a couple of DLLs not needed anymore by the statically linked
    # programms
    rm -rf ${BIN_INSTALL_DIR}/msvc*.dll
    rm -rf ${BIN_INSTALL_DIR}/vcruntime*.dll
    rm -rf ${BIN_INSTALL_DIR}/concrt*.dll
}

## tesseract 4.1.1
# wants:
#   - leptonica
#   - archive
tesseract() {
    git_clone_pull "tesseract" \
        https://github.com/tesseract-ocr/tesseract.git master \
        75103040c94ffd7fe5e4e3dfce0a7e67a8420849
    local cm_params=(\
        "-DSTATIC=ON " \
        "-DBUILD_TRAINING_TOOLS=OFF " \
        "-DSW_BUILD=OFF " \
        "-DLeptonica_DIR=$BUILD_DIR/leptonica" \
    )
    local tesseract=( "libjbig liblzma" )
    local libs=( tesseract )
    local c_flags=()
    cmake_configure "tesseract" "${SRC_DIR}/tesseract" cm_params libs c_flags
    cmake_build "tesseract"
    mkdir -p "${BIN_INSTALL_DIR}/tessdata"
    if [ ! -f "${BIN_INSTALL_DIR}/tessdata/eng.traineddata" ]; then
        echo "-- fetching eng.traineddata"
        curl -L https://github.com/tesseract-ocr/tessdata/raw/master/eng.traineddata \
            > "${BIN_INSTALL_DIR}/tessdata/eng.traineddata"
    fi
}

## vtk 8.2.0
vtk() {
    git_clone_pull "vtk" \
        https://gitlab.kitware.com/vtk/vtk.git master \
        e3de2c35c9f44fd6d16ad4c6b6527de7c4f677c7
    local cm_params=(\
        "-DGLUT_ROOT_PATH=$SRC_DIR/freeglut/ " \
        "-DOPENGL_LIBRARY_DIR=$LIB_INSTALL_DIR/ " \
        "-DVTK_RENDERING_BACKEND='OpenGL2'" \
        "-DBUILD_TESTING=OFF " \
    )
    local vtkProbeOpenGLVersion=( "libcmt" )
    local vtkTestOpenGLVersion=( "libcmt" )
    local libs=( vtkProbeOpenGLVersion vtkTestOpenGLVersion )
    local c_flags=()
    # since the target name scheme doesn't work here
    sed -i "s|target_link_libraries\s*(\s*H5make_libsettings|target_link_libraries(H5make_libsettings libcmt|" \
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/src/CMakeLists.txt"
    sed -i "s|target_link_libraries\s*(\s*H5detect|target_link_libraries(H5detect libcmt|" \
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/src/CMakeLists.txt"
    # we have to patch a couple of things
    sed -i "
        /#\s*define\s*RTLD_GLOBAL\s*0/ {
            N
            /#\s*endif/ {
                a \
                #ifndef RTLD_NOW
                a \
                #define RTLD_NOW 0x002
                a \
                #endif
            }
        }
    " "${SRC_DIR}/vtk/ThirdParty/libxml2/vtklibxml2/xmlmodule.c"
    sed -i "/\s*#\s*cmakedefine\s*H5_HAVE_FCNTL/d"\
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/config/cmake/H5pubconf.h.in"
    sed -i "/\s*#\s*cmakedefine\s*H5_HAVE_FLOCK/d"\
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/config/cmake/H5pubconf.h.in"
    sed -i "/\s*#\s*cmakedefine\s*H5_HAVE_GETRUSAGE/d"\
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/config/cmake/H5pubconf.h.in"
    sed -i "/\s*#\s*cmakedefine\s*H5_HAVE_SIGSETJMP/d"\
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/config/cmake/H5pubconf.h.in"
    sed -i "/\s*#\s*cmakedefine\s*H5_HAVE_SIGLONGJMP/d"\
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/config/cmake/H5pubconf.h.in"
    sed -i "/\s*#\s*cmakedefine\s*H5_HAVE_SIGNAL/d"\
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/config/cmake/H5pubconf.h.in"
    sed -i "/\s*#\s*cmakedefine\s*H5_HAVE_SYMLINK/d"\
        "${SRC_DIR}/vtk/ThirdParty/hdf5/vtkhdf5/config/cmake/H5pubconf.h.in"
    cmake_configure "vtk" "${SRC_DIR}/vtk" cm_params libs c_flags
    cmake_build "vtk"
}

## xz (lzma) 5.2.5
xz() {
    git_clone_pull "xz" \
        https://git.tukaani.org/xz.git master \
        b8e12f5ab4c9fd3cb09a4330b2861f6b979ababd
    local cm_params=()
    local libs=()
    local c_flags=()
    # We have to disable the HAVE__BUILTIN_BSWAPXX test, for it returns wrong
    # results running under Windows<-bash<-MSVC
    sed -i "
        /check_c_source_compiles\s*(/ {
            N
    :loop
            /HAVE___BUILTIN_BSWAPXX\s*)/ !{
                N
                b loop
            }
            /HAVE___BUILTIN_BSWAPXX\s*)/ {
                a\
    set(HAVE___BUILTIN_BSWAPXX OFF)
            }
        }
    " "${SRC_DIR}/xz/cmake/tuklib_integer.cmake"
    cmake_configure "xz" "${SRC_DIR}/xz" cm_params libs c_flags
    cmake_build "xz"
}

## zlib 1.2.11
zlib() {
    git_clone_pull "zlib" \
        https://github.com/madler/zlib.git master \
        cacf7f1d4e3d44d871b605da3b647f07d718623f
    local cm_params=()
    local example=( "libcmt" )
    local minigzip=( "libcmt" )
    local libs=( example minigzip )
    local c_flags=()
    cmake_configure "zlib" "${SRC_DIR}/zlib" cm_params libs c_flags
    cmake_build "zlib"
    # remove dynamic link libraries
    # CMake's FindZLIB might otherwise makes the projects downstream prefere
    # dynamic linking
    rm -f ${BIN_INSTALL_DIR}/zlib.dll
    rm -f ${LIB_INSTALL_DIR}/zlib.lib
}

## zstd 1.4.4
zstd() {
    git_clone_pull "zstd" \
        https://github.com/facebook/zstd.git master \
        10f0e6993f9d2f682da6d04aa2385b7d53cbb4ee
    local cm_params=(\
        "-DZSTD_BUILD_SHARED=OFF" \
        "-DZSTD_BUILD_STATIC=ON" \
        "-DZSTD_USE_STATIC_RUNTIME=ON" \
        "-DZSTD_LEGACY_SUPPORT=ON" \
        "-DZSTD_BUILD_PROGRAMS=OFF" \
    )
    local zstd=( "libcmt" )
    local libs=( zstd )
    local c_flags=( )
    cmake_configure "zstd" "${SRC_DIR}/zstd/build/cmake" cm_params libs c_flags
    cmake_build "zstd"
}

## ======
##  main
## ======

SCRIPT_NAME="lept-tess-ocv-build"

init_global_vars

echo " "
echo "running the environment check ..."
echo " "

check_environment

echo " "
echo "done checking the environment"
echo " "

parse_command_line $@

define_common_directories
echo "using source directories in  ${SRC_DIR}"
echo "writing build directories to ${BUILD_DIR}"
echo "installing binaries to       ${BIN_INSTALL_DIR}"
echo "installing includes to       ${INC_INSTALL_DIR}"
echo "installing libraries to      ${LIB_INSTALL_DIR}"

if [  ${INITIAL_BUILD} = true  ]; then
    echo " "
    echo "cleaning up all source repositories, build and install files"
    echo " "
    clean_all
elif [  ${CLEAN_BUILD} = true  ]; then
    echo " "
    echo "cleaning up build and install files"
    echo " "
    clean_build_and_install
fi

# == build packages ==

# zlib
# xz
# zstd
# libarchive <-- ToDo, maybe

# giflib
# libpng
# jbigkit
# libjpeg-turbo
# freeglut
# openjpeg
# libtiff   # without libwebp
# libwebp
# libtiff   # with libwebp
# vtk
# leptonica
# tesseract
# opencv_contrib
opencv

exit 0
