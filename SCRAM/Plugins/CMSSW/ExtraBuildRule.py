from os import environ
from re import compile

re_check = {
    "_mic_": compile(r"_mic_"),
    "_ASAN_": compile(r"_ASAN_"),
    "_UBSAN_": compile(r"_UBSAN_"),
    "_TSAN_": compile(r"_TSAN_")
}


class ExtraBuildRule:

    def __init__(self, template):
        self.template = template

    def isPublic(self, klass):
        return klass in ["LIBRARY", "BIGPRODUCT"]

    def Project(self):
        common = self.template
        fh = common.filehandle()
        common.symlinkPythonDirectory(1)
        common.autoGenerateClassesH(1)
        #$self->addPluginSupport(plugin-type,plugin-flag,plugin-refresh-cmd,dir-regexp-for-default-plugins,
        #   plugin-store-variable,plugin-cache-file,plugin-name-exp,no-copy-shared-lib)
        common.addPluginSupport("edm", "EDM_PLUGIN", "edmPluginRefresh", '\/plugins$', "SCRAMSTORENAME_LIB",
                                ".edmplugincache", '$name="${name}.edmplugin"', "yes")
        common.addPluginSupport("rivet", "RIVET_PLUGIN", "RivetPluginRefresh", '\/plugins$', "SCRAMSTORENAME_LIB",
                                ".rivetcache", '$name="Rivet${name}.\$(SHAREDSUFFIX)"', "yes")
        common.addPluginSupport("dd4hep", "DD4HEP_PLUGIN", "DD4HepPluginRefresh", '\/nplugins$', "SCRAMSTORENAME_LIB",
                                ".dd4hepcache", '$name="lib${name}.components"', "yes")
        common.setProjectDefaultPluginType("edm")
        common.setLCGCapabilitiesPluginType("edm")
        common.addSymLinks("src/LCG include/LCG 1 . ''")
        fh.write(
            "COND_SERIALIZATION:=$(SCRAM_SOURCEDIR)/CondFormats/Serialization/python/condformats_serialization_generate.py\n")
        if re_check["_mic_"].match(environ["SCRAM_ARCH"]):
            fh.write("EDM_WRITE_CONFIG:=true\n"
                     "EDM_CHECK_CLASS_VERSION:=true\n"
                     "EDM_CHECK_CLASS_TRANSIENTS=true\n")
        else:
            fh.write(
                "EDM_WRITE_CONFIG:=edmWriteConfigs\n"
                "EDM_CHECK_CLASS_VERSION:=$(SCRAM_SOURCEDIR)/FWCore/Utilities/scripts/edmCheckClassVersion\n"
                "EDM_CHECK_CLASS_TRANSIENTS=$(SCRAM_SOURCEDIR)/FWCore/Utilities/scripts/edmCheckClassTransients\n"
            )
            if re_check["_ASAN_"].match(environ["SCRAM_PROJECTVERSION"]):
                fh.write("EDM_TOOLS_PREFIX:=LD_PRELOAD=$(GCC_CXXCOMPILER_BASE)/lib64/libasan.so\n")
            if re_check["_UBSAN_"].match(environ["SCRAM_PROJECTVERSION"]):
                fh.write("EDM_TOOLS_PREFIX:=LD_PRELOAD=$(GCC_CXXCOMPILER_BASE)/lib64/libubsan.so\n")
            if re_check["_TSAN_"].match(environ["SCRAM_PROJECTVERSION"]):
                fh.write("EDM_TOOLS_PREFIX:=LD_PRELOAD=$(GCC_CXXCOMPILER_BASE)/lib64/libtsan.so\n")

        fh.write("""COMPILE_PYTHON_SCRIPTS:=yes
self_EX_FLAGS_CPPDEFINES+=-DCMSSW_GIT_HASH='"$(CMSSW_GIT_HASH)"' -DPROJECT_NAME='"$(SCRAM_PROJECTNAME)"' -DPROJECT_VERSION='"$(SCRAM_PROJECTVERSION)"'
ifeq ($(strip $(RELEASETOP)$(IS_PATCH)),yes)
CMSSW_SEARCH_PATH:=${CMSSW_SEARCH_PATH}:$($(SCRAM_PROJECTNAME)_BASE_FULL_RELEASE)/$(SCRAM_SOURCEDIR)
endif
""")

        ######################################################################
        # Dependencies: run ignominy analysis for release documentation
        fh.write(""".PHONY: dependencies
dependencies:
\t@cd $(LOCALTOP); \\
\tmkdir -p $(LOCALTOP)/doc/deps/$(SCRAM_ARCH); \\
\tcd $(LOCALTOP)/doc/deps/$(SCRAM_ARCH); \\
\tignominy -f -i -A -g all $(LOCALTOP)
""")

        ######################################################################
        # Documentation targets. Note- must be lower case otherwise conflict with rules
        # for dirs which have the same name:
        fh.write(""".PHONY: userguide referencemanual doc doxygen
doc: referencemanual
\t@echo "Documentation/release notes built for $(SCRAM_PROJECTNAME) v$(SCRAM_PROJECTVERSION)"
userguide:
\t@if [ -f $(LOCALTOP)/src/Documentation/UserGuide/scripts/makedoc ]; then \\
\t  doctop=$(LOCALTOP); \\
\telse \\
\t  doctop=$(RELEASETOP); \\
\tfi; \\
\tcd $$doctop/src; \\
\tDocumentation/UserGuide/scripts/makedoc $(LOCALTOP)/src $(LOCALTOP)/doc/UserGuide $(RELEASETOP)/src
referencemanual:
\t@cd $(LOCALTOP)/src/Documentation/ReferenceManualScripts/config; \\
\tsed -e 's|@PROJ_NAME@|$(SCRAM_PROJECTNAME)|g' \\
\t-e 's|@PROJ_VERS@|$(SCRAM_PROJECTVERSION)|g' \\
\t-e 's|@CMSSW_BASE@|$(LOCALTOP)|g' \\
\t-e 's|@INC_PATH@|$(LOCALTOP)/src|g' \\
\tdoxyfile.conf.in > doxyfile.conf; \\
\tcd $(LOCALTOP); \\
\tls -d src/*/*/doc/*.doc | sed 's|(.*).doc|mv "&" "\\1.dox"|' | /bin/sh; \\
\tif [ `expr substr $(SCRAM_PROJECTVERSION) 1 1` = "2" ]; then \\
\t  ./config/fixdocs.sh $(SCRAM_PROJECTNAME)"_"$(SCRAM_PROJECTVERSION); \\
\telse \\
\t  ./config/fixdocs.sh $(SCRAM_PROJECTVERSION); \\
\tfi; \\
\tls -d src/*/*/doc/*.doy |  sed 's/(.*).doy/sed "s|@PROJ_VERS@|$(SCRAM_PROJECTVERSION)|g" "&" > "\\1.doc"/' | /bin/sh; \\
\trm -rf src/*/*/doc/*.doy; \\
\tcd $(LOCALTOP)/src/Documentation/ReferenceManualScripts/config; \\
\tdoxygen doxyfile.conf; \\
\tcd $(LOCALTOP); \\
\tls -d src/*/*/doc/*.dox | sed 's|(.*).dox|mv "&" "\\1.doc"|' | /bin/sh;
doxygen:
\t@rm -rf $(LOCALTOP)/$(WORKINGDIR)/doxygen &&\\
\tmkdir -p $(LOCALTOP)/$(WORKINGDIR)/doxygen &&\\
\tscriptdir=$(LOCALTOP)/$(SCRAM_SOURCEDIR)/Documentation/ReferenceManualScripts/doxygen/utils &&\\
\t[ -d $$scriptdir ] || scriptdir=$(RELEASETOP)/$(SCRAM_SOURCEDIR)/Documentation/ReferenceManualScripts/doxygen/utils &&\\
\tcd $$scriptdir/doxygen &&\\
\tcp -t $(LOCALTOP)/$(WORKINGDIR)/doxygen cfgfile footer.html header.html doxygen.css DoxygenLayout.xml doxygen ../../script_launcher.sh &&\\
\tcd $(LOCALTOP)/$(WORKINGDIR)/doxygen &&\\
\tchmod +rwx doxygen script_launcher.sh &&\\
\tsed -e 's|@CMSSW_BASE@|$(LOCALTOP)|g' cfgfile > cfgfile.conf &&\\
\t./doxygen cfgfile.conf &&\\
\t./script_launcher.sh $(SCRAM_PROJECTVERSION) $$scriptdir $(LOCALTOP) &&\\
\techo "Reference Manual is generated."
.PHONY: gindices
gindices:
\t@cd $(LOCALTOP); \\
\trm -rf  .glimpse_*; mkdir .glimpse_full; \\
\tfind $(LOCALTOP)/src $(LOCALTOP)/cfipython/$(SCRAM_ARCH) -follow -mindepth 3 -type f | grep -v '.pyc$$' | sed 's|^./||' | glimpseindex -F -H .glimpse_full; \\
\tchmod 0644 .glimpse_full/.glimpse_*; \\
\tmv .glimpse_full/.glimpse_filenames .; \\
\tfor  x in `ls -A1 .glimpse_full` ; do \\
\t  ln -s .glimpse_full/$$x $$x; \\
\tdone; \\
\tcp .glimpse_filenames .glimpse_full/.glimpse_filenames; \\
\tsed -i -e "s|$(LOCALTOP)/||" .glimpse_filenames
.PHONY: productmap
productmap:
\t@cd $(LOCALTOP); \\
\tmkdir -p src; rm -f src/ReleaseProducts.list; echo ">> Generating Product Map in src/ReleaseProducts.list.";\\
\t(RelProducts.pl $(LOCALTOP) > $(LOCALTOP)/src/ReleaseProducts.list || exit 0)
.PHONY: depscheck
depscheck:
\t@ReleaseDepsChecks.pl --detail
""")


    def Extra_templateI(self):
        pass
