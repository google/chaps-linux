Chaps: A PKCS #11 Implementation For Linux
==========================================

This repository is a framework for building and installing the Chaps
[PKCS #11](http://www.emc.com/emc-plus/rsa-labs/standards-initiatives/pkcs-11-cryptographic-token-interface-standard.htm)
implementation from
[ChromiumOS](http://www.chromium.org/developers/design-documents/chaps-technical-design).

This repo does **not** hold the source code for Chaps; instead, the build files here retrieve the
source code from the ChromiumOS open source project, together with the other required
source code from the Chromium open source project.


Build Instructions
------------------

At the top level of this repository, run `make`.  This will:

 - Create a source tree under `src/`.
 - Download the relevant ChromiumOS and Chromium code under `src/`.
 - Copy additional files needed for the Linux build.
 - Build the code into binaries in `src/out/`, via libraries:
     - `src/libchrome-$(BASE_VER).a`: Chromium utility code
     - `src/libchromeos-$(BASE_VER).a`: ChromiumOS utility code


Repository Layout
-----------------

This small repo contains the following:

 - `README.md`: this file
 - `makefile`: master makefile
 - `extrasrc/`: additional source files needed for the Linux build
 - `patches/`: source code changes needed for the Linux build
 - `debian/`: Debian packaging files


Source Code Layout
------------------

Executing the master `makefile` will retrieve additional source code from various upstream locations, and will place it
under `src/`.

 - `src/base`: Chromium base library code from https://chromium.googlesource.com/chromium/src/base.git
 - `src/platform2`: ChromiumOS core code, including Chaps and utility libraries required by Chaps, from
   https://chromium.googlesource.com/chromiumos/platform2
 - `src/include`: Local include files
