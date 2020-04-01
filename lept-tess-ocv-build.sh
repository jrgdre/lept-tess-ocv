#!/bin/bash -e

## Leptonica, Tesseract, OpenCV build
# Tries to build all packages and the dependencies from the most recent stable
# release master commits in there git repositories (if exists).
#
# prerequisites:
#   - git
#   - cmake
#   - a c/c++ compiler
#   - nasm
#   - pkg-config
#   - you need to define the PYTHON3 environment variable, that points to your
#     python 3 binary
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
#   1.0.0 2020-03-26 jrgdre "initial release, working MSVC 19 dynamic linking"


## based on:
# - https://docs.opencv.org/master/d3/d52/tutorial_windows_install.html
# - http://www.sk-spell.sk.cx/building-tesseract-and-leptonica-with-cmake-and-clang-on-windows

## ==========
##  settings
## ==========

SCRIPT_NAME="lept-tess-ocv-build"

# default configuration values
PROJECT=""
GENERATOR=""
BUILD_TYPE=Release
CLEAN_BUILD=false
ARCH=""

# find out what we are building on and with
echo "running the environment check ..."
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
echo "done checking the environment"

# parse the command line arguments for the script
while [ ! -z $# ]; do
    case "$1" in
        -h|--help)
            echo "Leptonica, Tesseract, OpenCV build script"
            echo "(c)2020 Medical Data Solutions GmbH, MIT license"
            echo " "
            echo "$SCRIPT_NAME [options]"
            echo " "
            echo "options:"
            echo "-h, --help                        show this brief help"
            echo "-o, --os <operating-system>       override OS the build is for"
            echo "-p, --project <project-name>      give it a name do differentiate projects"
            echo "-g, --generator <CMAKE_GENERATOR> override the default CMAKE_GENERATOR"
            echo "-a, --arch <platform-name>        define an architecture for CMAKE_GENERATOR (if supported by generator)"
            echo "-b, --build <CMAKE_BUILD_TYPE>    override the default CMAKE_BUILD_TYPE (Release)"
            echo "-c, --clean                       remove all intermediate files of a previous build before building"
            exit 0
            ;;
        -a|--arch)
            shift
            if [ ! -z $# ]; then
                ARCH=$1
            else
                echo "no architecture specified, remove switch for default architecture"
            fi
            shift
            ;;
        -b|--build)
            shift
            if [ ! -z $# ]; then
                BUILD_TYPE=$1
            else
                echo "no build-type specified"
            fi
            shift
            ;;
        -c|-clean)
            CLEAN_BUILD=true
            shift
            ;;
        -g|--generator)
            shift
            if [ ! -z $# ]; then
                echo "GENERATOR set to $1"
                GENERATOR=$1
            else
                echo "no generator specified, remove switch for platform default generator"
            fi
            shift
            ;;
        -o|--os)
            shift
            if [ ! -z $# ]; then
                OS=$1
            else
                echo "no operating system specified, remove switch to omit"
            fi
            shift
            ;;
        -p|--project)
            shift
            if [ ! -z $# ]; then
                PROJECT=$1
            else
                echo "no project name specified, remove switch to omit"
            fi
            shift
            ;;
        *)
            break
            ;;
    esac
done

# ## debug print values of defined parameters
# echo $CPU
# echo $OS
# echo $OS_PLATFORM
# echo $OS_RELEASE
# echo $CXX_COMPILER_ID
# echo $CXX_COMPILER_VERSION

## define common directories
REPO_DIR=$(pwd)
SRC_DIR=$REPO_DIR/src
OUT_DIR=$REPO_DIR
if [  ! -z $OS  ]; then
    OUT_DIR=$OUT_DIR/$OS
fi
if [  ! -z $PROJECT  ]; then
    OUT_DIR=$OUT_DIR-$PROJECT
fi
if [  ! -z $CPU  ]; then
    OUT_DIR=$OUT_DIR-$CPU
fi
if [  ! -z $BUILD_TYPE  ]; then
    OUT_DIR=$OUT_DIR-$BUILD_TYPE
