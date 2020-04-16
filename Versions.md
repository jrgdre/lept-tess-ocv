# Released Versions

authors:

- jrgdre  "Joerg Drechsler, Medical Data Solutions GmbH"

## 2.1.0 2020-04-16

-   fix: switch jpeg from 12bit to 8bit format
-   remove: libtwebp other picture format support/dependecies
-   remove: libtiff other picture format support/dependecies
-   new: opencv_world

## 2.0.0 2020-04-15

This version is a complete overhaul of the 1.0.0. release.

-   remove: MSVC 19 dynamic linking (jrgdre)
-   new: for each package use a specific git commit, known to work (jrgdre)
-   new: freeglut (jrgdre)
-   new: vtk (jrgdre)
-   new: opencv support for viz (jrgdre)
-   new: opencv support for python2 (jrgdre)
-   new: opencv support for python3 (jrgdre)
-   new: meta build script lept-tess-opencv_piano.sh, if you like it less noisy
-   improved: script code quality (all function based)
-   remove: libarchive, lib won't build as static lib (jrgdre)

Also, we introduced functions for pretty much all tasks, to clean up the code
and improve overall code quality.

## 1.0.0 2020-03-26

-   initial release (jrgdre)
-   new: working MSVC 19 dynamic linking (jrgdre)
