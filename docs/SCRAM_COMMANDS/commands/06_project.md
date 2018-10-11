# project

```bash
    project  [options]  <-boot  bootstrap_file>  | <project_name version> |
```

       <release_path>
          Creates  a  project  developer  area  based  on  a release area or a
          release area using the project definition from the <bootstrap_file>.
          You can find the available releases by running 'scram list' command.

          OPTIONS

          -d, --dir <path>
             Indicate a project installation area into which the  new  project
             area should appear. Default is the current working directory.

          -f, --force
             Force  creation of developer area without checking for production
             architecture  and  deprecated  release  information.  This  avoid
             accessing releases information via internet.

          -l, --log
             See the detail log message while creating a dev area.

          -n, --name <name>
             Specify  the  name of the SCRAM-base development area you wish to
             create. By default <version> is used.

          -s, --symlinks
             Creates symlinks  for  various  product  build  directories  e.g.
             lib/bin/tmp. You need to have ~/.scramrc/symlinks file to config-
             ure the symlink creation e.g. something like the following in the
             ~/.scramrc/symlinks file

             lib:/tmp/$(USER)/path
             tmp:/tmp/$(USER)/path

             will create

             /tmp/$(USER)/path/lib.<dummyname> -> $(LOCALTOP)/lib
             /tmp/$(USER)/path/tmp.<dummyname> -> $(LOCALTOP/tmp

             You  can  use $(SCRAM_PROJECTNAME) and $(SCRAM_PROJECTVERSION) in
             the .scramrc/symlinks file to create separate tmp areas for  dif-
             ferent projects.

          -b, --boot <bootstrap_file>
             Creates a release area using the bootstrap file <bootstrap_file>.

          [<project_name>] <version>
             Creates a developer area based on an  already  available  release
             <version>.

          <release_path>
             Creates a developer area based on <release_path> release area.