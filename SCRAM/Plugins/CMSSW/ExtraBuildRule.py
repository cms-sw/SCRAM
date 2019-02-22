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
        # fh = common.filehandle()  # TODo
        fh = open("todo")
        common.symlinkPythonDirectory(1)
        common.autoGenerateClassesH(1)
        #   #$self->addPluginSupport(plugin-type,plugin-flag,plugin-refresh-cmd,dir-regexp-for-default-plugins,
        # plugin-store-variable,plugin-cache-file,plugin-name-exp,no-copy-shared-lib)
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

    def Extra_templateI(self):
        pass
