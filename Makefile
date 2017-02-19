TMP ?= $(abspath tmp)

version := 5.2.3
installer_version := 3
configure_flags := 

.SECONDEXPANSION :

.PHONY : all
all : xz-$(version).pkg

.PHONY : clean
clean :
	-rm -f xz-$(version).pkg
	-rm -rf $(TMP)


##### dist ##########
dist_sources := $(shell find dist -type f \! -name .DS_Store)

$(TMP)/install/usr/local/bin/xz : $(TMP)/build/src/xz/xz | $(TMP)/install
	cd $(TMP)/build && $(MAKE) DESTDIR=$(TMP)/install install

$(TMP)/build/src/xz/xz : $(TMP)/build/config.status $(dist_sources)
	cd $(TMP)/build && $(MAKE)

$(TMP)/build/config.status : dist/configure | $(TMP)/build
	cd $(TMP)/build && sh $(abspath dist/configure) $(configure_flags)

$(TMP)/build \
$(TMP)/install :
	mkdir -p $@


##### pkg ##########

$(TMP)/xz-$(version).pkg : \
		Makefile \
		$(TMP)/install/usr/local/bin/xz \
		$(TMP)/install/etc/paths.d/xz.path
	pkgbuild \
		--root $(TMP)/install \
		--identifier com.ablepear.xz \
		--ownership recommended \
		--version $(version) \
		$@

$(TMP)/install/etc/paths.d/xz.path : xz.path  $(TMP)/install/etc/paths.d
	cp $< $@

$(TMP)/install/etc/paths.d :
	mkdir -p $@


##### product ##########

xz-$(version).pkg : \
		Makefile \
		$(TMP)/xz-$(version).pkg \
		$(TMP)/distribution.xml \
		$(TMP)/resources/background.png \
		$(TMP)/resources/license.html \
		$(TMP)/resources/welcome.html
	productbuild \
		--distribution $(TMP)/distribution.xml \
		--resources $(TMP)/resources \
		--package-path $(TMP) \
		--version $(installer_version) \
		--sign 'Able Pear Software Incorporated' \
		$@

$(TMP)/distribution.xml \
$(TMP)/resources/welcome.html : $(TMP)/% : % Makefile | $$(dir $$@)
	sed -e s/{{version}}/$(version)/g $< > $@

$(TMP)/resources/background.png \
$(TMP)/resources/license.html : $(TMP)/% : % | $(TMP)/resources
	cp $< $@

$(TMP) \
$(TMP)/resources :
	mkdir -p $@