fi
BUILD_DIR=$OUT_DIR/build
INSTALL_DIR=$OUT_DIR/install
BIN_INSTALL_DIR=$INSTALL_DIR/bin
INC_INSTALL_DIR=$INSTALL_DIR/include
LIB_INSTALL_DIR=$INSTALL_DIR/lib

## print values of defined directories
# echo $REPO_DIR # debug only
echo "using source directories in  $SRC_DIR"
echo "writing build directories to $BUILD_DIR"
# echo "installing to $INSTALL_DIR" # debug only
echo "installing binaries to       $BIN_INSTALL_DIR"
echo "installing includes to       $INC_INSTALL_DIR"
echo "installing libraries to      $LIB_INSTALL_DIR"

## ===========
##  functions
## ===========

## make pushd shut up
# from https://stackoverflow.com/questions/25288194/dont-display-pushd-popd-stack-across-several-bash-scripts-quiet-pushd-popd
pushd () {
    command pushd "$@" > /dev/null
}

## make popd shut up
# from https://stackoverflow.com/questions/25288194/dont-display-pushd-popd-stack-across-several-bash-scripts-quiet-pushd-popd
popd () {
    command popd "$@" > /dev/null
}

## Build a project that supports CMake
# $1 project name
cmake_build() {
    cd $BUILD_DIR/$1
    cmake --build $BUILD_DIR/$1 \
        --config $BUILD_TYPE \
        --target install
    cd $REPO_DIR
}

## Configure a project that supports CMake
# $1 project name
cmake_configure() {
    local project=$1
    mkdir -p $BUILD_DIR/$project
    local PREFIX_PATHS="$SRC_DIR/$project;$BUILD_DIR/$project;$INSTALL_DIR;$LIB_INSTALL_DIR"
    echo "-- CMAKE_PREFIX_PATH=$PREFIX_PATHS"
    local MODULE_PATHS="$REPO_DIR/cmake;$INSTALL_DIR/cmake" # run custom cmakes first
    echo "-- CMAKE_MODULE_PATHS=$MODULE_PATHS"
    pushd $BUILD_DIR/$project
    if [  ! -z $GENERATOR  ]; then
        cmake $SRC_DIR/$project \
            -G "$GENERATOR" \
            -DCMAKE_MODULE_PATH=$MODULE_PATHS \
            -DCMAKE_PREFIX_PATH=$PREFIX_PATHS \
            -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
            -Wno-derecated \
            $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14} ${15} ${16} \
            ${17} ${18} ${19} ${20} ${21} ${22} ${23} ${24} ${25} ${26} ${27}
            # -DCMAKE_MODULE_LINKER_FLAGS=-whole-archive \
    else
        cmake $SRC_DIR/$project \
            -DCMAKE_MODULE_PATH=$MODULE_PATHS \
            -DCMAKE_PREFIX_PATH=$PREFIX_PATHS \
            -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
            -Wno-derecated \
            $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14} ${15} ${16} \
            ${17} ${18} ${19} ${20} ${21} ${22} ${23} ${24} ${25} ${26} ${27}
            # -DCMAKE_MODULE_LINKER_FLAGS=-whole-archive \
    fi
    popd
}

## Switches to a given branch
# If the branch does not yet exist, create it based on the ref given.
# $1 project name
# $2 branch to switch to
# $3 ref to base the branch on (e.g. tag or commit), optional, create only
git_branch() {
    local project=$1
    local branch=$2
    local ref=$3
    # define default values
    if [  -z $ref  ]; then
        ref=$branch
    fi
    # branch
    pushd $SRC_DIR/$project
    set -e; # don't exit script, if the branch can't be found by `git show-ref`
        `git show-ref --quiet --verify "refs/heads/$branch"` && true
    if [  $? == 1  ]; then              # branch dosn't exist yet
        git switch -c $branch $ref      # create and switch
    else
        git switch $branch
    fi
    popd
}

