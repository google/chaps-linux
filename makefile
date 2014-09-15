# Version information
CHAPS_VERSION=0.1
DEB_REVISION=1
DEB_VERSION=$(CHAPS_VERSION)-$(DEB_REVISION)

# The following should match platform2/chaps/Makefile $BASE_VER
CHROMEBASE_VER=293518
GMOCK_VERSION=1.7.0

# Absolute location of the src/ source tree
SRCDIR=$(CURDIR)/src
# Output from Chaps build.
OUTDIR=$(SRCDIR)/out

all: build


######################################
# Generate a source tree under src/
src_generate: src_includes src_makefiles src_gmock src_chromebase src_platform2
src:
	mkdir -p $@

# Copy across some include files from the build directory
src_includes: src/include/build/build_config.h src/include/trousers/scoped_tss_type.h src/include/testing/gtest/include/gtest/gtest_prod.h src/include/leveldb/memenv.h
src/include: | src
	mkdir -p $@
src/include/build: | src/include
	mkdir -p $@
src/include/trousers: | src/include
	mkdir -p $@
src/include/leveldb: | src/include
	mkdir -p $@
src/include/testing/gtest/include/gtest: | src/include
	mkdir -p $@

# Build configuration file for Chromium source code build.
src/include/build/build_config.h: extrasrc/build_config.h | src/include/build
	cp $< $@
# ChromiumOS's version of Trousers has an additional utility class to allow RAII use
# of TSS types.  Include a local copy of this, as Chaps uses it.
src/include/trousers/scoped_tss_type.h: extrasrc/scoped_tss_type.h | src/include/trousers
	cp $< $@
# Chromium includes <leveldb/memenv.h>.  This requires an install of libleveldb-dev that has
# memenv support included; move this into a local leveldb/ subdirectory
src/include/leveldb/memenv.h: /usr/include/leveldb/helpers/memenv.h | src/include/leveldb
	cp $< $@
# Chromium includes <include/testing/gtest/include/gtest/gtest_prod.h>, so have a local copy.
src/include/testing/gtest/include/gtest/gtest_prod.h: extrasrc/gtest_prod.h | src/include/testing/gtest/include/gtest
	cp $< $@


# Copy across some build files from the build directory into src/
BUILDFILES=Makefile Sconstruct.libchrome Sconstruct.libchromeos
SRC_BUILDFILES=$(addprefix src/, $(BUILDFILES))
src_makefiles: $(SRC_BUILDFILES)
src/Makefile: extrasrc/Makefile | src
	sed 's/@BASE_VER@/$(CHROMEBASE_VER)/' $< | sed 's/@GMOCK_VER@/$(GMOCK_VERSION)/' >$@
src/Sconstruct.libchrome: extrasrc/Sconstruct.libchrome | src
	cp $< $@
src/Sconstruct.libchromeos: extrasrc/Sconstruct.libchromeos | src
	cp $< $@


# Various parts of Chromium include gTest files.  To ensure consistency, get a local
# copy of gMock and gTest (rather than picking up whatever version is installed).
GMOCK_URL=https://googlemock.googlecode.com/files/gmock-$(GMOCK_VERSION).zip
GMOCK_DIR=$(CURDIR)/src/gmock-$(GMOCK_VERSION)
GTEST_DIR=$(GMOCK_DIR)/gtest
src_gmock: | $(GMOCK_DIR)
src/gmock-$(GMOCK_VERSION).zip: | src
	cd src && wget $(GMOCK_URL)
$(GMOCK_DIR): src/gmock-$(GMOCK_VERSION).zip
	cd src && unzip -q gmock-$(GMOCK_VERSION).zip


# Chaps relies on utility code from Chromium base libraries, at:
CHROMEBASE_GIT=https://chromium.googlesource.com/chromium/src/base.git
# The particular version of the Chromium base library required by platforms2/chaps
# is indicated by the BASE_VER value in platform2/chaps/Makefile.
#  - http://crrev/$BASE_VER returns a 302-redirect to the corresponding Git commit in
#    the Chromium source code.  Call this SHA_A
#  - However, this is a commit-ID in the master src.git repositiory, which is huge.
#    We're only interested in code under base/, which gets pulled into a separate
#    (smaller) Git repo base.git.
#  - Running `git log -n 1 .. $SHA_A base/` in the full src.git repo gives the SHA1
#    for the last commit that affected base/ and so should also be in base.git. Call
#    this SHA_B.
#  - Under base.git, running `git log --grep $SHA_B` gives the corresponding commit
#    in the base.git tree.  Call this SHA_C.
#  - This $SHA_C hash value from base.git is used here.
CHROMEBASE_COMMIT=c683753f6613efa9a553ce4a9e2c159afbc9277e
src_chromebase: src/base/base64.h
src/base: | src
	mkdir -p $@
src/base/base64.h: | src/base
	git clone $(CHROMEBASE_GIT) src/base
	cd src/base && git checkout $(CHROMEBASE_COMMIT)
	cd src/base && git am $(CURDIR)/patches/base.patch

# Chaps is included in the platform2 repository from ChromiumOS, as are various
# utility libraries (under libchromeos/chromeos) that it requires.
src_platform2: src/platform2/chaps
src/platform2:
	mkdir -p $@
PLATFORM2_GIT=https://chromium.googlesource.com/chromiumos/platform2
src/platform2/chaps: | src/platform2
	git clone $(PLATFORM2_GIT) src/platform2
	cd src/platform2 && git checkout -b linux
	cd src/platform2 && git am $(CURDIR)/patches/platform2.patch


######################################
# Build/Clean/Test - defer to src/Makefile
build: src/Makefile
	cd src && $(MAKE)
clean: src/Makefile
	cd src && $(MAKE) clean
test: src/Makefile
	cd src && $(MAKE) test



######################################
# Distclean: remove source
distclean:
	rm -rf src


######################################
# Source tarball
SRC_TARBALL=chaps-$(CHAPS_VERSION).tar.gz
dist: src/$(SRC_TARBALL)

src/$(SRC_TARBALL): $(SRC_BUILDFILES) src_includes src_makefiles src_chromebase src_platform2
	cd src && tar --transform "s,^,chaps-$(CHAPS_VERSION)/," --exclude-vcs --dereference -czf $(SRC_TARBALL) base platform2/chaps platform2/libchromeos/chromeos include gmock-$(GMOCK_VERSION) $(BUILDFILES)
clean_tarball:
	rm -f src/$(SRC_TARBALL)

