# Top-level Makefile for Chaps standalone Linux build.
BASE_VER ?= @BASE_VER@
GMOCK_VER ?= @GMOCK_VER@

SRCDIR=$(CURDIR)
OUTDIR=$(SRCDIR)/out
GMOCK_DIR=$(SRCDIR)/gmock-$(GMOCK_VER)
GTEST_DIR=$(GMOCK_DIR)/gtest

INCLUDES="-I$(SRCDIR)/include -I$(SRCDIR)/platform2/libchromeos -isystem $(GTEST_DIR)/include -I$(GMOCK_DIR)/include -I$(SRCDIR)/leveldb/include"

all: out/libchaps.so

# To build required Chromium components, defer to scons file.
libchrome-$(BASE_VER).a:
	BASE_VER=$(BASE_VER) GTEST_DIR=$(GTEST_DIR) scons -f Sconstruct.libchrome

# To build required ChromiumOS components, defer to scons file.
build_libchromeos: libchromeos-$(BASE_VER).a
libchromeos-$(BASE_VER).a:
	BASE_VER=$(BASE_VER) scons -f Sconstruct.libchromeos

# To build Chaps, defer to platform2/chaps/Makefile
out:
	mkdir -p $@
out/libchaps.so: libchrome-$(BASE_VER).a libchromeos-$(BASE_VER).a | out
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(SRCDIR) CXXFLAGS=$(INCLUDES) OUT=$(OUTDIR) $(MAKE)


out/gtest-all.o: | out
	$(CXX) -isystem $(GTEST_DIR)/include -I$(GTEST_DIR) -pthread -c $(GTEST_DIR)/src/gtest-all.cc -o $@
out/libgtest.a: out/gtest-all.o
	ar -rv $@ $<
out/gmock-all.o: | out
	$(CXX) -isystem $(GTEST_DIR)/include -I$(GTEST_DIR) -isystem $(GMOCK_DIR)/include -I$(GMOCK_DIR) -pthread -std=gnu++11 -c $(GMOCK_DIR)/src/gmock-all.cc -o $@
out/libgmock.a: out/gmock-all.o
	ar -rv $@ $<

test: out/libgtest.a out/libgmock.a out/libchaps.so
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(SRCDIR) CXXFLAGS=$(INCLUDES) LDLIBS="-L$(OUTDIR)" OUT=$(OUTDIR) $(MAKE) tests

clean: clean_chaps clean_chromeos clean_chromebase clean_gmock
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


distclean: clean
	rm -f .sconsign.dblite

install:
	echo $(INSTALL)
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(SRCDIR) CXXFLAGS=$(INCLUDES) OUT=$(OUTDIR) $(MAKE) install_files