## Clone or pull a repository
# $1 project name
# $2 remote reporsitory to pull
# $3 branch to pull (optional)
# $4 ref to checkout (optional)
# $5 branch to create and switch to (optional)
git_clone_pull() {
    local project=$1
    local repo=$2
    local pull_branch=$3
    local ref=$4
    local target=$5
    # define default values
    if [  -z $pull_branch  ]; then
        pull_branch='master'
    fi
    if [  ! -z $ref  ]; then
        if [  -z $target  ]; then
            target=$ref
        fi
    fi
    # clone / pull
    if [  ! -d "$SRC_DIR/$project"  ]; then
        mkdir -p $BUILD_DIR/$project
        pushd $SRC_DIR
        git clone $repo
    else
        echo "pulling $project"
        pushd $SRC_DIR/$project
        if [  ! -z $pull_branch  ]; then
            git switch "$pull_branch"
        fi
        git pull
    fi
    popd
    # branch for tag
    if [  ! -z $ref  ]; then
        git_branch $project $target $ref
    fi
}

# # Set the lib dir for static or dynamic linking of dependencies
# # This does not influence if the target is build as a static or dynamic link
# # library, only if the target itself links it's own dependencies statically or
# # as dynamic link libaries.
# # $1 link type override ("static"|"dynamic"), static linking if omitted
# link_dependencies() {
#     local link_type=static # default link type
#     if [  ! -z $1  ]; then
#         link_type=$1 # function parameter override
#     fi
#     rm -rf $LIB_DIR_TMP
#     echo "linking agains $LIB_DIR_OUT-$link_type"
#     ln -s $LIB_DIR_OUT-$link_type $LIB_DIR_TMP
# }

## ============================
##  setup build directory tree
## ============================

## clean-up old build and install files
if [  $CLEAN_BUILD = true  ]; then
    echo "cleaning up old files"
    if [ $OUT_DIR != $REPO_DIR ]; then
        rm -rf $OUT_DIR
    else
        rm -rf $BUILD_DIR
        rm -rf $INSTALL_DIR
    fi
fi

## create common directories
if [  ! -d "$REPO_DIR/src"  ]; then
	mkdir -p "src"
fi
if [  ! -d "$BUILD_DIR"  ]; then
	mkdir -p "$BUILD_DIR"
fi
if [  ! -d "$INSTALL_DIR"  ]; then
	mkdir -p "$INSTALL_DIR"
fi
if [  ! -d "$BIN_INSTALL_DIR"  ]; then
    mkdir -p "$BIN_INSTALL_DIR"
fi
if [  ! -d "$INC_INSTALL_DIR"  ]; then
    mkdir -p "$INC_INSTALL_DIR"
fi
if [  ! -d "$LIB_INSTALL_DIR"  ]; then
    mkdir -p "$LIB_INSTALL_DIR"
fi

## =====================
##  build prerequisites
## =====================


## freeglut
# no GIT repository, fetching a tar
if [  ! -d $SRC_DIR/freeglut  ]; then
    cd $SRC_DIR
    wget -c --show-progress \
        http://downloads.sourceforge.net/project/freeglut/freeglut/3.2.1/freeglut-3.2.1.tar.gz
    tar -xzf freeglut-3.2.1.tar.gz
    mv freeglut-3.2.1 freeglut
fi
# build static link libraries
link_dependencies static
cmake_configure freeglut \
    -DFREEGLUT_BUILD_SHARED_LIBS=OFF \
    -DFREEGLUT_BUILD_STATIC_LIBS=ON \
    -DFREEGLUT_REPLACE_GLUT=OFF \
    -DFREEGLUT_BUILD_DEMOS=OFF
cmake_build freeglut
mv -f $LIB_DIR_TMP/freeglut_static.lib $LIB_DIR_OUT-static/freeglut.lib
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
# We also need to run the GLUT replacement version, since downstream some
# packages expect glut.h
cmake_configure freeglut \
    -DFREEGLUT_BUILD_SHARED_LIBS=OFF \
    -DFREEGLUT_BUILD_STATIC_LIBS=ON \
    -DFREEGLUT_REPLACE_GLUT=ON \
    -DFREEGLUT_BUILD_DEMOS=OFF
