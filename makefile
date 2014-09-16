# Version information
CHAPS_VERSION=0.1
DEB_REVISION=2
DEB_VERSION=$(CHAPS_VERSION)-$(DEB_REVISION)

# The following should match platform2/chaps/Makefile $BASE_VER
CHROMEBASE_VER=293518
GMOCK_VERSION=1.7.0

# Absolute location of the source tree
SRCDIR_REL=chaps-$(CHAPS_VERSION)
SRCDIR=$(CURDIR)/$(SRCDIR_REL)
# Output from Chaps build.
OUTDIR=$(SRCDIR)/out

all: build


######################################
# Generate a source tree
src_generate: src_includes src_makefiles src_gmock src_chromebase src_platform2 src_debian
$(SRCDIR):
	mkdir -p $@

# Copy across some include files from the build directory
src_includes: $(SRCDIR)/include/build/build_config.h $(SRCDIR)/include/trousers/scoped_tss_type.h $(SRCDIR)/include/testing/gtest/include/gtest/gtest_prod.h $(SRCDIR)/include/leveldb/memenv.h
$(SRCDIR)/include: | $(SRCDIR)
	mkdir -p $@
$(SRCDIR)/include/build: | $(SRCDIR)/include
	mkdir -p $@
$(SRCDIR)/include/trousers: | $(SRCDIR)/include
	mkdir -p $@
$(SRCDIR)/include/leveldb: | $(SRCDIR)/include
	mkdir -p $@
$(SRCDIR)/include/testing/gtest/include/gtest: | $(SRCDIR)/include
	mkdir -p $@

# Build configuration file for Chromium source code build.
$(SRCDIR)/include/build/build_config.h: extrasrc/build_config.h | $(SRCDIR)/include/build
	cp $< $@
# ChromiumOS's version of Trousers has an additional utility class to allow RAII use
# of TSS types.  Include a local copy of this, as Chaps uses it.
$(SRCDIR)/include/trousers/scoped_tss_type.h: extrasrc/scoped_tss_type.h | $(SRCDIR)/include/trousers
	cp $< $@
# Chromium includes <leveldb/memenv.h>.  This requires an install of libleveldb-dev that has
# memenv support included; move this into a local leveldb/ subdirectory
$(SRCDIR)/include/leveldb/memenv.h: /usr/include/leveldb/helpers/memenv.h | $(SRCDIR)/include/leveldb
	cp $< $@
# Chromium includes <include/testing/gtest/include/gtest/gtest_prod.h>, so have a local copy.
$(SRCDIR)/include/testing/gtest/include/gtest/gtest_prod.h: extrasrc/gtest_prod.h | $(SRCDIR)/include/testing/gtest/include/gtest
	cp $< $@


# Copy across some build files from the build directory into source directory.
BUILDFILES=Makefile Sconstruct.libchrome Sconstruct.libchromeos
SRC_BUILDFILES=$(addprefix $(SRCDIR_REL)/, $(BUILDFILES))
src_makefiles: $(SRC_BUILDFILES)
$(SRCDIR_REL)/Makefile: extrasrc/Makefile | $(SRCDIR)
	sed 's/@BASE_VER@/$(CHROMEBASE_VER)/' $< | sed 's/@GMOCK_VER@/$(GMOCK_VERSION)/' >$@
$(SRCDIR_REL)/Sconstruct.libchrome: extrasrc/Sconstruct.libchrome | $(SRCDIR)
	cp $< $@
$(SRCDIR_REL)/Sconstruct.libchromeos: extrasrc/Sconstruct.libchromeos | $(SRCDIR)
	cp $< $@


# Various parts of Chromium include gTest files.  To ensure consistency, get a local
# copy of gMock and gTest (rather than picking up whatever version is installed).
GMOCK_URL=https://googlemock.googlecode.com/files/gmock-$(GMOCK_VERSION).zip
GMOCK_DIR=$(SRCDIR)/gmock-$(GMOCK_VERSION)
GTEST_DIR=$(GMOCK_DIR)/gtest
src_gmock: $(GMOCK_DIR)/LICENSE
$(GMOCK_DIR)/LICENSE: | $(SRCDIR)
	cd $(SRCDIR) && wget $(GMOCK_URL)
	cd $(SRCDIR) && unzip -q gmock-$(GMOCK_VERSION).zip
	rm $(SRCDIR)/gmock-$(GMOCK_VERSION).zip
	touch $@


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
src_chromebase: $(SRCDIR)/base/base64.h
$(SRCDIR)/base: | $(SRCDIR)
	mkdir -p $@
