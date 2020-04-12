#!/bin/bash -e

# run the build script with reduced noise

clear && \
    time ./lept-tess-ocv-build.sh ${1} \
        | grep --color=always 'error\|c4013\|warning\|vcxproj\|configuring'
