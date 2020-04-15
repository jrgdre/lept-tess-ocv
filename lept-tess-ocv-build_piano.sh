#!/bin/bash -e

## Leptonica, Tesseract, OpenCV build
# run the build script with reduced noise
#
# usage:
#   s. ReadMe.md
#
# (c)2020 Medical Data Solutions GmbH
# License: MIT (s. License.md)
#
# authors:
#   jrgdre  "Joerg Drechsler, Medical Data Solutions GmbH"
#
# versions:
#   1.0.0 2020-03-26 jrgdre "initial release"

clear && \
    time ./lept-tess-ocv-build.sh $@ \
        | grep -iw --color=always \
			'error\|C4013\|warning\|vcxproj\|configuring'
