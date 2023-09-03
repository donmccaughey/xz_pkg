APP_SIGNING_ID ?= Developer ID Application: Donald McCaughey
INSTALLER_SIGNING_ID ?= Developer ID Installer: Donald McCaughey
NOTARIZATION_KEYCHAIN_PROFILE ?= Donald McCaughey
TMP ?= $(abspath tmp)

version := 5.4.4
revision := 1
archs := arm64 x86_64

rev := $(if $(patsubst 1,,$(revision)),-r$(revision),)
ver := $(version)$(rev)


.SECONDEXPANSION :


.PHONY : signed-package
signed-package : $(TMP)/xz-$(ver)-unnotarized.pkg


.PHONY : notarize
notarize : xz-$(ver).pkg


.PHONY : clean
clean :
	-rm -f xz-*.pkg
	-rm -rf $(TMP)


.PHONY : check
check :
	test "$(shell lipo -archs $(TMP)/install/usr/local/bin/lzmadec)" = "x86_64 arm64"
	test "$(shell lipo -archs $(TMP)/install/usr/local/bin/lzmainfo)" = "x86_64 arm64"
	test "$(shell lipo -archs $(TMP)/install/usr/local/bin/xz)" = "x86_64 arm64"
	test "$(shell lipo -archs $(TMP)/install/usr/local/bin/xzdec)" = "x86_64 arm64"
	test "$(shell lipo -archs $(TMP)/install/usr/local/lib/liblzma.a)" = "x86_64 arm64"
	test "$(shell lipo -archs $(TMP)/install/usr/local/lib/liblzma.5.dylib)" = "x86_64 arm64"
	test "$(shell ./tools/dylibs --no-sys-libs --count $(TMP)/install/usr/local/bin/lzmadec) dylibs" = "0 dylibs"
	test "$(shell ./tools/dylibs --no-sys-libs --count $(TMP)/install/usr/local/bin/lzmainfo) dylibs" = "0 dylibs"
	test "$(shell ./tools/dylibs --no-sys-libs --count $(TMP)/install/usr/local/bin/xz) dylibs" = "0 dylibs"
	test "$(shell ./tools/dylibs --no-sys-libs --count $(TMP)/install/usr/local/bin/xzdec) dylibs" = "0 dylibs"
	codesign --verify --strict $(TMP)/install/usr/local/bin/lzmadec
	codesign --verify --strict $(TMP)/install/usr/local/bin/lzmainfo
	codesign --verify --strict $(TMP)/install/usr/local/bin/xz
	codesign --verify --strict $(TMP)/install/usr/local/bin/xzdec
	codesign --verify --strict $(TMP)/install/usr/local/lib/liblzma.a
	codesign --verify --strict $(TMP)/install/usr/local/lib/liblzma.5.dylib
	pkgutil --check-signature xz-$(ver).pkg
	spctl --assess --type install xz-$(ver).pkg
	xcrun stapler validate xz-$(ver).pkg


##### compilation flags ##########

arch_flags = $(patsubst %,-arch %,$(archs))

CFLAGS += $(arch_flags)


##### dist ##########

dist_sources := $(shell find dist -type f \! -name .DS_Store)


##### build xz and lzmainfo, statically linked ##########

xz_options := --disable-shared

$(TMP)/build_xz/src/xz/xz : $(TMP)/build_xz/config.status $(dist_sources)
	cd $(TMP)/build_xz && $(MAKE)

$(TMP)/build_xz/config.status : dist/configure | $(TMP)/build_xz
	cd $(TMP)/build_xz && sh $(abspath $<) $(xz_options) CFLAGS='$(CFLAGS)'

$(TMP)/build_xz :
	mkdir -p $@

##### build xzdec and lzmadec, optimized for size ##########

dec_options := \
		--disable-encoders \
		--disable-nls \
		--disable-shared \
		--disable-threads \
		--enable-small
dec_CFLAGS := $(CFLAGS) -Os

$(TMP)/build_decs/src/xzdec/xzdec : $(TMP)/build_decs/config.status $(dist_sources)
	cd $(TMP)/build_decs && $(MAKE)

$(TMP)/build_decs/config.status : dist/configure | $(TMP)/build_decs
	cd $(TMP)/build_decs && sh $(abspath $<) $(dec_options) CFLAGS='$(dec_CFLAGS)'

$(TMP)/build_decs :
	mkdir -p $@

##### build liblzma, static and dynamic ##########

lib_options := 

$(TMP)/build_libs/src/liblzma/.libs/liblzma.a : $(TMP)/build_libs/config.status $(dist_sources)
	cd $(TMP)/build_libs && $(MAKE)

$(TMP)/build_libs/config.status : dist/configure | $(TMP)/build_libs
	cd $(TMP)/build_libs && sh $(abspath $<) $(lib_options) CFLAGS='$(CFLAGS)'

$(TMP)/build_libs :
	mkdir -p $@


##### assemble installed distribution and sign binaries ##########

$(TMP)/installed-and-signed.stamp.txt : \
		$(TMP)/build_xz/src/xz/xz \
		$(TMP)/build_decs/src/xzdec/xzdec \
		$(TMP)/build_libs/src/liblzma/.libs/liblzma.a \
		| $(TMP)/install
	cd $(TMP)/build_xz && $(MAKE) DESTDIR=$(TMP)/install install
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$(TMP)/install/usr/local/bin/xz
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$(TMP)/install/usr/local/bin/lzmainfo
	cd $(TMP)/build_decs/src/xzdec && $(MAKE) DESTDIR=$(TMP)/install install
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$(TMP)/install/usr/local/bin/xzdec
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$(TMP)/install/usr/local/bin/lzmadec
	cd $(TMP)/build_libs/src/liblzma && $(MAKE) DESTDIR=$(TMP)/install install
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$(TMP)/install/usr/local/lib/liblzma.a
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$(TMP)/install/usr/local/lib/liblzma.5.dylib
	date > $@

