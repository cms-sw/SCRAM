#____________________________________________________________________ 
# File: Helper.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-19 13:56:50+0200
# Revision: $Id: Helper.pm,v 1.20.2.3 2008/02/19 15:06:46 muzaffar Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------

=head1 NAME

Helper - A package which provides each command with a helper function.
   
=head1 METHODS

=over

=cut

package SCRAM::Helper;
require 5.004;

use Exporter;

@ISA=qw(Exporter);
@EXPORT_OK=qw( );

=item   C<new()>

Create a new Helper object. This is done once when the SCRAM::SCRAM object is created.

=cut

sub new()
   {
   ###############################################################
   # new                                                         #
   ###############################################################
   # modified : Thu Oct 23 16:15:52 2003 / SFA                   #
   # params   :                                                  #
   #          :                                                  #
   # function :                                                  #
   #          :                                                  #
   ###############################################################  
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self={};
   
   bless $self,$class;
   
   return $self;
   }

=item   C<help($command)>

Execute the helper function for the command $command.
   
=cut

sub help()
   {
   my $self=shift;
   my ($helpcmd)=@_;
   
   my $help.= $self->helpheader($helpcmd);
   print ($help.= &{$helpcmd});
   }

=item   C<helpheader($command)>

Print the help header (just a string). Called only by help().
   
=cut

sub helpheader($)
   {
   my $self=shift;
   my $header=shift;
   
   $hd.="*********************************************************************************\n";
   $hd.="SCRAM HELP ------------ $header\n";
   $hd.="*********************************************************************************\n";
   return $hd;
   }

sub version()
   {
   my $self=shift;
   my $help;

   $help.="Description:\n";
   $help.="\n";
   $help.="\tthis command will simply show the current version number.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram version [-h]$::normal\n";

   $help.="\n";
   
   return $help;
   }

sub arch()
   {
   my $self=shift;
   my $help;

   $help.="Description:\n";
   $help.="\n";
   $help.="\tPrint out the architecture flag for the current machine.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram arch$::normal\n";
   $help.="or\n";
   $help.="$::bold";
   $help.="\tscram --arch <architecture>$::normal\n\nto set the architecture to that specified.\n";
   $help.="\n";

   return $help;
   }

sub runtime()
   {
   my $self=shift;
   my $help;
   
   $help.="Description:\n";
   $help.="\n";
   $help.="\tPrint the runtime environment for the current development area\n";
   $help.="\tin csh, sh or Windows flavours. \n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="\t$::bold scram runtime [-csh|-sh|-win] $::normal\n";
   $help.="\t$::bold scram runtime [-csh|-sh|-win] --dump <filename> $::normal\n";
   $help.="\n";
   $help.="** Examples **\n";
   $help.="\n";
   $help.="Set up to include the project runtime settings\n";
   $help.="in the current TCSH shell environment:-\n";
   $help.="$::bold\n";
   $help.="\teval `scram runtime -csh` $::normal\n";
   $help.="\n";
   $help.="Set up to include the project runtime settings\n";
   $help.="in a BASH/SH environment:-\n";
   $help.="$::bold\n";
   $help.="\teval `scram runtime -sh` $::normal\n";
   $help.="\n";
   $help.="To dump this environment to a file which can be sourced later, use\n";
   $help.="\n";
   $help.="\t$::bold scram runtime -sh --dump env.sh $::normal\n";
   $help.="\n";

   return $help;
   }

sub list()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tList the available projects and versions installed in the\n";
   $help.="\tlocal SCRAM database (see \"scram install help\").\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram list [-c] [-h] [<projectname>]$::normal\n";
   $help.="\n";
   $help.="Use the -c option to list the available projects and versions installed in the local\n";
   $help.="SCRAM database without fancy formatting or header strings.\n";
   $help.="The project name, version and installation directory are printed on STDOUT, separated\n";
   $help.="by spaces for use in scripts.\n\n";
   
   return $help;
   }