$(SRCDIR)/base/base64.h: | $(SRCDIR)/base
	git clone $(CHROMEBASE_GIT) $(SRCDIR)/base
	cd $(SRCDIR)/base && git checkout $(CHROMEBASE_COMMIT)
	cd $(SRCDIR)/base && git am $(CURDIR)/patches/base.patch

# We need two subdirectories from the platform2 repository from ChromiumOS:
#   - chaps/ for the Chaps source code
#   - libchromeos/chromeos/ for various utilities that Chaps requires.
src_platform2: $(SRCDIR)/platform2/chaps/Makefile
$(SRCDIR)/platform2:
	mkdir -p $@
PLATFORM2_GIT=https://chromium.googlesource.com/chromiumos/platform2
$(SRCDIR)/platform2/chaps/Makefile: | $(SRCDIR)/platform2
	cd $(SRCDIR)/platform2 && git init . && git remote add -f origin $(PLATFORM2_GIT)
	cd $(SRCDIR)/platform2 && git config core.sparsecheckout true
	cd $(SRCDIR)/platform2 && echo "chaps" > .git/info/sparse-checkout
	cd $(SRCDIR)/platform2 && echo "libchromeos/chromeos" >> .git/info/sparse-checkout
	cd $(SRCDIR)/platform2 && echo "common-mk/common.mk" >> .git/info/sparse-checkout
	cd $(SRCDIR)/platform2 && git pull origin master
	cd $(SRCDIR)/platform2 && git am $(CURDIR)/patches/platform2.patch


# Copy Debian packaging files
DEBIAN_MASTER_FILES=$(wildcard debian/* debian/source/*)
DEBIAN_FILES=$(addprefix $(SRCDIR)/,$(DEBIAN_MASTER_FILES))
src_debian: $(DEBIAN_FILES)
$(SRCDIR)/debian:
	mkdir -p $@
$(SRCDIR)/debian/%: debian/% | $(SRCDIR)/debian
	cp $< $@
$(SRCDIR)/debian/source:
	mkdir -p $@
$(SRCDIR)/debian/source/%: debian/source/% | $(SRCDIR)/debian/source
	cp $< $@


######################################
# Build/Clean/Test - defer to chaps-<VER>/Makefile
build: src_generate
	cd $(SRCDIR) && $(MAKE)
clean: src_generate
	cd $(SRCDIR) && $(MAKE) clean
test: src_generate
	cd $(SRCDIR) && $(MAKE) test


######################################
# Source tarball
SRC_TARBALL=chaps-$(CHAPS_VERSION).tar.gz
dist: $(SRC_TARBALL)

$(SRC_TARBALL): src_generate
	tar --exclude-vcs -czf $@ $(SRCDIR_REL)/base $(SRCDIR_REL)/platform2/chaps $(SRCDIR_REL)/platform2/libchromeos/chromeos $(SRCDIR_REL)/platform2/common-mk $(SRCDIR_REL)/include $(SRCDIR_REL)/gmock-$(GMOCK_VERSION) $(SRC_BUILDFILES) $(SRCDIR_REL)/debian
clean_dist:
	rm -f $(SRC_TARBALL)


######################################
# Debian source package
src-package: chaps_$(CHAPS_VERSION).orig.tar.gz
	cd $(SRCDIR) && dpkg-buildpackage -us -uc -S
chaps_$(CHAPS_VERSION).orig.tar.gz: $(SRC_TARBALL)
	cp -f $< $@


######################################
# Debian binary package
package: chaps_$(DEB_VERSION)_amd64.deb
chaps_$(DEB_VERSION)_amd64.deb: src_generate
	cd $(SRCDIR) && dpkg-buildpackage -us -uc -b
clean_package:
	rm -f chaps_$(DEB_VERSION)_amd64.deb


######################################
# Distclean: remove source and packages
distclean:
	rm -rf $(SRCDIR)
	rm -f chaps_$(DEB_VERSION)_amd64.deb
	rm -f chaps_$(CHAPS_VERSION).orig.tar.gz chaps_$(DEB_VERSION).debian.tar.gz chaps_$(DEB_VERSION)_source.changes chaps_$(DEB_VERSION).dsc
	rm -f $(SRC_TARBALL)
