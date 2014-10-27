ifneq ($(strip $(MAKECMDGOALS)),clean)
ifeq ($(strip $(VERSION)),)
VERSION:=$(strip $(filter V%,$(notdir $(shell pwd))))
ifeq ($(strip $(VERSION)),)
$(error Missing VERSION)
endif
endif
ifeq ($(strip $(INSTALL_BASE)),)
$(error Missing INSTALL_BASE)
endif
ifeq ($(strip $(PREFIX)),)
$(error Missing PREFIX)
endif
$(info SCRAM version:        $(VERSION))
$(info SCRAM install prefix: $(INSTALL_BASE))
$(info SCRAM install path:   $(PREFIX))
endif

.PHONY: all doc install

all: src/main/scram.pl doc

src/main/scram.pl: bin/scram
	@[ -e $@ ] || exit 0
	@[ -d $(@D) ] || mkdir $(@D) &&\
	cd $(@D) &&\
	rm -f $(@F) && ln -s ../../bin/scram $(@F) &&\
	echo ">> Generated $@"

bin/scram: bin/scram.in
	@sed -e "s|@CMS_PATH@|$(INSTALL_BASE)|g;s|@SCRAM_VERSION@|$(VERSION)|g" $< > $@ &&\
	chmod 755 $@ &&\
	echo ">> Generated $@"

doc: $(subst docs/man/,docs/man/man1/,$(subst .in,,$(wildcard docs/man/*.in)))

docs/man/man1/%.1: docs/man/%.1.in
	@echo ">> Generation man pages for '$*'" &&\
	[ -d $(@D) ] || mkdir $(@D) &&\
	nroff -man $< > $@

install: all
	@for f in `ls -d  * | grep -v Makefile | grep -v INSTALL.txt` ; do \
	  echo "Copying $$f -> $(PREFIX)/$$f" &&\
	  rm -rf $(PREFIX)/$$f &&\
	  cp -RP $$f $(PREFIX) ;\
	done ;\
	cd $(PREFIX) &&\
	rm bin/*.in docs/man/*.in
clean:
	rm -rf docs/man/man1 bin/scram src/main
