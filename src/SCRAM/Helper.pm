#____________________________________________________________________ 
# File: Helper.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-19 13:56:50+0200
# Revision: $Id: Helper.pm,v 1.6 2005/03/14 10:57:35 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package Helper;
require 5.004;

use Exporter;

@ISA=qw(Exporter);
@EXPORT_OK=qw( );


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

sub help()
   {
   my $self=shift;
   my ($helpcmd)=@_;
   
   my $help.= $self->helpheader($helpcmd);
   print ($help.= &{$helpcmd});
   }

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
   $help.="\tWith no version argument given, this command will simply show\n";
   $help.="\tthe current version number.\n";
   $help.="\tIf a version argument is supplied, that version will be downloaded and\n";
   $help.="\tinstalled, if not already locally available.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram version [-c] [-i] [-h] [<version>]$::normal\n";
   $help.="\n";
   $help.="The -i option shows CVS commit info (the value of '\$Id: Helper.pm,v 1.6 2005/03/14 10:57:35 sashby Exp $').\n";
   $help.="The -c option prints site CVS parameters to STDOUT. These parameters are used\n";
   $help.="when downloading and installing new SCRAM versions.\n";

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
   $help.="\tscram -arch <architecture>$::normal\n\nto set the architecture to that specified.\n";
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
   $help.="\t$::bold scram runtime [-csh|-sh|-win] -file filename $::normal\n";
   $help.="\t$::bold scram runtime [-csh|-sh|-win] -file <filename> -info <variable>$::normal\n";
   $help.="\t$::bold scram runtime [-csh|-sh|-win] -dump <filename> $::normal\n";
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
   $help.="\t$::bold scram runtime -sh -dump env.sh $::normal\n";
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
   $help.="\tscram list [-c] [-h] [--oldstyle] [<projectname>]$::normal\n";
   $help.="\n";
   $help.="Use the -c option to list the available projects and versions installed in the local\n";
   $help.="SCRAM database without fancy formatting or header strings.\n";
   $help.="The project name, version and installation directory are printed on STDOUT, separated\n";
   $help.="by spaces for use in scripts.\n\n";
   $help.="Use the --oldstyle option to show all projects from all versions (i.e. pre-V1) of SCRAM\n";
   $help.="(by default, only projects built and installed with V1x will be listed).\n";
   $help.="\n";
   
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
   $help.="\tscram db <subcommand> $::normal\n";
   $help.="\n";
   $help.="Valid subcommands are:\n";
   $help.="\n"; 
   $help.="-link\n"; 
   $help.="\tMake available an additional database for project and\n";
   $help.="\tlist operations, e.g.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram db link $::normal /a/directory/path/project.lookup\n";
   $help.="\n";
   $help.="-unlink\n"; 
   $help.="\tRemove a database from the link list. Note this does\n";
   $help.="\tnot remove the database, just the link to it in SCRAM.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram db unlink $::normal /a/directory/path/project.lookup\n";
   $help.="\n";
   $help.="-show\n"; 
   $help.="\tList the databases that are linked in.\n";
   $help.="\n";

   return $help;
   }

sub urlget()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tRetrieve URL information. For example, show location in the cache\n";
   $help.="\tof a local copy of a Tool Document.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram urlget [-h] <url>$::normal\n";
   $help.="\n";
   
   return $help;
   }

sub install()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tAssociates a label with the current release in the SCRAM database.\n";
   $help.="\tThis allows other users to refer to a centrally installed project by\n";
   $help.="\tthis label rather than a remote url reference.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram install [-f] [<project_tag> [<version_tag>]] $::normal\n";
   $help.="\n";
   $help.="The -f flag can be used to force an installation of a project, overwriting any entries\n";
   $help.="with the same project name and version (useful in batch processing).\n";
   $help.="\n";
   $help.="<project_tag>:\n";
   $help.="\n";
   $help.="\toverride default label (the project name of the current release)\n";
   $help.="\n";
   $help.="<version_tag>:\n";
   $help.="\n";
   $help.="\tthe version tag of the current release. If version is not\n";
   $help.="\tspecified the base release version will be taken by default.\n";
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
   $help.="\tscram remove [-f] [<projectname>] [projectversion]$::normal\n";
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
   $help.="\tSet up a new project development area. The new area will appear in the\n";
   $help.="\tcurrent working directory by default.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram project [-t] [-d <area>] [-n <dir>] [-f <tools.conf>] <projecturl> [<projectversion>]$::normal\n";
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
   $help.="Currently supported URL types are:\n";
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
   $help.="\tscram project XX XX_8_0$::normal\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram project -b ~/myprojects/projecta/config/BootStrapFile $::normal\n";
   $help.="\n";
   $help.="\n";
   $help.="Use the \"-f\" flag followed by a valid filename (which MUST end in \".conf\") to\n";
   $help.="allow auto setup to proceed without reading files from a repository (STANDALONE mode).\n"; 
   $help.="\n";			      
   $help.="Some project template files can be obtained using the command:\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram project -template$::normal\n";
   $help.="\n";			      
   $help.="The templates will be copied to a directory called \"config\" in the current directory.\n";
   $help.="\n";
   
   return $help;
   }

