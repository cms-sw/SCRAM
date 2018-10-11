# runtime

```bash
    runtime -csh|-sh|-win [--dump <file>]
```

          Shows  the list of shell commands needed to set the runtime environ-
          ment for the release. This command needs to be run from a release or
          developer  area.  You can eval the output of this command to set the
          runtime environment e.g.  eval 'scram runtime -sh'

          OPTIONS

          -csh
             Show runtime commands for csh/tcsh shell.

          -sh
             Show runtime commands for sh/bash/zsh shell.

          -win
             Show runtime commands for cygwin.

          --dump <file>
             Optional: Save the  runtime  environment  in  a  <file>  for  the
             selected shell.