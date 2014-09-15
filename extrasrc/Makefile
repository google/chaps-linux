# Top-level Makefile for Chaps standalone Linux build.

all:
	BASE_VER=$(BASE_VER) scons -f Sconstruct.libchrome
	BASE_VER=$(BASE_VER) scons -f Sconstruct.libchromeos
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(CURDIR) $(MAKE) all

clean:
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(CURDIR) $(MAKE) clean
	BASE_VER=$(BASE_VER) scons -c -f Sconstruct.libchromeos
	BASE_VER=$(BASE_VER) scons -c -f Sconstruct.libchrome

distclean: clean
	rm -f .sconsign.dblite

install:
	echo $(INSTALL)
	cd platform2/chaps && BASE_VER=$(BASE_VER) LINUX_BUILD=1 PKG_CONFIG_PATH=$(CURDIR) $(MAKE) install_files
