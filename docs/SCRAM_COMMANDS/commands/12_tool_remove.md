# tool remove

```bash
    tool remove <toolname>
```


          Makes the tool <toolname> unavailable. SCRAM moves the tools defini-
          tion  file   from   config/toolbox/$SCRAM_ARCH/tools/selected/<tool-
          name>.xml  to  config/toolbox/$SCRAM_ARCH/tools/available directory.
          So if one needs to select this tool again then just run 'scram setup
          <toolname>' command.