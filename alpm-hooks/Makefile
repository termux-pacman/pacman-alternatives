include ../config.mk

default: install

HOOK_SOURCES = $(wildcard *.alpm-hook)
HOOKS = $(HOOK_SOURCES:.alpm-hook=.hook)

%.hook: %.alpm-hook
	sed "s|@ALTER_FILES_FULLPATH@|$(ALTER_FILES_FULLPATH)|g; \
		s|@ALPM_SCRIPT_DIR@|$(ALPM_SCRIPT_DIR)|g" $^ > $@

run-pacman-alternatives: run-pacman-alternatives.sh
	sed "s|@BASHPATH@|$(BASHPATH)|g" $^ > $@

install-hooks: $(HOOKS)
	install -Dm644 $^ $(ALPM_HOOK_DIR)

install-script: run-pacman-alternatives
	install -Dm755 run-pacman-alternatives $(ALPM_SCRIPT_DIR)

install: install-hooks install-script

clean:
	rm -fr $(HOOKS) run-pacman-alternatives
