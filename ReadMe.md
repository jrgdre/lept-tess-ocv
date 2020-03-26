# Building OpenCv with Tesseract and Leptonica support

This project aims to:

1.	build an Open Computer Vision library under MS-Windows, that supports the
	OCRTesseract API.

2.	Have one build script, that:

	-	first pulls (clone or update) all the dependencies from there Source
		Code Versioning systems (like GitHub);

	-	compiles the different packages;

	-	create a `lib` directory for static linking applications;

	-	create a `install` directory with the binaries needed for dynamic
		linking applications

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