sub setup()
   {
   my $self=shift;
   my $help;
   
   $help.="Description:\n";
   $help.="\n";			      
   $help.="\tAllows installation/re-installation of a new tool/external package into an\n";
   $help.="\talready existing development area. If no toolname is specified,\n";
   $help.="\tthe complete installation process is initiated.\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram setup [-i] [-f tools.conf] [toolname] [[version] [url]]$::normal\n";
   $help.="\n";			      
   $help.="<projecturl>:\n";
   $help.="\tThe URL of a SCRAM bootstrap file.\n";
   $help.="\n";			      
   $help.="toolname:\n";
   $help.="\tThe name of the tool to be set up.\n";
   $help.="\n";			      
   $help.="version:\n";
   $help.="\tThe version of the tool to set up.\n";
   $help.="\n";			      
   $help.="url:\n";
   $help.="\tURL (file: or http:) of the tool document describing the tool being set up.\n";
   $help.="\n";		      
   $help.="The -i option turns off the automatic search mechanism allowing for more\n";
   $help.="user interaction during setup.\n";
   $help.="\n";			      
   $help.="The -f option allows the user to specify a tools file (the filename MUST end\n";
   $help.="in \".conf\"). This file contains values to be used for settings of the tool.\n";
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
   $help.="$::bold";
   $help.="template <TYPE> $::normal\n";
   $help.="\tCreate a template tool description file of type <TYPE>,\n";
   $help.="\twhere <TYPE> can be either \"compiler\" or \"basic\" depending on whether the\n";
   $help.="\ttemplate is for a compiler or for a basic tool.\n";
   $help.="\tThe template will be created in the current directory.\n";
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
   $help.="--writegraphs=<g|p>  enable creation of dependency graphs. Set this to 'global' (g) if you\n";
   $help.="                     want to create project-wide dependency graphs or 'package' (p) for\n";
   $help.="                     package-level graphs. The graphs will be stored in the project working\n";
   $help.="                     directory. If you set the environment variable SCRAM_WRITEGRAPHS=X\n";
   $help.="                     (where X is PS/JPEG/GIF), SCRAM will automatically create the graphs in format X.\n\n";
   $help.="                     Note that you must have AT&T's Dot program installed and in\n";
   $help.="                     your path to be able to use this feature.\n";
   $help.="\n";
   $help.="$::bold";
   $help.="Example:$::normal To refresh the current area cache, produce global dependency graphs but not run gmake\n";
   $help.="\n";
   $help.="$::bold";
   $help.="\tscram build -r -w=g -t$::normal\n";
   $help.="\n";
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

sub config()
   {
   my $self=shift;
   my $help;
   $help.="Description:\n";
   $help.="\n";
   $help.="\tDump configuration information for the current project area.\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram config [--tools] [--full] $::normal\n";
   $help.="\n";   
   $help.="The --tools option will dump a list of configured tools, rather like \"tool info\",\n";
   $help.="but in a format parseable by external scripts. This could be used to create RPM/TAR files\n";
   $help.="of external products required by the project.\n";
   $help.="\n";
   $help.="The format of each line of output is:\n";
   $help.="\n";
   $help.="\t<tool name>:<tool version>:scram project[0/1]:<base path>:<dependencies>\n";
   $help.="\n\n";
   $help.="<base path> can have the value <SYSTEM> if located in system directories (e.g., /lib).\n\n";
   $help.="<dependencies> will be set to <NONE> if there are no external dependencies for this tool.\n";
   $help.="\n";
   $help.="The --full option will list the tool info and project information too.\n";
   $help.="\n";      
   
   return $help;
   }

sub ui()
   {
   my $self=shift;
   my $help;

   $help.="Description:\n";
   $help.="\n";
   $help.="\tAllow user interaction with the build Metadata.\n";
   $help.="\n";
   $help.="Usage:\n";
   $help.="$::bold";
   $help.="\tscram ui -edit [class]$::normal\n";
   $help.="$::bold";
   $help.="\tscram ui -show [meta type]$::normal\n";
   $help.="\n";

   return $help;
   }
#
# A template routine for future help commands:
#
# sub _template()
#    {
#    my $self=shift;
#    my $help;

#    $help.="\n";
#    $help.="\n";
   
#    return $help;
#    }


## 
1;
