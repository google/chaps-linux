Chaps: A PKCS #11 Implementation For Linux
==========================================

**NOTE: As of ~May 2017 this repository is unmaintained and does not build**

This repository is a framework for building and packaging the Chaps
[PKCS #11](http://www.emc.com/emc-plus/rsa-labs/standards-initiatives/pkcs-11-cryptographic-token-interface-standard.htm)
implementation from
[ChromiumOS](http://www.chromium.org/developers/design-documents/chaps-technical-design)
on Linux.  Chaps provides an alternative to [OpenCryptoKi](http://sourceforge.net/projects/opencryptoki/)
that has been [designed](http://www.chromium.org/developers/design-documents/chaps-technical-design#TOC-Rationale)
to be faster and more maintainable.

This repo does **not** hold the source code for Chaps; instead, the build files here retrieve the
source code from the
[ChromiumOS open source project](https://chromium.googlesource.com/chromiumos/platform2/),
together with the other required source code from the
[Chromium open source project](https://chromium.googlesource.com/chromium/src/base.git).

The Linux build of Chaps is still under development, and should be considered to be **alpha status**.

This is NOT an official Google product.


Installing Chaps
----------------

To build and install Chaps on a Debian-based Linux system:

 - Build the Chaps packages:
    - Install the prerequisites: `sudo apt-get install debhelper scons protobuf-compiler libdbus-1-dev libdbus-c++-dev
      libprotobuf-dev libsnappy-dev libleveldb-dev libglib2.0-dev libctemplate-dev libssl-dev libtspi-dev libpam0g-dev`
    - Ensure that the TPM is initialized and accessible (see below).
    - Build a source tree (under `chaps-<version>`) with `make src_generate`
    - Build the packages with `make package`
 - Install the Chaps packages:
    - Install the packages with `sudo dpkg -i chaps_*_amd64.deb libchaps0_*_amd64.deb`
        - This needs some pre-requisite packages to be installed, notably [TrouSerS](http://trousers.sourceforge.net/)
          (the key library that allows software access to the hardware TPM).
    - Log out and in again, so that Chaps can create a per-user token.


Package Configuration
---------------------

The behavior of the Chaps package is influenced by two configuration values:

 - If the `CHAPS_SYSTEM_TOKEN` variable in `/etc/default/chaps` is set (the default), the
   Chaps daemon will load a system-wide token on startup.
 - If the Chaps PAM module is enabled (via `pam-auth-update`) then per-user tokens will be
   created when a user logs in.


PKCS#11 and TPMs
----------------

[PKCS #11](http://www.emc.com/emc-plus/rsa-labs/standards-initiatives/pkcs-11-cryptographic-token-interface-standard.htm)
is a standard C API for accessing cryptographic hardware.  The API allows encryption/decryption with both symmetric and
asymmetric keys, together with signature generation/verification and random number generation.

In Chaps, the majority of these cryptographic operations are performed in software (using the OpenSSL libraries); however, the
presence of a *trusted platform module* (TPM) on the system allows for a few key operations to be performed in hardware:

 - Random number generation.
 - Generation of RSA public/private keypairs.
 - Wrapping/unwrapping of other keys (i.e. encrypting/decrypting them).

This enables a key use case for PKCS#11: storing cryptographic material so that it can only be used on the local
machine.  A key can be stored in encrypted form, where decrypting the key (eventually) requires the use of a private
key that is held in the TPM, and which cannot be extracted from the TPM.  This means that an attacker with that gets
full access to the local machine's disk still can't access the key.  (If a TPM is not available, this protection is
obviously not available, but Chaps will continue to work.)


PKCS#11 Slots and Users
-----------------------

In the PKCS#11 API, an item of cryptographic hardware is known as a *token*, and tokens are accessed via a particular
*slot*.

```
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
```

The PKCS#11 API also includes authentication to allow token contents to be secured, where the API user needs to log-in to
access *private* objects on the token.  However, there is only a single user PIN/password for the whole API; the PKCS#11
API has no mechanism to allow different users to store cryptographic material and be isolated from each other.
(The API does include another role with a distinct PIN/password, the *security officer*, but this role is intended for
administrative operations &ndash; such as resetting the token or the user's PIN &ndash; rather than cryptographic operations.)

Therefore, to allow multi-user use, Chaps does not make use of the PKCS#11 login mechanism (`C_Login`).  Instead, Chaps
creates a token (held under `/var/lib/chaps/tokens/<user>/`) for each user when it first sees that user log in to the
system, together with a blob of authentication data that is only visible to that user (in
`/var/lib/chaps/isolates/<user>`).  When that user subsequently makes PKCS#11 API calls, only their own slot/token
contents are visible to them.
(To ease compatibility with other PKCS#11 implementations, Chaps will accept a `C_Login` operation with a PIN of
'111111', although this is a no-op;  Chaps does not allow `C_Login` for the security office role.)

The contents of the per-user token are encrypted using a hash of the user's password, which means that the user's
token is only available when they are properly logged in (i.e. `su <user>` as `root` does not give access).  However,
this does impose a requirement for the user to re-login after installation (and after anything that restarts the Chaps
system daemon).

Chaps also optionally provides a system token, which is visible to users that do not have their own per-user token,
because no PAM login event has occurred for them (e.g. for privileged users like `root`, or because PAM notifications
are administratively disabled on the system).  This option is configured via `CHAPS_SYSTEM_TOKEN` variable in
`/etc/default/chaps`, which controls the `--auto_load_system_token` option for the `chapsd` system daemon.


TPM Initialization and Configuration
------------------------------------

A system with a hardware TPM may need configuration and initialization before the TPM is available for use by Chaps.
Working upwards from the hardware, the things to configure and check are as follows; **note that re-initializing the TPM
will make any pre-existing TPM-backed cryptographic material inaccessible**:

 - Check the TPM is visible to the system with the `tpm_version` command (from the
   [`tpm-tools` package](https://packages.debian.org/wheezy/tpm-tools)). If not:
    - Confirm that the TPM is enabled.  This is usually a BIOS setup option, although note that accessing all of
      the relevant BIOS TPM options may require a [cold boot](http://support.lenovo.com/us/en/documents/ht003928).
        - If the TPM has been configured previously and the owner password is not known, it will need to be cleared via
          the cold-boot BIOS options or `tpm_clear --force`. Obviously **this will destroy any previous cryptographic
          material**.
        - The TPM needs to be *enabled* and *ownable*.
    - Confirm that the local kernel has been configured with TPM support
        - either compiled-in to the kernel: `grep -i tpm /boot/config-$(uname -r)`
        - or available as a module: `lsmod | grep -i tpm`
    - Confirm that [Trousers](https://packages.debian.org/wheezy/trousers) is installed and running (`ps -ef | grep tcsd`).
 - The system also needs to have *taken ownership* of the TPM, which generates the *storage root key* (SRK) that will
   encrypt sensitive material.  This operation also involves setting two passwords:
     - The *SRK password* governs use of the storage root key, and so is needed for most TPM operations.
     - The *owner password* governs authentication of the TPM itself; in particular, it is needed to change the SRK
       password.
 - The `tpm_takeownership` command performs the take-ownership operation, if required.  To use the TPM with Chaps,
   specify an empty SRK password, and whatever you like for the owner password.  (Note that an empty password is
   **different** than the `--well-known` option to this tool, which uses a 20-bytes-of-zero password.)
     - If the SRK already has a non-empty password, Chaps can be configured to use this password with the
       `--srk_password` or `--srk_zeros` options to `chapsd`.  However, these options are not currently exposed
       externally (i.e. they cannot be configured in `/etc/default/chaps`), and a non-empty SRK password would
       prevent current Debian versions of OpenCryptoKi from using the TPM.


Troubleshooting
---------------

Chaps emits log messages to the system log (e.g. `/var/log/syslog`); the verbosity of these logs can be altered
with `chaps_client --set_log_level=<level>`.

 - If any operation fails with a "No EK" error, ensure that the TPM has generated an *endorsement key* (EK) that
   identifies the TPM (which is normally only created once at first use of the TPM). The `tpm_getpubek` command displays
   this (and requires the owner password); if no EK is available, generate one with `tpm_createek`.
 - Check for the following errors from `chapsd` in the system log:
     - `TPM_E_NOSRK` indicates that the TPM has not been taken ownership of. Use `tpm_takeownership` to take ownership,
       which generates an SRK and setting the owner and SRK passwords.
     - `TPM_E_AUTHFAIL` indicates that the Chaps and the TPM have different ideas of what the SRK password is.  Use
       `tpm_changeownerauth` (which requires the TPM owner password) to set an empty SRK password.
     - `TPM_E_DEFEND_LOCK_RUNNING` indicates that the TPM is defending against dictionary attacks after multiple failed
        password attempts.  Wait for the timer to expire, or use `tpm_resetdalock` (which requires the TPM owner
        password) to reset the lock.
 - If no slots are visible (with `pkcs11-tool --module /usr/lib/libchaps.so.0 --list-slots`):
     - Try logging out and in again.
     - Check that PAM authentication is enabled.
     - For users that never log in, check whether the system token option is enabled.


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

 - Create a source tree under `chaps-<version>/` via the `src_generate` target:
     - Download the relevant ChromiumOS and Chromium code under `chaps-<version>/`.
     - Copy additional files needed for the Linux build.
 - Build the library code that Chaps needs:
     - `chaps-<version>/libchrome-$(BASE_VER).a`: Chromium utility code
     - `chaps-<version>/libchromeos-$(BASE_VER).a`: ChromiumOS utility code
 - Build the Chaps code into binaries in `chaps-<version>/out/`.

To build Debian packages, run `make package`.  This will generate two packages:

 - `chaps_<version>_<platform>.deb`: Chaps system daemon
 - `libchaps0_<version>_<platform>.deb`: PKCS#11 client library

A corresponding source package can be generated with `make src-package`.

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

Executing the `src_generate` target of the master `makefile` will retrieve
additional source code from various upstream locations, and will place it
under `chaps-<version>/`.

 - `chaps-<version>/base`: Chromium base library code from
   [https://chromium.googlesource.com/chromium/src/base](https://chromium.googlesource.com/chromium/src/base)
 - `chaps-<version>/platform2`: ChromiumOS core code, including Chaps and utility libraries required by Chaps, from
   [https://chromium.googlesource.com/chromiumos/platform2](https://chromium.googlesource.com/chromiumos/platform2)
 - `chaps-<version>/googletest-release-<version>`: GoogleMock and GoogleTest code
 - `chaps-<version>/include`: Local include files
 - `chaps-<version>/debian`: Local Debian packaging files
 - `chaps-<version>/man`: man pages


Versioning
----------

The Chaps source code tree is primarily built from two upstream repositories,
ChromiumOS's [platform2](https://chromium.googlesource.com/chromiumos/platform2)
repo together with the
[base](https://chromium.googlesource.com/chromium/src/base) repo from Chromium.

The platform2 code has branches named like `release-R42-6812.B` that correspond
to CrOS releases, and the equivalent Debian package for Chaps will have version
0.42-6812-<debian_revision>.

To update Chaps so that it corresponds to a new CrOS release:
 - Change the `CROS_VERSION` variable in `Makefile` to match the numeric part of
   the CrOS release ID; for example, release-R42-6812.B gives
   `CROS_VERSION=42-6812`
 - Find the value of `BASE_VER` in `platform2/chaps/Makefile` (as of the
   relevant CrOS branch for the release, e.g. `origin/release-R42-6812.B`).
   This indicates the revision of the Chromium base repo that is expected.
 - Update the `CHROMEBASE_VER` value in `Makefile` to match that value.
 - Follow the instructions in `Makefile` to determine a commit ID for
   the Chromium [base](https://chromium.googlesource.com/chromium/src/base) repo
   that matches that `BASE_VER` revision.
 - Update the `CHROMEBASE_COMMIT` value in `Makefile` to hold that commit ID.
 - Update the `debian/changelog` file to include a stanza for the new version,
   and describe the changes therein.
 - Reset the `DEB_REVISION` value in `Makefile` to 1.
 - Force a re-generation of the source tree with `make distclean`.

If the upstream source remains the same, but there are local packaging changes
or patches, then just the `DEB_REVISION` value in `Makefile` needs to be incremented.
