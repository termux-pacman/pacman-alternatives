include config.mk

default: install

$(OUTPUT):
	sed "s|@BASHPATH@|$(BASHPATH)|; \
		s|@SYSDIR@|$(SYSDIR)|; \
		s|@ROOTDIR@|$(ROOTDIR)|; \
		s|@LINKDIR@|$(LINKDIR)|; \
		s|@PREFIX@|$(PREFIX)|; \
		s|@ALTER_FILES_PATH@|$(ALTER_FILES_FULLPATH)|; \
		s|@ENABLED_ALTERS_PATH@|$(ENABLED_ALTERS_FULLPATH)|; \
		s|@READER_USER@|$(READER_USER)|" \
		$(SOURCE) > $@
	chmod +x $@

build: $(OUTPUT)

build-alpm-hooks:
	$(MAKE) -C alpm-hooks DESTDIR="$(FULL_DESTDIR)" build

build-all: build build-alpm-hooks

install-alpm-hooks:
	$(MAKE) -C alpm-hooks DESTDIR="$(FULL_DESTDIR)"

install-$(OUTPUT): $(OUTPUT)
	mkdir -p $(FULL_DESTDIR)$(ALTER_FILES_FULLPATH)
	mkdir -p $(FULL_DESTDIR)$(ENABLED_ALTERS_FULLPATH)
	install -Dm755 $^ $(FULL_DESTDIR)$(BINDIR)/$^
	@if [ "$^" != "palt" ]; then \
		ln -sfr $(FULL_DESTDIR)$(BINDIR)/$^ $(FULL_DESTDIR)$(BINDIR)/palt; \
	fi

create-linux-reader-user:
	useradd -r -s /usr/sbin/nologin -M $(READER_USER)

INSTALL_TARGETS = install-$(OUTPUT) install-alpm-hooks
ifneq ($(READER_USER),)
	INSTALL_TARGETS += create-linux-reader-user
endif
install: $(INSTALL_TARGETS)

clean:
	rm -fr $(OUTPUT)
	$(MAKE) -C alpm-hooks clean
