SHELL = /bin/bash
FULL_DESTDIR =
ifneq ($(strip $(DESTDIR)),)
	FULL_DESTDIR = $(shell realpath $(DESTDIR))
endif

DEF_OS = linux
ifneq (,$(wildcard /system/bin/app_process))
	DEF_OS = android
endif

ifeq ($(DEF_OS),android)
	# pacman-based Termux
	SYSDIR = /data/data/com.termux/files/usr/
	PREFIX = /data/data/com.termux/files/usr
	READER_USER =
else
	# pacman-based Linux distributions
	SYSDIR = /
	PREFIX = /usr
	READER_USER = pacman-alternatives
endif
LINKDIR =
ROOTDIR =

ALTER_FILES_PATH = share/pacman-alternatives
ENABLED_ALTERS_PATH = var/lib/pacman/alternatives
ALTER_FILES_FULLPATH = $(shell grep -q "^/.*" <<< "$(ALTER_FILES_PATH)" && echo "" || echo "$(PREFIX)/")$(ALTER_FILES_PATH)
ifeq ($(DEF_OS),android)
	ENABLED_ALTERS_FULLPATH = $(shell grep -q "^/.*" <<< "$(ENABLED_ALTERS_PATH)" && echo "" || echo "$(PREFIX)/")$(ENABLED_ALTERS_PATH)
else
	ENABLED_ALTERS_FULLPATH = $(shell grep -q "^/.*" <<< "$(ENABLED_ALTERS_PATH)" && echo "" || echo "$(SYSDIR)/")$(ENABLED_ALTERS_PATH)
endif
ALTER_FILES_FULLPATH := $(shell realpath -m "$(ALTER_FILES_FULLPATH)")
ENABLED_ALTERS_FULLPATH := $(shell realpath -m "$(ENABLED_ALTERS_FULLPATH)")

BINDIR = $(PREFIX)/bin
BASHPATH = $(BINDIR)/bash
ALPMDIR = $(PREFIX)/share/libalpm
ALPM_HOOK_DIR = $(ALPMDIR)/hooks
ALPM_SCRIPT_DIR = $(ALPMDIR)/scripts

SOURCE = pacman-alternatives.sh
OUTPUT = pacman-alternatives
