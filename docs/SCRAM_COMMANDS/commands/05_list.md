# list

```bash
    list [options] [<project_name>] [<version>]
```

          Show available SCRAM-based projects for the selected SCRAM_ARCH.

          OPTIONS

          -a, --all
             Show projects for all available architectures.

          -c --compact
             Show project list in compact format. Output format of  each  line
             will be
                ProjectName Version ReleaseInstallPath

          -e, --exists
             Show  only  projects  will actually looks OK. Note, this might be
             slow on distributed  filesystems  as  SCRAM  has  to  check  each
             installed project and its version.

          <project_name>
             Optional:  Name of the project for which SCRAM should display the
             available versions.

          <version>
             Optional: To Show only those  installed  versions  which  contain
             <version>