cmake_build freeglut
# We have to discard the glut.lib crated in this step, or CMake's FindGLUT.cmake
# gets confused.
# rm -rf $LIB_DIR_TMP
rm -f $INSTALL_DIR/bin/glut.dll # we doon't need this one
# build dynamic link libraries
link_dependencies dynamic
cmake_configure freeglut \
    -DFREEGLUT_BUILD_SHARED_LIBS=ON \
    -DFREEGLUT_BUILD_STATIC_LIBS=OFF \
    -DFREEGLUT_REPLACE_GLUT=OFF \
    -DFREEGLUT_BUILD_DEMOS=OFF
cmake_build freeglut
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
rm -rf $LIB_DIR_TMP

## zlib
git_clone_pull zlib \
    https://github.com/madler/zlib.git origin/master
link_dependencies static
cmake_configure zlib \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
cmake_build zlib
cp $LIB_DIR_TMP/zlib.lib $LIB_DIR_OUT-dynamic/zlib.lib
cp $LIB_DIR_TMP/zlibstatic.lib $LIB_DIR_OUT-static/zlib.lib
rm -rf $LIB_DIR_TMP

## libpng
git_clone_pull libpng \
    https://github.com/glennrp/libpng.git origin/master
link_dependencies static
cmake_configure libpng \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DPNG_TESTS=OFF
cmake_build libpng
cp $LIB_DIR_TMP/libpng16.lib $LIB_DIR_OUT-dynamic/libpng16.lib
cp $LIB_DIR_TMP/libpng16_static.lib $LIB_DIR_OUT-static/libpng16.lib
cp -rf $LIB_DIR_TMP/libpng $LIB_DIR_OUT-dynamic/
cp -rf $LIB_DIR_TMP/libpng $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP

## giflib
# This package doesn't provide dynamic linking.
# We copy the static link library to the -dynamic directory for convenience.
# The build creates two directories in $LIB_DIR_TMP/cmake:
# - `giflib`
# - `<version number>`
# The last one sucks, it has nothing that says: "This belongs to giflib" and it
# can change.
git_clone_pull giflib \
    https://github.com/xbmc/giflib.git origin/master
link_dependencies static
cmake_configure giflib \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
rm -rf $LIB_DIR_TMP/cmake # avoid polluting target dirs with wrong versions
cmake_build giflib
cp $LIB_DIR_TMP/giflib.lib $LIB_DIR_OUT-dynamic/giflib.lib
cp $LIB_DIR_TMP/giflib.lib $LIB_DIR_OUT-static/giflib.lib
cp -rf $LIB_DIR_TMP/cmake $LIB_DIR_OUT-dynamic/
cp -rf $LIB_DIR_TMP/cmake $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP

## libjpeg-turbo
git_clone_pull libjpeg-turbo \
    https://github.com/libjpeg-turbo/libjpeg-turbo.git origin/master
link_dependencies static
cmake_configure libjpeg-turbo \
    -DWITH_12BIT=ON
cmake_build libjpeg-turbo
cp $LIB_DIR_TMP/jpeg.lib $LIB_DIR_OUT-dynamic/jpeg.lib
cp $LIB_DIR_TMP/jpeg-static.lib $LIB_DIR_OUT-static/jpeg.lib
mkdir -p $LIB_DIR_OUT-dynamic/pkgconfig/
cp -rf $LIB_DIR_TMP/pkgconfig/libjpeg.pc $LIB_DIR_OUT-dynamic/pkgconfig/
cp -rf $LIB_DIR_TMP/pkgconfig/libturbojpeg.pc $LIB_DIR_OUT-dynamic/pkgconfig/
mkdir -p $LIB_DIR_OUT-static/pkgconfig/
cp -rf $LIB_DIR_TMP/pkgconfig/libjpeg.pc $LIB_DIR_OUT-static/pkgconfig/
cp -rf $LIB_DIR_TMP/pkgconfig/libturbojpeg.pc $LIB_DIR_OUT-static/pkgconfig/
rm -rf $LIB_DIR_TMP

