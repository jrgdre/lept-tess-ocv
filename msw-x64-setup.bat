:: MS-Windows script to set-up the environment for an x64 target build.
::
:: Tested with:
:: - MS-Visual Studio 2019 Community
:: - MSYS2 (stand-alone or git for Windows)
::
:: Prerequisites:
:: - MS-Visual Studio installed (Community is fine)
:: - bash.exe in PATH
::
:: Before you can use this script you have to:
:: - point us to the `vcvarsall.bat` of your MS-Visual Studio installation,
::   using the VCVARS_DIR variable
::
:: VCVARS_DIR we suggest you put it in your user's environment settings.
::
@echo off

if %VCVARS_DIR%=="" goto error_VCVARS_DIR

:: see. https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=vs-2019
:: for valid target architectures
set TARGET=x64

call %VCVARS_DIR%\vcvarsall.bat %TARGET%
@echo.
@echo all set, now you can run ./lept-tess-ocv-build.sh
bash

exit 0

error_VCVARS_DIR:
@echo "error: You have to tell us where to find vcvarsall.bat by setting the"
@echo "       VCVARS_DIR environment variable."
exit 1
