# SCRAM CONTROL FLAGS

       There  are  few  control flags which one can add in to Buildfile.xml to
       control scram build process e.g.

       <export><lib="1"/></export>
          This makes a shared library generated  form  <package>/BuildFile.xml
          linkable.

       RIVET_PLUGIN=1|0
          To  tell  SCRAM  to  generate  a  RIVET  Plugin  instead of a shared
          library. Default value is 0.

       EDM_PLUGIN=1|0
          To tell SCRAM to generate a EDM Plugin instead of a shared  library.
          Default  value  is 1 for <package>/<plugins>/BuildFile.xml and 0 for
          all otherBuildFile.xml

       ADD_SUBDIR=1|0
          To tell SCRAM to search for source files in all  sub-directories  pf
          <package>/src.   Default value is 0 i.e. scram only looks for source
          files (c, cc, cpp, ccx) in <package>/src directory

       NO_LIB_CHECKING=1|0
          To tell SCRAM to not check the generated shared  library/edm  plugin
          for missing symbols.  Default value is 0.

       LCG_DICT_HEADER=<files>
          Space  separated  list  of  classes.h  files  for  LCG dictionaries.
          Default value is classes.h

       LCG_DICT_XML=<files>
          Space separated list of classes_def.xml files for LCG  dictionaries.
          Default value is classes_def.xml

       ROOTMAP=1|0
          Generate .rootmap file too. Default value is 0

       GENREFLEX_FAILES_ON_WARNS=1|0
          To tell scram to fail on genreflex warnings. Default value is 0.

       SKIP_FILES=<files>
          Space  separated list of source files which should not be considered
          for compilation.

       INSTALL_SCRIPTS=<files>
          Space separated list of scripts which should be copied to bin/<arch>
          product store.

       NO_TESTRUN=1|0
          To  avoid  running  the  unit test via "scram build runtests".  This
          flag is only valid in <package>/test/BuildFile.xml

       TEST_RUNNER_ARGS=<options>
          Command-line arguments to be passed to the test when test is run via
          "scram   build   runtests"   This  flag  is  only  valid  in  <pack-
          age>/test/BuildFile.xml

       TEST_RUNNER_CMD=<command>
          The command to run the test via "scram build runtests" This flag  is
          only valid in <package>/test/BuildFile.xml

       SETENV=<env_var>=<value>
          This  sets  the  environment  variable before running the unit test.
          This flag is only valid in <package>/test/BuildFile.xml

       SETENV_SCRIPT=<scrpit-to-source>
          This sources the script to set environment before running  the  unit
          test.  This flag is only valid in <package>/test/BuildFile.xml

       PRE_TEST=<test>
          Tests  which should be run first before run this test.  This flag is
          only valid in <package>/test/BuildFile.xml

       DROP_DEP=<dependency>
          For Big EDM Plugins, to drop any direct or indirect dependnecy  used
          by the packages of Big Plugin.

       LLVM_PLUGIN
          Name  of the static analyzer plugin for LLVM Static Analysis. Effec-
          tive only in config/BuildFile.xml.

       LLVM_CHECKERS
          Default checkers to be enbabled for LLVM Static Analysis.  Effective
          only in config/BuildFile.xml.

       <include_path path="<dir>"/>
          To add -I<dir> during compilation. <dir> could be full path or rela-
          tive to the BuildFile.xml.

       <library name="<name>" file="<files>">[dependencies/flags]</library>
          To generate a shared library  from  a  <packages>/[plugins|test|bin]
          directory.

          By  default, SCRAM generates shared library for <package>/src direc-
          tory so no need to use <library> tag in <package>/BuildFile.xml.
          By default, all shared libraries generated  from  <packages>/plugins
          are  EMD  Plugins.   unless explicitly turned off by <flags EDM_PLU-
          GIN="0"/>

       <bin name="<name>" file="<files>">[dependencies/flags]</bin>
          To generate an executable/test executable from  a  <packages>/[plug-
          ins|test|bin] directory.

       <test        name="<name>"        command="<command-to-run>">[dependen-
       cies/flags]</test>
          To run the command for the test in <package>/test directory.

       <if<condition> name|match="[!]<regexp>"/></if<condition>>
       OR
       <if<condition> value="[!]<value>"/></if<condition>>
       OR
       <if<condition> name|match|value=="[!]<value>"/>
         <!-- contents -->
       <elif name|match|value="[!]<value>"/>
         <!-- contents -->
       <else/>
         <!-- contents -->
       </if<condition>>
          Any  flag/dependency  within  these  tags will apply if regexp/value
          match the condition. If first charactor of regexp/value is '!'  then
          flags/dependency will apply if regexp/value doe not match.

             Valid conditions are
               architecture: SCRAM_ARCH environment variable
               compiler : Default compiler from config/Self.xml
               release: SCRAM_PROJECTVERSION environment variable
               project: SCRAM_PROJECTNAME environment variable
               scram: SCRAM_VERSION environment variable
               config: SCRAM_CONFIGCHKSUM environment variable
               cxx11_abi: SCRAM_CXX11_ABI environment variable
               tool: To check for a tool (and optionally its version) e.g
                     `<iftool name="root" version="6\..="></iftool>`

             Nasted conditions blocks are allowed.

    CONTROL FLAGS (via environment)

       There are few environment flags that can control SCRAM e.g.

       USER_[BIGOBJ_][REM_]<CPPFLAGS|CXXFLAGS|CFLAGS|FFLAGS|LDFLAGS>
          Various user defined compilation/link flags.

       USER_LLVM_CHECKERS
          Used  defined extra checkers to be enabled for LLVM Static Analysis.

       SCRAM_USERLOOKUPDB=<path>
          To instruct SCRAM to  use  <path>  as  its  database  and  look  for
          projects under this directory.

       RUN_LLVM_ANALYZER_ON_ALL=yes
          To  run  llvm analyzer on generated code too. By default it does not
          run on generated code.

       BUILD_LOG=yes
          To redirect the "scram build -j n" output  to  log  files  for  each
          product.

       SCRAM_NOEDMWRITECONFIG=1
          No to run EDM Write Config script after the edmplugin build.

       SCRAM_IGNORE_PACKAGES=<packages>
          Do not build <packages>

       SCRAM_IGNORE_SUBDIRS=<sub-dirs>
          Do  not build <sub-dirs> of each package e.g. one can set it to test
          to avoid building test executables/plugins.

       SKIP_UNITTESTS=<tests>
          Do not run these <tests> when "scram  build  runtests|unittests"  is
          run.

       SCRAM_NOSYMCHECK=1
          Do not run any extra shared library missing symbols checks.

       SCRAM_TEST_RUNNER_PREFIX=<command>
          Prefix each unittest with <command> before running.