# openjpeg
this one acknowledges BUILD_SHARED_LIBS
we want static and dynamic libs, so we run cmake twice
git_clone_pull openjpeg \
    https://github.com/uclouvain/openjpeg.git origin/master
link_dependencies static
cmake_configure openjpeg -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DBUILD_THIRDPARTY=ON
cmake_build openjpeg
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP
link_dependencies dynamic
cmake_configure openjpeg -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DBUILD_THIRDPARTY=ON
cmake_build openjpeg
cp $LIB_DIR_TMP/openjp2.lib $LIB_DIR_OUT-dynamic/openjp2.lib
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
rm -rf $LIB_DIR_TMP

# jbigkit
Under MSCV the libraries build seem to be the same, wether we select
BUILD_SHARED_LIBS or not.
Makes you wonder, if the dynamic linking really is a dynamic linking.
Right now we roll with it.
git_clone_pull jbigkit \
    https://github.com/zdenop/jbigkit.git origin/master
We always need to run both configurations or the dynamic library build fails
with linker errors.
link_dependencies static
cmake_configure jbigkit -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
cmake_build jbigkit
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP
link_dependencies dynamic
cmake_configure jbigkit -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
cmake_build jbigkit
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
rm -rf $LIB_DIR_TMP

## lzma (xz)
# This package currently has the problem of not providing a lib file under
# MSVC, if you only build the shared lib.
# The way it is currently build, the lib file in -static is the same as the
# lib file in -dynamic.
# That probably will cause problems later in one of the two build branches.
# Right now we don't have a solution for this.
git_clone_pull xz \
    https://git.tukaani.org/xz.git origin/master
# this one acknowledges BUILD_SHARED_LIBS
# we want static and dynamic libs, so we run cmake twice
link_dependencies static
cmake_configure xz -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
cmake_build xz
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP
cmake_configure xz -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
cmake_build xz
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
rm -rf $LIB_DIR_TMP

## zstd
git_clone_pull zstd \
    https://github.com/facebook/zstd.git origin/master
# This repository has a different layout.
# So we need a custom configure handler here.
mkdir -p $BUILD_DIR/zstd
cd $BUILD_DIR/zstd
link_dependencies static
if [ ! z $CMAKE_GENERATOR ]; then
    cmake $SRC_DIR/zstd/build/cmake \
        -G "$CMAKE_GENERATOR" \
        -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
        -DCMAKE_PREFIX_PATH=$INSTALL_DIR \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
        -DZSTD_BUILD_SHARED=OFF \
        -DZSTD_BUILD_STATIC=ON \
        -DZSTD_LEGACY_SUPPORT=ON \
        -DZSTD_ZLIB_SUPPORT=ON \
        -DZSTD_BUILD_PROGRAMS=ON
else
    cmake $SRC_DIR/zstd/build/cmake \
        -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
        -DCMAKE_PREFIX_PATH=$INSTALL_DIR \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
        -DZSTD_BUILD_SHARED=OFF \
        -DZSTD_BUILD_STATIC=ON \
        -DZSTD_LEGACY_SUPPORT=ON \
        -DZSTD_ZLIB_SUPPORT=ON \
        -DZSTD_BUILD_PROGRAMS=ON
fi
cd $REPO_DIR
cmake_build zstd
cp $LIB_DIR_TMP/zstd_static.lib $LIB_DIR_OUT-static/zstd.lib
rm -rf $LIB_DIR_TMP
cd $BUILD_DIR/zstd
link_dependencies dynamic
if [ ! z $CMAKE_GENERATOR ]; then
    cmake $SRC_DIR/zstd/build/cmake \
        -G "$CMAKE_GENERATOR" \
        -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
        -DCMAKE_PREFIX_PATH=$INSTALL_DIR \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
        -DZSTD_BUILD_SHARED=ON \
        -DZSTD_BUILD_STATIC=OFF \
        -DZSTD_LEGACY_SUPPORT=ON \
        -DZSTD_BUILD_PROGRAMS=OFF
