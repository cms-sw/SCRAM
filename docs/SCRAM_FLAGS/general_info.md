# SCRAM FLAGS

       SCRAM-based projects' build rules  provided  via  cmssw-config  support
       many  compilation/control  flags.  Scope  of build/compilation flag are
       defined by the place they are defined in. e.g.

          Project level flags
             Any flag defined/provided via following are used  for  all  build
             products of the project
             - top-level config/BuildFile.xml
             -  compiler's  tools files (e.g. gcc-cxxcompiler.xml, gcc-cxxcom-
             piler.xml and gcc-f77compiler.xml)
             - via command-line USER_<flag>/SCRAM_<flag>

          Tool level flags
             Any flags defined in the tool file of an external  are  used  for
             all  the  build  products which directly or indirectly depends on
             that tool.

          Product level flags
             Any flags defined in the BuildFile.xml is used by the  product(s)
             defined in that BuildFile.xml

       Some  flags  (<class>[_REM]_<flag>)  can  be  configured based on their
       product class e.g. available classes are
          LIBRARY
             For all shared library/edm plugin/edm capabilities  plugin  prod-
             ucts
          BINARY
             For all executables.
          TEST
             For all test executables.
          TEST_LIBRARY
             For all test shared libraires executables.

       Some  flags (<type>[_REM]_<flag>) can be configured based on the SCRAM-
       based area types e.g. available area types are
          RELEASE
             Only for compilation/build in the release area environment.
          DEV
             Only for compilation/build user development area.
