# SCRAM BUILD FLAGS

       SCRAM sets variuos flags to be used by different compilers (e.g CXX,  C
       and Fortran)

       [<class|type>_][REM_]<CXX|C|F>FLAGS
          Compilation flags for CXX/C/Fortran compilers.

       [<class|type>_][REM_]CPPFLAGS
          Pre-processor flags for pre-processing.

       [<class|type>_][REM_]CPPDEFINES
          Pre-processor macros, SCRAM adds -D for each of these flags.

       [<class|type>_][REM_]LDFLAGS
          Link flags for linking shared libraries or building executables.

       [CXX|C|F]OPTIMISEDFLAGS
          Optiomization flags for CXX/C/Fortran

       [CXX|C|F]CXXSHAREDOBJECTFLAGS
          Shared object flags for CXX/C/Fortran

       [REM_]CUDA_FLAGS
          Compilation flags for CUDA compiler.

       [REM_]CUDA_CFLAGS
          Compilation  flags  for CUDA compiler which should passes via --com-
          piler-options.

       [<class>_][REM_]<EDM|CAPABILITIES>_<CPPFLAGS|CXXFLAGS|CFLAGS>
          Compilation flags for EDM/Capabilities Plugin compilation

       [<class>_][REM_]EDM_LDFLAGS
          Link flags for EDM Plugin linking.

       [REM_]LCGDICT_LDFLAGS
          Link flags for EDM Capabilities Plugin linking.

       [<class>_][REM_]<LCG|ROOT>DICT_<CPPFLAGS|CXXFLAGS>
          Compilation flags to compile generated lcg/root dictionary files.

       LD_UNIT
          Flags used for the generation of big object file for big plugins.

       MISSING_SYMBOL_FLAGS
          Link flags used for linking to make sure there are no  missing  sym-
          bols.

       BIGOBJ_[REM_]<CPPFLAGS|CXXFLAGS|CFLAGS|FFLAGS|LDFLAGS>
          Various compilation/link flags for Big Plugins.

       GENREFLEX_ARGS
          Flags/arguments for genreflex

       GENREFLEX_GCCXMLOPT
          GCCXML options passed to genreflex

       GENREFLEX_CPPFLAGS
          Pre-processor flags pass to genreflex
