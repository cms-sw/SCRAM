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

.PHONY: all install

all: src/main/scram.pl

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

install: all
	@for f in `ls -d  * | grep -v Makefile | grep -v INSTALL.txt` ; do \
	  echo "Copying $$f -> $(PREFIX)/$$f" &&\
	  rm -rf $(PREFIX)/$$f &&\
	  cp -RP $$f $(PREFIX) ;\
	done ;\
	cd $(PREFIX) &&\
	rm bin/*.in
clean:
	rm -rf bin/scram src/main