else
    cmake $SRC_DIR/zstd/build/cmake \
        -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
        -DCMAKE_PREFIX_PATH=$INSTALL_DIR \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
        -DZSTD_BUILD_SHARED=ON \
        -DZSTD_BUILD_STATIC=OFF \
        -DZSTD_LEGACY_SUPPORT=ON \
        -DZSTD_BUILD_PROGRAMS=OFF
fi
cd $REPO_DIR
cmake_build zstd
cp $LIB_DIR_TMP/zstd.lib $LIB_DIR_OUT-dynamic/zstd.lib
rm -rf $LIB_DIR_TMP

## libwebp (step 1, without tiff support (libtiff uses libwebp))
# Again with MSVC static and dynamic link libraries are the same and the *.dll
# is extremely small. Makes you wonder, if dynamic linking is really supported.
# Also we always first need to build the static libs, with one of GIF2WEB or
# IMG2WEB =ON, or some dependencies are missing in the dynamic build.
git_clone_pull libwebp \
    https://chromium.googlesource.com/webm/libwebp origin/master
link_dependencies static
cmake_configure libwebp -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DWEBP_BUILD_ANIM_UTILS=OFF \
    -DWEBP_BUILD_CWEBP=OFF \
    -DWEBP_BUILD_DWEBP=OFF \
    -DWEBP_BUILD_EXTRAS=OFF \
    -DWEBP_BUILD_GIF2WEBP=ON \
    -DWEBP_BUILD_IMG2WEBP=OFF \
    -DWEBP_BUILD_VWEBP=OFF \
    -DWEBP_BUILD_WEBPINFO=OFF
cmake_build libwebp
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP
link_dependencies dynamic
cmake_configure libwebp -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DWEBP_BUILD_ANIM_UTILS=ON \
    -DWEBP_BUILD_CWEBP=ON \
    -DWEBP_BUILD_DWEBP=ON \
    -DWEBP_BUILD_EXTRAS=ON \
    -DWEBP_BUILD_GIF2WEBP=ON \
    -DWEBP_BUILD_IMG2WEBP=ON \
    -DWEBP_BUILD_VWEBP=ON \
    -DWEBP_BUILD_WEBPINFO=ON
cmake_build libwebp
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
rm -rf $LIB_DIR_TMP

## libtiff
# this one acknowledges BUILD_SHARED_LIBS
# we want static and dynamic libs, so we run cmake twice
git_clone_pull libtiff \
    https://gitlab.com/libtiff/libtiff.git origin/master
link_dependencies static
cmake_configure libtiff -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -Dlzma=OFF # MSVC linking agains lzma.lib is broken
cmake_build libtiff
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP
link_dependencies dynamic
cmake_configure libtiff -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -Dlzma=OFF # linking agains lzma.lib is broken
cmake_build libtiff
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
rm -rf $LIB_DIR_TMP

## glfw (opengl)
git_clone_pull glfw \
    https://github.com/glfw/glfw.git origin/master
link_dependencies dynamic
cmake_configure glfw -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DGLFW_BUILD_EXAMPLES=OFF \
    -DGLFW_BUILD_TESTS=OFF \
    -DGLFW_BUILD_DOCS=OFF
cmake_build glfw

## vtk
git_clone_pull vtk \
    https://gitlab.kitware.com/vtk/vtk.git
git checkout -b v8.2.0 8.2.0
link_dependencies static
cmake_configure vtk -DBUILD_SHARED_LIBS=OFF \
    -DVTK_BUILD_TESTING=OFF
cmake_build vtk
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
rm -rf $LIB_DIR_TMP
link_dependencies dynamic
cmake_configure vtk -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF
cmake_build vtk
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
rm -rf $LIB_DIR_TMP

# libarchive
linking dependencies statically is the whole point
git_clone_pull libarchive \
    https://github.com/libarchive/libarchive.git
