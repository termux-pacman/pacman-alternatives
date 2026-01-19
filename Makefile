include config.mk

default: install

$(OUTPUT):
	cp -r $(SOURCE) $(OUTPUT)
	sed -i "s|@BASHPATH@|$(BASHPATH)|; \
		s|@SYSDIR@|$(SYSDIR)|; \
		s|@PREFIX@|$(PREFIX)|; \
		s|@ALTER_FILES_PATH@|$(ALTER_FILES_PATH)|; \
		s|@ENABLED_ALTERS_PATH@|$(ENABLED_ALTERS_PATH)|" $(OUTPUT)

install-alpm-hooks:
	$(MAKE) -C alpm-hooks

install-$(OUTPUT): $(OUTPUT)
	mkdir -p $(ALTER_FILES_FULLPATH)
	mkdir -p $(ENABLED_ALTERS_FULLPATH)
	install -Dm755 $(OUTPUT) $(BINDIR)

install: install-$(OUTPUT) install-alpm-hooks

clean:
	rm -fr $(OUTPUT)
	$(MAKE) -C alpm-hooks clean
