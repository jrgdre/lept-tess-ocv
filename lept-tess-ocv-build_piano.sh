#!/bin/bash -e

# run the build script with reduced noise

clear && \
    time ./lept-tess-ocv-build.sh ${1} \
        | grep -iw --color=always 'error\|C4013\|warning\|vcxproj\|configuring'
