# Building OpenCv with Tesseract and Leptonica support

This project aims to:

1.	Build an Open Computer Vision library under MS-Windows, that supports the
	OCRTesseract API.

	Especially I'm interested in building libraries for static linking, so my
	applications can escape the DLL- (or .so) hell.

2.	Have one build script, that performes the following steps:

	-	pull (clone or update) all the dependencies from there Source
		Code Versioning systems (like GitHub);

	-	check out the latest known working stable release of each package;

	-	compile the packages, in order of dependency;

3.	Support different compilers:

	3.1	Microsoft Visual Studio

	3.2	LLVM Clang

	3.3	MSYS2 gcc

	3.4	MinGW gcc

## Prerequisites

- git
- sed
- grep
- cmake
- curl
- a c/c++ compiler
- nasm
- pkg-config

optional:
- python 2
- you need to define the PYTHON3 environment variable, that points to your
  python 3 binary, if you want python3 support

## Usage

###  MS-Windows OS / MSVC:

We provide a simple MSW batch script, that helps to set-up the correct
environment.

For it to work you have to set the `VCVARS_DIR` environment variable to point to
the directory your `vcvarsall.bat` lives in.

Than:

1.	Run `msw-x64-setup.bat`
   	from Windows-Expolorer or from a Command Prompt

	This makes sure all the environment variables are set right.

2.	Run the build script

	`SCRIPT_NAME [options]`

Where:

SCRIPT_NAME:

	lept-tess-ocv-build.sh           # all messages
	lept-tess-ocv-build_piano.sh     # a little less noisy

options:

	-h, --help                        show this brief help"
	-o, --os <operating-system>       override OS the build is for"
	-p, --project <project-name>      give it a name do differentiate projects"
	-g, --generator <CMAKE_GENERATOR> override the default CMAKE_GENERATOR"
	-a, --arch <platform-name>        define an architecture for CMAKE_GENERATOR (if supported by generator)"
	-b, --build <CMAKE_BUILD_TYPE>    override the default CMAKE_BUILD_TYPE (Release)"
	-c, --clean                       remove all intermediate files of a previous build before building"
	-i, --initial                     remove all source and intermediate files and start from scratch"
	-u, --update                      clone- / pull- update all repositories"

__This will take a while!__

On my machine something like 90 minutes for a fresh build, depending on the
mood of my internet connection.
