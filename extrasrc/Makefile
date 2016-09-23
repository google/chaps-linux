# Top-level Makefile for Chaps standalone Linux build.
BASE_VER ?= @BASE_VER@
GMOCK_VER ?= @GMOCK_VER@
CHAPS_VERSION_MAJOR ?= @CHAPS_VERSION_MAJOR@
CHAPS_VERSION_MINOR ?= @CHAPS_VERSION_MINOR@
CHAPS_VERSION=$(CHAPS_VERSION_MAJOR).$(CHAPS_VERSION_MINOR)

SRCDIR=$(CURDIR)
OUTDIR=$(SRCDIR)/out
GMOCK_DIR=$(SRCDIR)/googletest-release-$(GMOCK_VER)/googlemock
GTEST_DIR=$(SRCDIR)/googletest-release-$(GMOCK_VER)/googletest

INCLUDES="-I$(SRCDIR)/include -I$(SRCDIR)/libchromeos -isystem $(GTEST_DIR)/include -I$(GMOCK_DIR)/include -I$(SRCDIR)/leveldb/include"

# To build Chaps, defer to platform2/chaps/Makefile
all: libchrome-$(BASE_VER).a libbrillo-$(BASE_VER).a | out
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(SRCDIR) CXXFLAGS=$(INCLUDES) OUT=$(OUTDIR) CHAPS_VERSION_MAJOR=$(CHAPS_VERSION_MAJOR) CHAPS_VERSION_MINOR=$(CHAPS_VERSION_MINOR) $(MAKE)

# To build required Chromium components, defer to scons file.
libchrome-$(BASE_VER).a:
	BASE_VER=$(BASE_VER) GTEST_DIR=$(GTEST_DIR) scons -f Sconstruct.libchrome

# To build required Brillo/ChromiumOS components, defer to scons file.
libbrillo-$(BASE_VER).a:
	BASE_VER=$(BASE_VER) scons -f Sconstruct.libchromeos

out:
	mkdir -p $@


out/gtest-all.o: | out
	$(CXX) -isystem $(GTEST_DIR)/include -I$(GTEST_DIR) -pthread -c $(GTEST_DIR)/src/gtest-all.cc -o $@
out/libgtest.a: out/gtest-all.o
	ar -rv $@ $<
out/gmock-all.o: | out
	$(CXX) -isystem $(GTEST_DIR)/include -I$(GTEST_DIR) -isystem $(GMOCK_DIR)/include -I$(GMOCK_DIR) -pthread -std=gnu++11 -c $(GMOCK_DIR)/src/gmock-all.cc -o $@
out/libgmock.a: out/gmock-all.o
	ar -rv $@ $<

test: out/libgtest.a out/libgmock.a libchrome-$(BASE_VER).a libbrillo-$(BASE_VER).a | out
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(SRCDIR) CXXFLAGS=$(INCLUDES) LDLIBS="-L$(OUTDIR)" OUT=$(OUTDIR) $(MAKE) tests

clean: clean_chaps clean_chromeos clean_chromebase clean_gmock clean_debian
clean_gmock:
	rm -rf $(OUTDIR)/gtest-all.out $(OUTDIR)/libgtest.a
	rm -rf $(OUTDIR)/gmock-all.out $(OUTDIR)/libgmock.a
clean_chromebase:
	-BASE_VER=$(BASE_VER) scons -f Sconstruct.libchrome -c
clean_chromeos:
	-BASE_VER=$(BASE_VER) scons -f Sconstruct.libchromeos -c
clean_chaps:
	-cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(SRCDIR) $(MAKE) clean
	rm -rf out
clean_debian:
	dh_clean


distclean: clean
	rm -f .sconsign.dblite

INSTALL ?= install
MANDIR=$(DESTDIR)/usr/share/man
install_man:
	$(INSTALL) -m 0644 -D man/chapsd.8 $(MANDIR)/man8/chapsd.8
	$(INSTALL) -m 0644 -D man/chaps_client.8 $(MANDIR)/man8/chaps_client.8
install: install_man
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(SRCDIR) CXXFLAGS=$(INCLUDES) OUT=$(OUTDIR) CHAPS_VERSION_MAJOR=$(CHAPS_VERSION_MAJOR) CHAPS_VERSION_MINOR=$(CHAPS_VERSION_MINOR) $(MAKE) install_files