link_dependencies static # static linking of dependencies
cmake_configure libarchive \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DENABLE_WERROR=OFF # or compiling with VS2019 currently fails
cmake_build libarchive
cp $LIB_DIR_TMP/archive.lib $LIB_DIR_OUT-dynamic/archive.lib
cp $LIB_DIR_TMP/archive_static.lib $LIB_DIR_OUT-static/archive.lib
cp $LIB_DIR_TMP/pkgconfig/libarchive.pc $LIB_DIR_OUT-dynamic/pkgconfig/
cp $LIB_DIR_TMP/pkgconfig/libarchive.pc $LIB_DIR_OUT-static/pkgconfig/
rm -rf $LIB_DIR_TMP

# --> ToDo: check if needed <--

## libwebp (step 2, rebuild with tiff support)
# --> broken MSCV linker errors agains tiff.lib <--
# rm -rf $BUILD_DIR/libwebp
# link_dependencies static
# cmake_configure libwebp -DBUILD_SHARED_LIBS=OFF \
#    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
# cmake_build libwebp
# cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
# rm -rf $LIB_DIR_TMP
# cmake_configure libwebp -DBUILD_SHARED_LIBS=ON \
#    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT"
# cmake_build libwebp
# cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
# rm -rf $LIB_DIR_TMP

# ## little-CMS-cmake
# # doesn't support the generation of a static link library
# git_clone_pull little-CMS-cmake \
#     https://github.com/mindw/little-CMS-cmake.git origin/xy
# link_dependencies dynamic
# cmake_configure little-CMS-cmake -DBUILD_TESTS=OFF
# cmake_build little-CMS-cmake
# cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
# rm -rf $LIB_DIR_TMP

## ====================================
##  build leptonica, tesseract, opencv
## ====================================

## leptonica
git_clone_pull leptonica \
    https://github.com/DanBloomberg/leptonica.git origin/master
link_dependencies static
cmake_configure leptonica -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DSW_BUILD=OFF \
    -DCMAKE_MODULE_LINKER_FLAGS=-whole-archive