$(TMP)/install :
	mkdir -p $@


##### pkg ##########

$(TMP)/xz.pkg : \
		$(TMP)/install/usr/local/bin/uninstall-xz
	pkgbuild \
		--root $(TMP)/install \
		--identifier cc.donm.pkg.xz \
		--ownership recommended \
		--version $(version) \
		$@

$(TMP)/install/etc/paths.d/xz.path : \
		xz.path \
		$(TMP)/installed-and-signed.stamp.txt \
		| $$(dir $$@)
	cp $< $@

$(TMP)/install/usr/local/bin/uninstall-xz : \
		uninstall-xz \
		$(TMP)/install/etc/paths.d/xz.path \
		| $$(dir $$@)
	cp $< $@
	cd $(TMP)/install && find . -type f \! -name .DS_STORE | sort >> $@
	sed -e 's/^\./rm -f /g' -i '' $@
	chmod a+x $@

$(TMP)/install/etc/paths.d \
$(TMP)/install/usr/local/bin :
	mkdir -p $@


##### product ##########

arch_list := $(shell printf '%s' "$(archs)" | sed "s/ / and /g")
date := $(shell date '+%Y-%m-%d')
macos:=$(shell \
	system_profiler -detailLevel mini SPSoftwareDataType \
	| grep 'System Version:' \
	| awk -F ' ' '{print $$4}' \
	)
xcode:=$(shell \
	system_profiler -detailLevel mini SPDeveloperToolsDataType \
	| grep 'Version:' \
	| awk -F ' ' '{print $$2}' \
	)
 
$(TMP)/xz-$(ver)-unnotarized.pkg : \
		$(TMP)/xz.pkg \
		$(TMP)/build-report.txt \
		$(TMP)/distribution.xml \
		$(TMP)/resources/background.png \
		$(TMP)/resources/background-darkAqua.png \
		$(TMP)/resources/license.html \
		$(TMP)/resources/welcome.html
	productbuild \
		--distribution $(TMP)/distribution.xml \
		--resources $(TMP)/resources \
		--package-path $(TMP) \
		--version v$(version)-r$(revision) \
		--sign '$(INSTALLER_SIGNING_ID)' \
		$@

$(TMP)/build-report.txt : | $$(dir $$@)
	printf 'Build Date: %s\n' "$(date)" > $@
	printf 'Software Version: %s\n' "$(version)" >> $@
	printf 'Installer Revision: %s\n' "$(revision)" >> $@
	printf 'Architectures: %s\n' "$(arch_list)" >> $@
	printf 'macOS Version: %s\n' "$(macos)" >> $@
	printf 'Xcode Version: %s\n' "$(xcode)" >> $@
	printf 'APP_SIGNING_ID: %s\n' "$(APP_SIGNING_ID)" >> $@
	printf 'INSTALLER_SIGNING_ID: %s\n' "$(INSTALLER_SIGNING_ID)" >> $@
	printf 'NOTARIZATION_KEYCHAIN_PROFILE: %s\n' "$(NOTARIZATION_KEYCHAIN_PROFILE)" >> $@
	printf 'TMP directory: %s\n' "$(TMP)" >> $@
	printf 'CFLAGS: %s\n' "$(CFLAGS)" >> $@
	printf 'Tag: v%s-r%s\n' "$(version)" "$(revision)" >> $@
	printf 'Tag Title: XZ Utils %s for macOS rev %s\n' "$(version)" "$(revision)" >> $@
	printf 'Tag Message: A signed and notarized universal installer package for XZ Utils %s.\n' "$(version)" >> $@


$(TMP)/distribution.xml \
$(TMP)/resources/welcome.html : $(TMP)/% : % | $$(dir $$@)
	sed \
		-e 's/{{arch_list}}/$(arch_list)/g' \
		-e 's/{{date}}/$(date)/g' \
		-e 's/{{macos}}/$(macos)/g' \
		-e 's/{{revision}}/$(revision)/g' \
		-e 's/{{version}}/$(version)/g' \
		-e 's/{{xcode}}/$(xcode)/g' \
		$< > $@

$(TMP)/resources/background.png \
$(TMP)/resources/background-darkAqua.png \
$(TMP)/resources/license.html : $(TMP)/% : % | $(TMP)/resources
	cp $< $@

$(TMP) \
$(TMP)/resources :
	mkdir -p $@


##### notarization ##########

$(TMP)/submit-log.json : $(TMP)/xz-$(ver)-unnotarized.pkg | $$(dir $$@)
	xcrun notarytool submit $< \
		--keychain-profile "$(NOTARIZATION_KEYCHAIN_PROFILE)" \
		--output-format json \
		--wait \
		> $@

$(TMP)/submission-id.txt : $(TMP)/submit-log.json | $$(dir $$@)
	jq --raw-output '.id' < $< > $@

$(TMP)/notarization-log.json : $(TMP)/submission-id.txt | $$(dir $$@)
	xcrun notarytool log "$$(<$<)" \
		--keychain-profile "$(NOTARIZATION_KEYCHAIN_PROFILE)" \
		$@

$(TMP)/notarized.stamp.txt : $(TMP)/notarization-log.json | $$(dir $$@)
	test "$$(jq --raw-output '.status' < $<)" = "Accepted"
	date > $@

xz-$(ver).pkg : $(TMP)/xz-$(ver)-unnotarized.pkg $(TMP)/notarized.stamp.txt
	cp $< $@
	xcrun stapler staple $@

