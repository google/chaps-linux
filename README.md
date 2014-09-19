Chaps: A PKCS #11 Implementation For Linux
==========================================

This repository is a framework for building and installing the Chaps
[PKCS #11](http://www.emc.com/emc-plus/rsa-labs/standards-initiatives/pkcs-11-cryptographic-token-interface-standard.htm)
implementation from
[ChromiumOS](http://www.chromium.org/developers/design-documents/chaps-technical-design).

This repo does **not** hold the source code for Chaps; instead, the build files here retrieve the
source code from the ChromiumOS open source project, together with the other required
source code from the Chromium open source project.


Status
------

The Linux build of Chaps is still under development, and should be considered to be alpha status.
Known to-do items include:

 - Simplify the build process (currently a combination of various different build systems)
 - Sort out library versioning for Debian packages:
     - Add SONAME to libchaps.so
     - Separate into distinct packages (chaps, libchaps0, libchaps-dev)
     - Add `ldconfig` steps to `postinst`
 - Make the process of owning/connecting to the TPM less error-prone.


Build Instructions
------------------

First ensure the prerequisites are available.  The master list is given in the `Build-Depends` section of the
`debian/control` file, but specifically includes:

 - The <leveldb/memenv.h> header file, available in the `liblevedb-dev` Debian package.
 - The SCons build tool (typically from the `scons` Debian package).
 - Development headers for GLib 2.0 (`libglib2.0-dev` package).
 - Development headers for the DBus C++ library (`libdbus-c++-dev` package).
 - Development headers for protocol buffers (`libprotobuf-dev` package).
 - Development headers for OpenSSL (`libssl-dev` package).
 - Development headers for PAM modules (`libpam0g-dev` package).
 - Development headers for TSS (`libtspi-dev` package).

At the top level of this repository, run `make`.  This will:

 - Create a source tree under `chaps-<version>/`.
 - Download the relevant ChromiumOS and Chromium code under `chaps-<version>/`.
 - Copy additional files needed for the Linux build.
 - Build the code into binaries in `chaps-<version>/out/`, via libraries:
     - `chaps-<version>/libchrome-$(BASE_VER).a`: Chromium utility code
     - `chaps-<version>/libchromeos-$(BASE_VER).a`: ChromiumOS utility code


Repository Layout
-----------------

This small repo contains the following:

 - `README.md`: this file
 - `makefile`: master makefile
 - `extrasrc/`: additional source files needed for the Linux build
 - `patches/`: source code changes needed for the Linux build
 - `debian/`: Debian packaging files
 - `man/`: vestigial man pages


Source Code Layout
------------------

Executing the master `makefile` will retrieve additional source code from various upstream locations, and will place it
under `chaps-<version>/`.

 - `chaps-<version>/base`: Chromium base library code from https://chromium.googlesource.com/chromium/src/base.git
 - `chaps-<version>/platform2`: ChromiumOS core code, including Chaps and utility libraries required by Chaps, from
   https://chromium.googlesource.com/chromiumos/platform2
 - `chaps-<version>/gmock-<gmock-version>`: GoogleMock and GoogleTest code
 - `chaps-<version>/include`: Local include files
 - `chaps-<version>/debian`: Local Debian packaging files
 - `chaps-<version>/man`: man pages


Packaging
---------

The `package` and `src-package` targets in the top-level makefile build a Debian
binary or source package respectively.


Package Configuration
---------------------

The behavior of the Chaps package is influenced by two configuration values:

 - If the `CHAPS_SYSTEM_TOKEN` variable in `/etc/default/chaps` is set to true, the
   Chaps daemon will load a system-wide token on startup.
 - If the Chaps PAM module is enabled (via `pam-auth-update`) then per-user tokens will be
   created when a user logs in.
