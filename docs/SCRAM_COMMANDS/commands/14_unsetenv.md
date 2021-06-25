# unsetenv

```bash
    unsetenv -csh|-sh|-win
```

          Shows  the  list of shell commands needed to unset the runtime envi-
          ronment set previously by 'scram runtime command'. You can eval  the
          output of this command to cleanup your previously set scram environ-
          ment e.g.  eval 'scram unsetenv -sh'

          OPTIONS

          -csh
             Show unset commands for csh/tcsh shell.

          -sh
             Show unset commands for sh/bash/zsh shell.

          -win
             Show unset commands for cygwin.