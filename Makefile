include config.mk

default: install

$(OUTPUT):
	cp -r $(SOURCE) $@
	sed -i "s|@BASHPATH@|$(BASHPATH)|; \
		s|@SYSDIR@|$(SYSDIR)|; \
		s|@PREFIX@|$(PREFIX)|; \
		s|@ALTER_FILES_PATH@|$(ALTER_FILES_PATH)|; \
		s|@ENABLED_ALTERS_PATH@|$(ENABLED_ALTERS_PATH)|" $@

install-alpm-hooks:
	$(MAKE) -C alpm-hooks DESTDIR="$(FULL_DESTDIR)"

install-$(OUTPUT): $(OUTPUT)
	mkdir -p $(FULL_DESTDIR)$(ALTER_FILES_FULLPATH)
	mkdir -p $(FULL_DESTDIR)$(ENABLED_ALTERS_FULLPATH)
	install -Dm755 $^ $(FULL_DESTDIR)$(BINDIR)/$^

install: install-$(OUTPUT) install-alpm-hooks

clean:
	rm -fr $(OUTPUT)
	$(MAKE) -C alpm-hooks clean