sub db()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   
   $help.="\tSCRAM database administration command.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram db [-h] -s|<-l scramdb>|-u <scramdb>  $::normal\n";
   $help.="\n";
   $help.="Valid subcommands are:\n";
   $help.="\n"; 
   $help.="-l|--link\n"; 
   $help.="\tMake available an additional database for project and\n";
   $help.="\tlist operations, e.g.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram db --link $::normal /a/directory/path/project.lookup\n";
   $help.="\n";
   $help.="-u|--unlink\n"; 
   $help.="\tRemove a database from the link list. Note this does\n";
   $help.="\tnot remove the database, just the link to it in SCRAM.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram db --unlink $::normal /a/directory/path/project.lookup\n";
   $help.="\n";
   $help.="-s|--show\n"; 
   $help.="\tList the databases that are linked in.\n";
   $help.="\n";

   return $help;
   }

sub install()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tInstalled this project so that other user can create developer area against it.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram install [-f]$::normal\n";
   $help.="\n";
   $help.="The -f flag can be used to force an installation of a project, overwriting any entries\n";
   $help.="with the same project name and version (useful in batch processing).\n";
   $help.="\n";

   return $help;
   }

sub remove()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tRemove a project entry from SCRAM database file (\"project.lookup\").\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram remove [-f] <projectname> <projectversion>$::normal\n";
   $help.="\n";   
   $help.="The -f flag can be used to force removal of a project, not prompting the user for\n";
   $help.="confirmation (useful in batch processing).\n";
   $help.="\n";

   return $help;
   }

sub project()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tSet up a new project development area or update an existing one. A new area will appear in the\n";
   $help.="\tcurrent working directory by default.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram project [-l] [-s] [-d <area>] [-n <dir>] [-f <tools.conf>] <projecturl>|[<projectname> <projectversion>]$::normal\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram project --update [<projectversion>]$::normal\n";
   $help.="\n";
   $help.="Options:\n";
   $help.="\n";
   $help.="<projecturl>:\n";
   $help.="\tThe URL of a SCRAM bootstrap file.\n";
   $help.="\n";
   $help.="<projectversion>:\n";
   $help.="\tOnly for use with a database label.\n";
   $help.="\n";
   $help.="-d <area>:\n";
   $help.="\tIndicate a project installation area into which the new\n";
   $help.="\tproject area should appear. Default is the current working\n";
   $help.="\tdirectory.\n";
   $help.="\n";
   $help.="-n <dir>:\n";
   $help.="\tSpecify the name of the SCRAM development area you wish to\n"; 
   $help.="\tcreate.\n";
   $help.="\n";
   $help.="\n";
   $help.="$::bold";
   $help.="database label$::normal\tLabels can be assigned to installed releases of projects for easy\n";
   $help.="access (See \"scram install\" command). If you specify a label you must also specify\n";
   $help.="a project version. This command is normally used to create cloned developer areas.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="-b <file>$::normal\tA bootstrap file on an accessible file system. This command would\n";
   $help.="be used to create a project area from scratch on a laptop.\n";
   $help.="\n";
   $help.="** Examples **\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram project XX XX_9_0$::normal\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram project -b ~/myprojects/projecta/config/boot $::normal\n";
   $help.="\n";
   $help.="\n";
   $help.="Use the \"-f\" flag followed by a valid filename to allow auto setup to proceed.\n";
   $help.="\n";			      
   $help.="Use \"-l\" to see the detail log message when creating a dev area.\n";
   $help.="\n";
   $help.="Use \"-s\" to create symlinks for lib/bin/tmp area. You need to have a ~/.scramrc/symlinks\n";
   $help.="file which could have something like\n";
   $help.="\t##### START OF:~/.scramrc/symlinks ########\n";
   $help.="\t#FORMAT:link:/path \n";
   $help.="\tlib:/tmp/\$(USER)/\$(SCRAM_PROJECTNAME)/\$(SCRAM_PROJECTVERSION)\n";
   $help.="\ttmp:/tmp/\$(USER)/\$(SCRAM_PROJECTNAME)/\$(SCRAM_PROJECTVERSION)\n";
   $help.="\t##### END OF:~/.scramrc/symlinks ########\n";
   $help.="and scram will create\n";
   $help.="/tmp/\$(USER)/\$(SCRAM_PROJECTNAME)/\$(SCRAM_PROJECTVERSION)/lib.<dummyname> -> \$(LOCALTOP)/lib\n";
   $help.="/tmp/\$(USER)/\$(SCRAM_PROJECTNAME)/\$(SCRAM_PROJECTVERSION)/tmp.<dummyname> -> \$(LOCALTOP/tmp\n";
   $help.="\n";
   $help.="An existing developer area for a project can be updated to a more recent version of\n";
   $help.="the SAME project by running \"scram project -update <VERSION>\" in the developer area.\n";
   $help.="If no VERSION is given, the command is considered like a query and will return a list\n";
   $help.="of project versions which are compatible with the configuration of the current area.\n";
   $help.="\n";
   $help.="A subsequent invocation of the command with a valid VERSION will then update the area\n";
   $help.="to that version.\n";
   $help.="\n";
   
   return $help;
   }

