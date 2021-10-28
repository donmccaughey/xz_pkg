APP_SIGNING_ID ?= Developer ID Application: Donald McCaughey
INSTALLER_SIGNING_ID ?= Developer ID Installer: Donald McCaughey
NOTARIZATION_KEYCHAIN_PROFILE ?= Donald McCaughey
TMP ?= $(abspath tmp)

version := 5.2.5
revision := 1
archs := arm64 x86_64


.SECONDEXPANSION :


.PHONY : all
all : xz-$(version).pkg


.PHONY : notarize
notarize : $(TMP)/stapled.stamp.txt


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
	codesign --verify --strict $(TMP)/install/usr/local/bin/lzmadec
	codesign --verify --strict $(TMP)/install/usr/local/bin/lzmainfo
	codesign --verify --strict $(TMP)/install/usr/local/bin/xz
	codesign --verify --strict $(TMP)/install/usr/local/bin/xzdec
	codesign --verify --strict $(TMP)/install/usr/local/lib/liblzma.a
	codesign --verify --strict $(TMP)/install/usr/local/lib/liblzma.5.dylib
	pkgutil --check-signature xz-$(version).pkg
	spctl --assess --type install xz-$(version).pkg
	xcrun stapler validate xz-$(version).pkg


##### compilation flags ##########

arch_flags = $(patsubst %,-arch %,$(archs))

CFLAGS += $(arch_flags)


##### dist ##########

dist_sources := $(shell find dist -type f \! -name .DS_Store)

$(TMP)/install/usr/local/bin/xz : $(TMP)/build/src/xz/xz | $(TMP)/install
	cd $(TMP)/build && $(MAKE) DESTDIR=$(TMP)/install install

$(TMP)/build/src/xz/xz : $(TMP)/build/config.status $(dist_sources)
	cd $(TMP)/build && $(MAKE)

$(TMP)/build/config.status : dist/configure | $(TMP)/build
	cd $(TMP)/build && sh $(abspath $<) CFLAGS='$(CFLAGS)'

$(TMP)/build \
$(TMP)/install :
	mkdir -p $@


##### pkg ##########

# sign executable

$(TMP)/lzmadec-signed.stamp.txt :  $(TMP)/install/usr/local/bin/lzmadec | $$(dir $$@)
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$<
	date > $@

$(TMP)/lzmainfo-signed.stamp.txt :  $(TMP)/install/usr/local/bin/lzmainfo | $$(dir $$@)
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$<
	date > $@

$(TMP)/xz-signed.stamp.txt :  $(TMP)/install/usr/local/bin/xz | $$(dir $$@)
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$<
	date > $@

$(TMP)/xzdec-signed.stamp.txt :  $(TMP)/install/usr/local/bin/xzdec | $$(dir $$@)
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$<
	date > $@

$(TMP)/liblzma.a-signed.stamp.txt :  $(TMP)/install/usr/local/lib/liblzma.a | $$(dir $$@)
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$<
	date > $@

$(TMP)/liblzma.5.dylib-signed.stamp.txt :  $(TMP)/install/usr/local/lib/liblzma.5.dylib | $$(dir $$@)
	xcrun codesign \
		--sign "$(APP_SIGNING_ID)" \
		--options runtime \
		$<
	date > $@

$(TMP)/xz.pkg : \
		$(TMP)/install/etc/paths.d/xz.path \
		$(TMP)/install/usr/local/bin/uninstall-xz \
		$(TMP)/install/usr/local/bin/lzmadec \
		$(TMP)/install/usr/local/bin/lzmainfo \
		$(TMP)/install/usr/local/bin/xz \
		$(TMP)/install/usr/local/bin/xzdec \
		$(TMP)/lzmadec-signed.stamp.txt \
		$(TMP)/lzmainfo-signed.stamp.txt \
		$(TMP)/xz-signed.stamp.txt \
		$(TMP)/xzdec-signed.stamp.txt \
		$(TMP)/liblzma.a-signed.stamp.txt \
		$(TMP)/liblzma.5.dylib-signed.stamp.txt
	pkgbuild \
		--root $(TMP)/install \
		--identifier cc.donm.pkg.xz \
		--ownership recommended \
		--version $(version) \
		$@

$(TMP)/install/etc/paths.d/xz.path : xz.path | $$(dir $$@)
	cp $< $@

$(TMP)/install/usr/local/bin/uninstall-xz : \
		uninstall-xz \
		$(TMP)/install/usr/local/bin/xz \
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
 
xz-$(version).pkg : \
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
	printf 'Tag Version: v%s-r%s\n' "$(version)" "$(revision)" >> $@
	printf 'APP_SIGNING_ID: %s\n' "$(APP_SIGNING_ID)" >> $@
	printf 'INSTALLER_SIGNING_ID: %s\n' "$(INSTALLER_SIGNING_ID)" >> $@
	printf 'NOTARIZATION_KEYCHAIN_PROFILE: %s\n' "$(NOTARIZATION_KEYCHAIN_PROFILE)" >> $@
	printf 'TMP directory: %s\n' "$(TMP)" >> $@
	printf 'CFLAGS: %s\n' "$(CFLAGS)" >> $@
	printf 'Release Title: xz %s for macOS rev %s\n' "$(version)" "$(revision)" >> $@
	printf 'Description: A signed macOS installer package for `xz` %s.\n' "$(version)" >> $@

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

$(TMP)/submit-log.json : xz-$(version).pkg | $$(dir $$@)
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

$(TMP)/stapled.stamp.txt : xz-$(version).pkg $(TMP)/notarized.stamp.txt
	xcrun stapler staple $<
	date > $@

