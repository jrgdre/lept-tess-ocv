# Building OpenCv with Tesseract and Leptonica support

This project aims to:

1.	build an Open Computer Vision library under MS-Windows, that supports the
	OCRTesseract API.

2.	Have one build script, that performes the following steps:

	-	pull (clone or update) all the dependencies from there Source
		Code Versioning systems (like GitHub);

	-	check out the latest known working stable release of each package;

	-	compile the packages, in order of dependency;

	-	create two `lib` directories, one for static linking applications, one
		for dynamic linking applications;

	-	create a `bin` directory with the binaries needed for dynamic linking
		applications and the applications created by the packages

3.	Support different compilers:

	3.1	Microsoft Visual Studio

	3.2	LLVM Clang

	3.3	MSYS2 gcc

	3.4	MinGW gcc

## Prerequisites

-	Git for Windows
-	CMake
-	a working c/c++ compiler environment
-	nasm
-  	pkg-config

## Usage

###  MS-Windows OS / MSVC:

We provide a simple MSW batch script, that helps to set-up the correct
environment.

For it to work you have to set the VCVARS_DIR environment variable to point to
directory your `vcvarsall.bat` lives.

1. open a Windows Command Prompt (cmd or PowerShell)

2. run `msw-x64-setup.bat`

These two steps make sure all the environment variables are set right.

3. run `lept-tess-ocv-build.sh` from where you stored it