cmake_build leptonica
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-static/
mkdir -p $LIB_DIR_OUT-static/cmake/leptonica
mv $INSTALL_DIR/cmake/* $LIB_DIR_OUT-static/cmake/leptonica/
rm -rf $INSTALL_DIR/cmake
rm -rf $LIB_DIR_TMP
link_dependencies dynamic
cmake_configure leptonica -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="/NODEFAULTLIB:LIBCMT" \
    -DSW_BUILD=OFF \
    -DCMAKE_MODULE_LINKER_FLAGS=-whole-archive
cmake_build leptonica
cp -rf $LIB_DIR_TMP/* $LIB_DIR_OUT-dynamic/
mkdir -p $LIB_DIR_OUT-dynamic/cmake/leptonica
mv $INSTALL_DIR/cmake/* $LIB_DIR_OUT-dynamic/cmake/leptonica/
rm -rf $INSTALL_DIR/cmake
rm -rf $LIB_DIR_TMP

## tesseract
# apperently doesn't support a static link library build
git_clone_pull tesseract \
    https://github.com/tesseract-ocr/tesseract.git origin/master
link_dependencies dynamic
cmake_configure tesseract -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TRAINING_TOOLS=OFF \
    -DSW_BUILD=OFF \
    -DLeptonica_DIR=$BUILD_DIR/leptonica \
    -DCMAKE_MODULE_LINKER_FLAGS=-whole-archive
cp $LIB_DIR_TMP/tiff.lib $BUILD_DIR/tesseract/ # workaround comfig error
cmake_build tesseract
cp $LIB_DIR_TMP/tesseract* $LIB_DIR_OUT-dynamic/
mkdir -p $LIB_DIR_OUT-dynamic/pkgconfig/
cp $LIB_DIR_TMP/pkgconfig/tesseract* $LIB_DIR_OUT-dynamic/pkgconfig/
mkdir -p $LIB_DIR_OUT-dynamic/cmake/tesseract
cp $INSTALL_DIR/cmake/* $LIB_DIR_OUT-dynamic/cmake/tesseract/
rm -rf $INSTALL_DIR/cmake
rm -rf $LIB_DIR_TMP

# ## static build of tesseract
# --> MSVC static build of tesseract has linker errors <--
# We omit a static build of tesseract for now.

## opencv_contrib
git_clone_pull opencv_contrib \
    https://github.com/opencv/opencv_contrib.git origin/master

# opencv
git_clone_pull opencv \
    https://github.com/opencv/opencv.git origin/master
link_dependencies dynamic
# as of commit bf0075a5 of opencv_contrib leptonica and tesseract detection
# for MS-Windowss VC is broken in opencv's text module
# - we find the libraries ourself
#   LIB_LEPT=`ls $LIB_DIR_TMP/leptonica*`
#   LIB_TESS=`ls $LIB_DIR_TMP/tesseract*`
# - disable the tesseract detection
#   -DTesseract_FOUND=ON \
# - set the variables
#   -DLept_LIBRARY=$LIB_LEPT \
#   -DTesseract_INCLUDE_DIR=$INSTALL_DIR/include/tesseract \
#   -DTesseract_LIBRARY=$LIB_TESS \
#   -DTesseract_INCLUDE_DIRS="$INSTALL_DIR/include/tesseract;$INSTALL_DIR/include/leptonica" \
#   -DTesseract_LIBRARYS="$LIB_TESS;$LiB_LEPT" \
LIB_LEPT=`ls $LIB_DIR_TMP/leptonica*`
LIB_TESS=`ls $LIB_DIR_TMP/tesseract*`
# posix -> windows
LIB_LEPT=$(sed 's|^/\([a-z,A-Z]\)/|\1:/|' <<< $LIB_LEPT)
LIB_TESS=$(sed 's|^/\([a-z,A-Z]\)/|\1:/|' <<< $LIB_TESS)
cmake_configure opencv -DBUILD_SHARED_LIBS=ON \
    -DENABLE_CXX11=ON \
    -DTesseract_FOUND=ON \
    -DLept_LIBRARY=$LIB_LEPT \
    -DTesseract_INCLUDE_DIR=$INSTALL_DIR/include \
    -DTesseract_LIBRARY=$LIB_TESS \
    -DTesseract_INCLUDE_DIRS=$INSTALL_DIR/include \
    -DTesseract_LIBRARIES=$LIB_TESS\;$LIB_LEPT \
    -DPYTHON3_EXECUTABLE=$PYTHON3/python \
    -DOPENCV_EXTRA_MODULES_PATH=$SRC_DIR/opencv_contrib/modules \
    -DBUILD_PERF_TESTS:BOOL=OFF \
    -DBUILD_TESTS:BOOL=OFF \
    -DBUILD_DOCS:BOOL=OFF \
    -DWITH_CUDA:BOOL=OFF \
    -DEXECUTABLE_OUTPUT_PATH=$INSTALL_DIR/bin
cmake_build opencv

mkdir -p $LIB_DIR_OUT-dynamic/cmake/opencv
mv $INSTALL_DIR/OpenCV* $LIB_DIR_OUT-dynamic/cmake/opencv/
mv $INSTALL_DIR/setup_vars_opencv* $INSTALL_DIR/bin/
mkdir -p $LIB_DIR_OUT-dynamic/LICENSES
mv $INSTALL_DIR/LICENSE $LIB_DIR_OUT-dynamic/LICENSES/opencv.txt

## ToDo: find a way to set or detect the opencv build output directory
OCV_INSTALL_DIR=`ls $INSTALL_DIR/x64`
cp -rf $INSTALL_DIR/x64/$OCV_INSTALL_DIR/bin/* $INSTALL_DIR/bin/
cp -rf $INSTALL_DIR/x64/$OCV_INSTALL_DIR/lib/* $LIB_DIR_OUT-dynamic/
mv $LIB_DIR_OUT-dynamic/*.cmake $LIB_DIR_OUT-dynamic/cmake/opencv/
rm -rf $LIB_DIR_TMP
rm -rf $INSTALL_DIR/x64

# ## static build of opencv
# There are a lot of questionable or broken static library builds upstream.
# So we omit a static build of opencv for now.
