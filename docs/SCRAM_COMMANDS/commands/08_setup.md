# setup

```bash
    setup [<toolname>|<toolfile>.xml]
```

          Setup/add  an  external tool to be used by the project. All selected
          tools        definitions        exists        in        config/tool-
          box/$SCRAM_ARCH/tools/selected  directory  in  your project area. In
          order to change the tool definition, modify  the  corresponding  xml
          toolfile and run scram setup <tool> command.

          This command needs to be run from a release or developer area.

          OPTIONS

          <toolname>
             Name of the external tool which is already by the scram. A corre-
             sponding  <toolname>.xml   should   exists   under   config/tool-
             box/$SCRAM_ARCH/tools.

          <toolfile>.xml
             Full   path   of   the  toolfile.  SCRAM  will  make  a  copy  of
             <toolfile>.xml in to config/toolbox/$SCRAM_ARCH/tools for  future
             use.
