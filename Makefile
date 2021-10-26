INSTALLER_SIGNING_ID ?= Developer ID Installer: Donald McCaughey
TMP ?= $(abspath tmp)

version := 5.2.5
revision := 1


.SECONDEXPANSION :


.PHONY : all
all : xz-$(version).pkg


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
	codesign --verify --strict $(TMP)/install/usr/local/bin/lzmadec
	codesign --verify --strict $(TMP)/install/usr/local/bin/lzmainfo
	codesign --verify --strict $(TMP)/install/usr/local/bin/xz
	codesign --verify --strict $(TMP)/install/usr/local/bin/xzdec
	pkgutil --check-signature xz-$(version).pkg
	spctl --assess --type install xz-$(version).pkg
	xcrun stapler validate xz-$(version).pkg


##### dist ##########

dist_sources := $(shell find dist -type f \! -name .DS_Store)

$(TMP)/install/usr/local/bin/xz : $(TMP)/build/src/xz/xz | $(TMP)/install
	cd $(TMP)/build && $(MAKE) DESTDIR=$(TMP)/install install

$(TMP)/build/src/xz/xz : $(TMP)/build/config.status $(dist_sources)
	cd $(TMP)/build && $(MAKE)

$(TMP)/build/config.status : dist/configure | $(TMP)/build
	cd $(TMP)/build && sh $(abspath $<)

$(TMP)/build \
$(TMP)/install :
	mkdir -p $@


##### pkg ##########

$(TMP)/xz.pkg : \
		$(TMP)/install/etc/paths.d/xz.path \
		$(TMP)/install/usr/local/bin/uninstall-xz \
		$(TMP)/install/usr/local/bin/xz
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
	printf 'macOS Version: %s\n' "$(macos)" >> $@
	printf 'Xcode Version: %s\n' "$(xcode)" >> $@
	printf 'Tag Version: v%s-r%s\n' "$(version)" "$(revision)" >> $@
	printf 'Release Title: xz %s for macOS rev %s\n' "$(version)" "$(revision)" >> $@
	printf 'Description: A signed macOS installer package for `xz` %s.\n' "$(version)" >> $@

$(TMP)/distribution.xml \
$(TMP)/resources/welcome.html : $(TMP)/% : % | $$(dir $$@)
	sed \
		-e s/{{date}}/$(date)/g \
		-e s/{{macos}}/$(macos)/g \
		-e s/{{revision}}/$(revision)/g \
		-e s/{{version}}/$(version)/g \
		-e s/{{xcode}}/$(xcode)/g \
		$< > $@

$(TMP)/resources/background.png \
$(TMP)/resources/license.html : $(TMP)/% : % | $(TMP)/resources
	cp $< $@

$(TMP) \
$(TMP)/resources :
	mkdir -p $@

