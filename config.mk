SHELL = /bin/bash
FULL_DESTDIR =
ifneq ($(strip $(DESTDIR)),)
	FULL_DESTDIR = $(shell realpath $(DESTDIR))
endif

ifneq (,$(wildcard /system/bin/app_process))
	# for android (termux)
	SYSDIR = /data/data/com.termux/files/usr/
	PREFIX = /data/data/com.termux/files/usr
else
	# for other Linux OS
	SYSDIR = /
	PREFIX = /usr
endif

ALTER_FILES_PATH = share/pacman-alternatives
ENABLED_ALTERS_PATH = var/lib/pacman/alternatives
ALTER_FILES_FULLPATH = $(shell grep -q "^/.*" <<< "$(ALTER_FILES_PATH)" && echo "" || echo "$(PREFIX)/")$(ALTER_FILES_PATH)
ENABLED_ALTERS_FULLPATH = $(shell grep -q "^/.*" <<< "$(ENABLED_ALTERS_PATH)" && echo "" || echo "$(PREFIX)/")$(ENABLED_ALTERS_PATH)

BINDIR = $(PREFIX)/bin
BASHPATH = $(BINDIR)/bash
ALPMDIR = $(PREFIX)/share/libalpm
ALPM_HOOK_DIR = $(ALPMDIR)/hooks
ALPM_SCRIPT_DIR = $(ALPMDIR)/scripts

SOURCE = pacman-alternatives.sh
OUTPUT = pacman-alternatives