sub setup()
   {
   my $self=shift;
   my $help;
   
   $help.="Description:\n";
   $help.="\n";			      
   $help.="\tAllows installation/re-installation of a new/existing tool/external package into an\n";
   $help.="\talready existing development area. If no toolname/toolfile is specified,\n";
   $help.="\tthe complete installation process is initiated.\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram setup [-i] [-h] [-f tools.conf] [<toolname>|<toolfile>]$::normal\n";
   $help.="\n";			      
   $help.="toolname:\n";
   $help.="\tThe name of the tool to be set up. There must be a tool file under\n";
   $help.="config/<arch>/tools/[selected|available]/<toolname>.xml\n";
   $help.="\n";			      
   $help.="toolfile:\n";
   $help.="\tThis is a toolfile document describing the tool being set up.\n";
   $help.="\n";
   $help.="The -i option turns off the automatic search mechanism allowing for more\n";
   $help.="user interaction during setup.\n";
   $help.="\n";			      
   $help.="The -f option allows the user to specify a tools file. This file contains\n";
   $help.="values to be used for settings of the tool.\n";
   $help.="\n";			      

   return $help;
   }

sub tool()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tManage the tools in the current SCRAM project area.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram tool <subcommand> $::normal\n";
   $help.="\n";
   $help.="where valid tool subcommands and arguments are:\n";
   $help.="\n";
   $help.="$::bold";
   $help.="list $::normal\n";
   $help.="\tList of configured tools available in the current SCRAM area.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="info <tool_name> $::normal\n";
   $help.="\tPrint out information on the specified tool in the current area.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="tag <tool_name> <tag_name> $::normal\n";
   $help.="\tPrint out the value of a variable (tag) for the specified tool in the\n";
   $help.="\tcurrent area configuration. If no tag name is given, then all known tag\n";
   $help.="\tnames are printed to STDOUT.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="remove <tool_name> $::normal\n";
   $help.="        Remove the specified tool from the current project area.\n";
   $help.="\n";
   
   return $help;
   }

sub build()
   {
   my $self=shift;
   my $help;

   $help.="Description:\n";
   $help.="\n";
   $help.="\tRun compilation in the current project area.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram [--debug] build [options] [makeopts] <TARGET> $::normal\n";
   $help.="\n";
   $help.="--debug can be used to turn on full SCRAM debug output.\n\n";
   $help.="The following long options are supported (can be abbreviated to '-x'):\n\n";
   $help.="--help               show this help message.\n";
   $help.="--verbose            verbose mode. Show cache scan progress and compilation cmds (will\n";
   $help.="                     automatically set SCRAM_BUILDVERBOSE to TRUE)\n";
   $help.="--testrun            do everything except run gmake.\n";
   $help.="--reset              reset the project caches and rescan/rebuild.\n";
   $help.="--fast               skip checking the cache and go straight to building.\n";
   $help.="--convertxml         convert any non-xml BuildFile in to BuildFile.xml.\n";
   $help.="\n";
   $help.="Make option flags can be passed to gmake at build-time: the supported options are\n";
   $help.="\n -n               print the commands that would be executed but do not run them\n";
   $help.=" --printdir       print the working directory before and after entering it\n";
   $help.=" --printdb        print the data base of rules after scanning makefiles, then build as normal\n";
   $help.=" -j <n>           the number of processes to run simultaneously\n";
   $help.=" -k               continue for as long as possible after an error\n";
   $help.=" -s               do not print any output\n";                
   $help.=" -d               run gmake in debug mode\n\n";      
   $help.="\n";

   return $help;
   }

## 
1;

=back

=head1 AUTHOR/MAINTAINER

Shaun ASHBY 

=cut

