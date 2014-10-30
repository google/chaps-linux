Chaps: A PKCS #11 Implementation For Linux
==========================================

This repository is a framework for building and packaging the Chaps
[PKCS #11](http://www.emc.com/emc-plus/rsa-labs/standards-initiatives/pkcs-11-cryptographic-token-interface-standard.htm)
implementation from
[ChromiumOS](http://www.chromium.org/developers/design-documents/chaps-technical-design) on Linux.

This repo does **not** hold the source code for Chaps; instead, the build files here retrieve the
source code from the ChromiumOS open source project, together with the other required
source code from the Chromium open source project.

The Linux build of Chaps is still under development, and should be considered to be **alpha status**.

This is NOT an official Google product.


Installing Chaps
----------------

To install Chaps on a Debian based system:

 - Install the prerequisites: `sudo apt-get install debhelper scons protobuf-compiler libdbus-1-dev libdbus-c++-dev
   libprotobuf-dev libsnappy-dev libleveldb-dev libglib2.0-dev libctemplate-dev libssl-dev libtspi-dev libpam0g-dev`
 - Ensure that the TPM is initialized and accessible.
 - Build the packages: `make package`
 - Install the packages: `sudo dpkg -i chaps_*_amd64.deb libchaps0_*_amd64.deb`
 - Log out and in again, so that Chaps can create a per-user token.


About TPMs and PKCS#11
----------------------

[PKCS #11](http://www.emc.com/emc-plus/rsa-labs/standards-initiatives/pkcs-11-cryptographic-token-interface-standard.htm)
is a standard C API for accessing cryptographic hardware.  The API allows encryption/decryption with both symmetric and
asymmetric keys, together with signature generation/verification and random number generation.

The majority of these cryptographic operations are performed in software (using the OpenSSL libraries); however, the
presence of a *trusted platform module* (TPM) on the system allows for a few key operations to be performed in hardware:

 - Random number generation.
 - Generation of RSA public/private keypairs.
 - Wrapping/unwrapping of other keys (i.e. encrypting/decrypting them).

This enables a key use case for PKCS#11: storing cryptographic material so that it can only be used on the local
machine.  A key can be stored in encrypted form, where decrypting the key (eventually) requires the use of a private
key that is held in the TPM, and which cannot be extracted from the TPM.  This means that an attacker with that gets
full access to the local machine's disk still can't access the key.  (If a TPM is not available, this protection is
obviously not available, but Chaps will continue to work.)


Slots and Users
---------------

In the PKCS#11 API, an item of cryptographic hardware is known as a *token*, and tokens are accessed via a particular
*slot*.

````
% pkcs11-tool --module /usr/lib/libchaps.so.0 --list-slots
Available slots:
Slot 0 (0x0): TPM Slot
  token label        : System TPM Token
  token manufacturer : Chromium OS
  token model        :
  token flags        : rng, PIN initialized, PIN pad present, token initialized
  hardware version   : 1.0
  firmware version   : 1.0
  serial num         : Not Available
````

The PKCS#11 API also includes authentication to allow token contents to be secured; the API user needs to log-in to
access *private* objects on the token.  However, there is only a single user PIN/password for the whole API; the PKCS#11
API has no mechanism to allow different users to store cryptographic material and be isolated from each other.

(The API does include another role with a distinct PIN/password, the *security officer*, but this role is intended for
administrative operations -- such as resetting the token or the user's PIN -- rather than cryptographic operations.)

Therefore, to allow multi-user use, Chaps does not make use of the PKCS#11 login mechanism (`C_Login`).  Instead, Chaps
creates a token (held under `/var/lib/chaps/tokens/<user>/`)for each user when it first sees that user log in to the
system, together with a blob of authentication data that is only visible to that user (in
`/var/lib/chaps/isolates/<user>`).  When that user subsequently makes PKCS#11 API calls, only their own slot/token
contents are visible to them.

(To ease compatibility with other PKCS#11 implementations, Chaps will accept a `C_Login` operation with a PIN of
'111111', although this is a no-op;  Chaps does not allow `C_Login` for the security office role.)

Also, the contents of the per-user token are encrypted using a hash of the user's password, which means that the user's
token is only available when they are properly logged in (i.e. `su <user>` as `root` does not give access).  However,
this does impose a requirement for the user to re-login after installation (and after anything that restarts the Chaps
system daemon).


Troubleshooting
---------------

Chaps emits log messages to the system log (e.g. `/var/log/syslog`); the verbosity of these logs can be altered
with `chaps_client --set_log_level=<level>`.



Detailed Build Instructions
---------------------------

First ensure the prerequisites are available.  The master list is given in the `Build-Depends` section of the
`debian/control` file, but specifically includes:

 - The `<leveldb/memenv.h>` header file, available in the `liblevedb-dev` Debian package.
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

To build Debian packages, run `make package`.  This will generate two packages:

 - `chaps_<version>_<platform>.deb`: Chaps system daemon
 - `libchaps0_<version>_<platform>.deb`: PKCS#11 client library


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

 - If the `CHAPS_SYSTEM_TOKEN` variable in `/etc/default/chaps` is set (the default), the
   Chaps daemon will load a system-wide token on startup.
 - If the Chaps PAM module is enabled (via `pam-auth-update`) then per-user tokens will be
   created when a user logs in.
