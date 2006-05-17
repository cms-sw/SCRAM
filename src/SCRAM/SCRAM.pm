#____________________________________________________________________ 
# File: SCRAM.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-06-18 18:04:35+0200
# Revision: $Id: SCRAM.pm,v 1.20 2006/02/07 15:06:02 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------

=head1 NAME

SCRAM::SCRAM - The main SCRAM package, providing all core functionality
               to command subroutines.
   
=head1 SYNOPSIS

	my $obj = SCRAM::SCRAM->new();

=head1 DESCRIPTION

All functionality needed by the command subroutines is derived from this package.
This includes prerequisite checks, version checking and environment checks.

=head1 METHODS

=over

=cut

package SCRAM::SCRAM;
require 5.004;

use Exporter;
use SCRAM::Helper;
use Utilities::Architecture;
use Utilities::Verbose;
use SCRAM::CMD;

@ISA=qw(Exporter Utilities::Verbose SCRAM::CMD);
@EXPORT_OK=qw( );

=item   C<new()>

Create a new instance. Usually this is accessible everywhere from
the global variable $::scram.
The initialisation process sets up the command environment, determines
whether the current directory is a SCRAM project area and handles
environment configuration.

A SCRAM::Helper object is also created to handle help requests.

=cut

sub new()
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self=
      {
      SCRAM_PREREQCHECK => undef,
      SCRAM_VERSIONCHECK => undef,
      SCRAM_ALLOWEDCMDS => undef,
      SCRAM_ARCH => undef || $ENV{SCRAM_ARCH},
      SCRAM_VERBOSE => 0 || $ENV{SCRAM_VERBOSE},
      SCRAM_BUILDVERBOSE => 0 || $ENV{SCRAM_BUILDVERBOSE},
      SCRAM_DEBUG => 0 || $ENV{SCRAM_DEBUG},
      SCRAM_VERSION => undef,
      SCRAM_CVSID => '$Id: SCRAM.pm,v 1.20 2006/02/07 15:06:02 sashby Exp $',
      SCRAM_TOOLMANAGER => undef,
      SCRAM_HELPER => new Helper,
      ISPROJECT => undef,
      };
  
   bless $self,$class;

   $self->_init();
   return $self;
   }

=item   C<_init()>

Initialize command environment and area parameters. Called only
by new().

=cut

sub _init()
   {
   my $self=shift;

   # Store available ommands:
   $self->commands();
   # Set up the environment:
   $self->_initlocalarea();
   $self->_initreleasearea();
   $self->_initenv();
   # Check that we have everything to
   # be able to run:
   $self->prerequisites();
   # Create new interface object:
   $self->scramfunctions();
   # See which version of SCRAM
   # should be used:
   $self->versioncheck();
   return $self;
   }

=item   C<commands()>

Returns a reference to a list of supported commands which are also
defined here. Sets $self->{SCRAM_ALLOWEDCMDS} in the $::scram object.

=cut

sub commands()
   {
   my $self = shift;
   my @env_commands = qw(version arch runtime config);
   my @info_commands = qw(list db urlget); 
   my @buildenv_commands = qw(project setup toolbox tool gui);
   my @build_commands=qw(build xmlmigrate install remove);
   my @dev_cmds=qw();

   return ($self->{SCRAM_ALLOWEDCMDS} =
	   [@env_commands,@info_commands,@buildenv_commands,@build_commands,@dev_cmds]);
   }

=item   C<showcommands()>

Returns the array of supported commands (the contents of the
$self->{SCRAM_ALLOWEDCMDS}) element in the $::scram object.

=cut

sub showcommands()
   {
   my $self=shift;
   return @{$self->{SCRAM_ALLOWEDCMDS}};
   }

=item   C<execcommand($cmd, @ARGS)>

Execute a command. This is only used by the main script B<scram.pl>. $cmd is the
command to be run, which can be abbreviated, and all other arguments are passed
directly via @ARGS.

=cut

sub execcommand()
   {
   my $self = shift;
   my ($cmd,@ARGS) = @_;
   my $rval=0;
   my $status=1;
   
   local @ARGV = @ARGS;
   # Add the "dbghook_" function here rather than via "showcommands"
   # since we don't want this to be public (it's only for debugging).
   # dbghook_ is just a hook subroutine to test command routines
   # called inside it:
   map
      {
      if ( $_ =~ /^$cmd/i)
	 {
	 $status=0; # Command found so OK;
	 $rval = $self->$_(@ARGV);
	 }
      } $self->showcommands(),"dbghook_";
   
   # Print usage and exit if no command matched:
   if ($status)
      {
      print $self->usage();
      $rval = 1;
      }
   
   return $rval;
   }

=item   C<prerequisites()>

Check for prerequisites to running SCRAM. Once the check is complete
and is successful, set $self->{SCRAM_PREREQCHECK} = 1.
Note that this function is run but is not really doing any checks due
to site ambiguities.
   
=cut

sub prerequisites()
   {
   my $self=shift;
   $self->{SCRAM_PREREQCHECK} = 1;
   return $self;
   }

=item   C<versioncheck(@ARGS)>

Check that the appropriate version of SCRAM is being run and
pass down all arguments to the new instance of $::scram.
Once completed, $self->{SCRAM_VERSIONCHECK} is set to 1 and 
$self->{SCRAM_VERSION} is set to the required version.

=cut

sub versioncheck()
   {
   my $self=shift;
   my $version;

   # This routine checks for consistency in SCRAM versions. Only
   # applies in a project area since outside we'll be using the
   # current release anyway. If we're in a project we use the "scram_version"
   # file in config directory:
   if ($self->islocal())
      {
      my $versionfile=$ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR}."/scram_version";
      if ( -f $versionfile )
	 {
	 open (VERSION, "<".$versionfile);
	 $version=<VERSION>;
	 chomp $version;
	 }
      # Spawn the required version:
      $self->scramfunctions()->spawnversion($version,@ARGV), if (defined ($version));
      }

   $self->{SCRAM_VERSIONCHECK} = 1;
   $self->{SCRAM_VERSION} = $version;
   return $self;
   }

=item   C<_initenv()>

Initialise the environment for SCRAM. Also set the current
architecture (SCRAM_ARCH) and the basic environment variables
required by the build system.

=cut

sub _initenv()
   {
   my $self=shift;

   # Read the Environment file if inside a project:
   $self->localarea()->copyenv(\%ENV), if ($self->islocal());

   # Check and set architecture:
   if (! defined $self->{SCRAM_ARCH})
      {
      my $a = Architecture->new();
      $self->architecture($a->arch());
      $self->system_architecture($a->system_arch_stem());
      $ENV{SCRAM_ARCH} = $self->architecture();
      }
   
   # Set up some environment variables:
   $ENV{SCRAM_TMP}="tmp";
   $ENV{SCRAM_INTwork}=$ENV{SCRAM_TMP}."/".$ENV{SCRAM_ARCH};
   $ENV{SCRAM_SOURCEDIR}="src";
   $ENV{SCRAM_INTlog}="logs";
   ($ENV{SCRAM_BASEDIR}=$ENV{SCRAM_HOME}) =~ s/(.*)\/.*/$1/;
   $ENV{SCRAM_BASEDIR} =~ s!:$!:/! if $^O eq 'MSWin32';
   $ENV{SCRAM_TOOL_HOME}=$ENV{SCRAM_HOME}."/src";
   
   # Need a lookup database. Try the user's environment first to override
   # the value set at install time (in SCRAM_SITE.pm):
   if (exists $ENV{SCRAM_USERLOOKUPDB} && -f "$ENV{SCRAM_USERLOOKUPDB}")
      {
      print "Using $ENV{SCRAM_USERLOOKUPDB} as the database.","\n", if ($ENV{SCRAM_DEBUG});
      $ENV{SCRAM_LOOKUPDB}=$ENV{SCRAM_USERLOOKUPDB};
      }
   
   # A fallback option:
   if ( ! ( exists $ENV{SCRAM_LOOKUPDB} ) )
      {
      if ( -d "$ENV{SCRAM_BASEDIR}/scramdb/" )
	 {
	 $ENV{SCRAM_LOOKUPDB}="$ENV{SCRAM_BASEDIR}/scramdb/project.lookup";
	 }
      else
	 {
	 # Just store in user home directory:
	 $ENV{SCRAM_LOOKUPDB}=$ENV{HOME}."/project.lookup";
	 }
      }
   }

=item   C<_loadscramdb()>

Read the local SCRAM project database and populate $self->{SCRAM_PDB} to keep
track of which external tools in the current configuration are managed by SCRAM.
This is basically a lookup table from which the base directory of scram projects
can be looked up: functions needing access to project caches can use the base
dir to find these caches.

=cut

sub _loadscramdb()
   {
   my $self=shift;
   # Read the scram database to keep track of which
   # projects are scram-managed:
   my @scramprojects = $self->getprojectsfromDB();
   $self->{SCRAM_PDB}={};
   
   foreach my $project (@scramprojects)
      {
      my $parea=$self->scramfunctions()->scramprojectdb()->getarea($project->[0], $project->[1]);
      if (defined ($parea) && $parea->location() ne '')
	 {
	 # Store the name of the project as lowercase to make lookups easier
	 # during setup. When storing the individual project name/version entries, mangle the
	 # version with the real name, separated by a :  for access to this data needed
	 # when getting the area:
	 $self->{SCRAM_PDB}->{lc($project->[0])}->{$project->[0].":".$project->[1]} = $parea->location(); 
	 }
      }
   
   return $self->{SCRAM_PDB};
   }

=item   C<islocal()>

Return true/false depending on whether the current directory
is a SCRAM project area. This is set in _initlocalarea().

=cut

sub islocal()
   {
   my $self=shift;
   
   @_ ? $self->{ISPROJECT} = shift # Modify or
      : $self->{ISPROJECT};        # retrieve

   }

=item   C<scramfunctions()>

Provide access to a SCRAM::ScramFunctions object. A lot of
core functionality is implemented (probably for historical
reasons) in this package. Many commands are executed via calls
like $self->scramfunctions()->X(). These include project
bootstrapping and listing.

=cut

sub scramfunctions()
   {
   my $self=shift;
   
   if ( ! defined $self->{functions} )
      {
      require SCRAM::ScramFunctions;
      $self->{functions} = SCRAM::ScramFunctions->new();
      $self->architecture($ENV{SCRAM_ARCH});
      }
   else
      {
      return $self->{functions};
      }
   }

=item   C<_initlocalarea()>

Initialise the local area. Once this function has been run, a
call to $self->islocal() will return true or false depending on
whether the current area is a SCRAM project area.
This sets the local Configuration::ConfigArea  object so that
calls to $self->localarea() can be used to access it.
   
=cut

sub _initlocalarea()
   {
   my $self=shift;
   
   if ( ! defined ($self->localarea()) )
      {
      require Configuration::ConfigArea;
      $self->localarea(Configuration::ConfigArea->new());

      # Set LOCALTOP if we're inside project area:
      $ENV{LOCALTOP} = $self->localarea()->location();
      
      if ( ! defined ($ENV{LOCALTOP}) )
	 {
	 if ( $self->localarea()->bootstrapfromlocation() )
	    {
	    # We're not in a local area: 
	    $self->localarea(undef);
	    }
	 else
	    {
	    $self->localarea()->archname($self->scramfunctions()->arch());
	    }
	 }
      else
	 {
	 $self->localarea()->bootstrapfromlocation($ENV{LOCALTOP});
	 }
      
      # Now create some environment variables that need LOCALTOP:
      if (defined ($ENV{LOCALTOP}))
	 {
	 ($ENV{THISDIR}=cwd) =~ s/^\Q$ENV{LOCALTOP}\L//;
	 $ENV{THISDIR} =~ s/^\///;
	 # Also set LOCALRT (soon obsolete) and BASE_PATH:
	 $ENV{LOCALRT} = $ENV{LOCALTOP};
	 $ENV{BASE_PATH} = $ENV{LOCALTOP};
	 $self->projectname($self->localarea()->name());
	 $self->projectversion($self->localarea()->version());
	 $self->configversion($self->localarea()->toolboxversion());
	 $self->islocal(1);
	 }
      else
	 {
	 # We're not in a project area. Some commands will not need to
	 # be in an area to work so we just set a flag:
	 $self->islocal(0);
	 }
      }
   }

=item   C<align()>

Align the current area. Not even sure if this is ever called.

=cut

sub align
   {
   my $self=shift;   
   $self->localarea()->align(); 
   }

=item   C<localarea()>

Return the Configuration::ConfigArea object for the current
project area. This is first set by a call to _initlocalarea().

=cut

sub localarea()
   {
   my $self=shift;

   @_ ? $self->{localarea} = shift # Modify or
      : $self->{localarea};        # retrieve
   }

=item   C<_initreleasearea()>

Create a Configuration::ConfigArea object for the release
area of the current project area if the local area is a developer
area.

=cut

sub _initreleasearea()
   {
   my $self=shift;

   if ( ! defined $self->releasearea() )
      {
      require Configuration::ConfigArea;
      $self->releasearea(Configuration::ConfigArea->new());
      $self->releasearea()->bootstrapfromlocation($ENV{RELEASETOP});
      }

   return $self->releasearea();
   }

=item   C<releasearea()>

Return the Configuration::ConfigArea object for the release
area (if this area is a developer area). This is first set
by a call to _initreleasearea().

=cut

sub releasearea()
   {
   my $self=shift;
   
   @_ ? $self->{releasearea} = shift # Modify or
      : $self->{releasearea};        # retrieve
   }

=item   C<debuglevel()>

Set or retrieve the debug level. Not yet used.

=cut

sub debuglevel()
   {
   my $self=shift;

   @_ ? $self->{SCRAM_DEBUG} = shift # Modify or
      : $self->{SCRAM_DEBUG};        # retrieve
   }

=item   C<cvsid()>

Return the current CVS id string (which contains information
on last commit).				  

=cut

sub cvsid()
   {
   my $self=shift;

   @_ ? $self->{SCRAM_CVSID} = shift # Modify or
      : $self->{SCRAM_CVSID};        # retrieve
   }

=item   C<projectname()>

Set/return the project name.

=cut

sub projectname()
   {
   my $self=shift;
   @_ ? $self->{SCRAM_PROJECTNAME} = shift # Modify or
      : $self->{SCRAM_PROJECTNAME};        # retrieve
   }

=item   C<projectversion()>

Set/return the project version.

=cut

sub projectversion()
   {
   my $self=shift;
   @_ ? $self->{SCRAM_PROJECTVERSION} = shift # Modify or
      : $self->{SCRAM_PROJECTVERSION};        # retrieve
   }

=item   C<configversion()>

Set/return the configuration version.

=cut

sub configversion()
   {
   my $self=shift;
   @_ ? $self->{SCRAM_CONFIGVERSION} = shift # Modify or
      : $self->{SCRAM_CONFIGVERSION};        # retrieve
   }

=item   C<architecture()>

Set/return the current SCRAM architecture, e.g. B<slc3_ia32_gcc323>.

=cut

sub architecture()
   {
   my $self=shift;

   @_ ? $self->{SCRAM_ARCH} = shift # Modify or
      : $self->{SCRAM_ARCH};        # retrieve
   }

=item   C<system_architecture()>

Set/return the current SCRAM system architecture, e.g. B<slc3_ia32>.

=cut

sub system_architecture()
   {
   my $self=shift;

   @_ ? $self->{SCRAM_SYSARCH} = shift # Modify or
      : $self->{SCRAM_SYSARCH};        # retrieve
   }

=item   C<getprojectsfromDB()>

Retrieve the list of installed projects from the local SCRAM
project database (as determined from value of SCRAM_LOOKUPDB
environment variable which was set for the current site when
SCRAM was installed.)

=cut

sub getprojectsfromDB()
   {
   my $self=shift;

   # Get list of projects from scram database and return them:
   return ($self->scramfunctions()->scramprojectdb()->listall());
   }

=item   C<isregistered($area)>

Return true or false depending on whether the SCRAM project area
$area is registered in the SCRAM database as having been installed.
The status is set according to whether a file B<.installed> exists
in the architecture-dependent directories under the admin dir of
the project. This allows a project to be installed for one architecture
only, while other architectures may not be released.
   
=cut

sub isregistered()
   {
   my $self=shift;
   my ($area) = @_;
   my $archdir = $area->location()."/".$area->admindir()."/".$self->architecture();
   my $registerfile = $archdir."/.installed";
   # Check the area to see if .installed exists:
   ( -f $registerfile) ? return 1 : return 0;
   }

=item   C<register_install()>

Register that a project was really installed by creating a file B<.installed>
in the project architecture directory. This can then be checked in addition to the
architecture-dependent directories which are created automatically when building.

=cut

sub register_install()
   {
   my $self=shift;
   # Register that a project was really installed by creating a file .installed
   # in the project arch directory. This can then be checked in addition to the
   # arch-dependent dirs which are created automatically when building:
   my $area = $self->{localarea};
   my $archdir = $area->location()."/".$area->admindir()."/".$self->architecture();
   my $registerfile = $archdir."/.installed";

   # The file should exist in the .SCRAM/<arch> directory. This is better than checking
   # for product store directories:
   open(INSTALLFILE, "> $registerfile");
   print INSTALLFILE time()."\n";
   close(INSTALLFILE);

   my $filemode = 0444;
   chmod $filemode, $registerfile;
   }

=item   C<unregister_install()>

Remove a project from the SCRAM database. Reverse the process of register_install().

=cut

sub unregister_install()
   {
   my $self=shift;
   my $area = $self->{localarea};
   my $archdir = $area->location()."/".$area->admindir()."/".$self->architecture();
   my $registerfile = $archdir."/.installed";
   my $retval = 0;
   
   # Remove the register file:
   if ( -f $registerfile)
      {
      $retval = system("rm","-f",$registerfile);
      }
   
   return $retval;
   }

=item   C<toolmanager($location)>

Reload the BuildSystem::ToolManager object from the tool cache file.
If the cache file does not exist, it implies that the area has not yet
been set up so a copy of whichever one exists is made and informs the
user to run B<scram setup>.

If this area has been cloned, adjustments must be made so that the cache
is really local and refers to all settings of local area (admin dir etc.).
   
=cut

sub toolmanager()
   {
   my $self = shift;
   my ($location)=@_;
   $location||=$self->localarea();
   
   # This subroutine is used to reload the ToolManager object from file.
   # If this file does not exist, it implies that the area has not yet been set
   # up so we make a copy of whichever one exists and tell the user to run "scram setup":
   if ( -r $location->toolcachename() )
      {
      # Cache exists, so read it:
      $self->info("Reading tool data from ToolCache.db.") if ($self->{SCRAM_DEBUG});
      use Cache::CacheUtilities;
      $toolmanager=&Cache::CacheUtilities::read($location->toolcachename());      

      # If this area has been cloned, we must make some adjustments so that the cache
      # is really local and refers to all settings of local area (admin dir etc.):
      if ($ENV{RELEASETOP} && ! $toolmanager->cloned_tm())
	 {
	 $self->info("Cloning release-area ToolCache.db. Localising settings...") if ($self->{SCRAM_DEBUG});
	 $toolmanager->clone($location);
	 $toolmanager->writecache(); # Save the new cache
	 }
      
      # We have a toolmanager in memory. We now check to see if the cachename (i.e. where we
      # read the cache from) matches the location stored as CACHENAME in the tool manager
      # object read from the cache file. If it doesn't match, it implies that this area has been
      # moved: we therefore return to the behaviour of the old V0_xx scram versions which
      # permitted areas to be moved without problems:
      if ($location->toolcachename() ne $toolmanager->name())
	 {
	 $self->info("This area has been relocated: modifying ToolCache.db CACHENAME.") if ($self->{SCRAM_DEBUG});
	 # Set the name to be correct:
	 $toolmanager->name($location->toolcachename());
	 $toolmanager->writecache(); # Save the new cache
	 }
      }
   else
      {
      my $found;
      local $toolcachedir;
      
      # Path to cache dir in SCRAM area:
      my $cachedir = $ENV{LOCALTOP}."/.SCRAM";
      # Get a list of subdirs in this dir. There will be a subdir for
      # each known architecture:
      opendir(CACHEDIR, $cachedir) || die "SCRAM: $cachedir: cannot read: $!\n";
      # Skip . and .. but include other dirs:
      my @ARCHDIRS = map { "$cachedir/$_" } grep ($_ ne "." && $_ ne "..", readdir(CACHEDIR));
      
      # If we don't have our arch subdir, create it before copying:
      if (! -d $cachedir."/".$ENV{SCRAM_ARCH})
	 {
	 mkdir($cachedir."/".$ENV{SCRAM_ARCH}, 0755) || die
	    "SCRAM: Unable to create directory $cachedir: $!","\n";
	 }
      
      # Run over the dirs and check for a cache:
      foreach $toolcachedir (@ARCHDIRS)
	 {
	 # If there's a cache file, copy it:
	 if ( -f $toolcachedir."/ToolCache.db" )
	    {
	    # If we found one, read it:
	    $found=$toolcachedir."/ToolCache.db";
	    use Cache::CacheUtilities;
	    # Read, make arch-specific changes then write out:
	    $toolmanager=&Cache::CacheUtilities::read($found);
	    $toolmanager->arch_change_after_copy($ENV{SCRAM_ARCH}, $location->toolcachename());
	    last;
	    }
	 else
	    {
	    next;
	    }	 
	 }
      
      if (!$found)
	 {
	 $self->scramerror("Unable to read a tool cache. Maybe the area is not yet set up?");
	 }
      }
   
   return $toolmanager;
   }

=item   C<checklocal()>

Check that the current area is a project area and continue or exit otherwise.

=cut

sub checklocal()
   {
   my $self=shift;
   $self->scramfatal("Unable to locate the top of local release. Exitting."), if (! $self->islocal());   
   }

=item   C<checkareatype()>

Check that the current area is a SCRAM Version 1.0 series project area and continue or exit otherwise.

=cut

sub checkareatype()
   {
   my $self=shift;
   my ($areapath, $message)=@_;
   # Simple check: see if templates exist:
   my (@templates)=glob($areapath."/config/*.tmpl");
   $self->scramfatal($message), unless ($#templates > -1)
   }

=item   C<missing_package($package)>
   
Print a message that the package $package is not available
on the current system and exit. This is part of a check when
loading Perl modules like Tk which might not be installed.
   
=cut

sub missing_package()
   {
   my $self=shift;
   my ($p)=@_;
   print "The following Perl modules appear(s) to be missing\n";
   print "on this machine:\n\n";
   print " ".$p."\n";
   print "\n";
   print "For now, this command is disabled.\n";
   print "\n";
   exit(1);  
   }

=item   C<msg(@text)>
   
Print a message using @text as text input.
   
=cut

sub msg()
   {
   my $self=shift;
   return "> ",join(' ',@_);
   }

=item   C<warning(@message)>

Print a warning message @message.

=cut

sub warning()
   {
   my $self=shift;
   return "warning: ",join(' ',@_);
   }

=item   C<error(@message)>

Print an error message @message.

=cut

sub error()
   {
   my $self=shift;
   return "error: ",join(' ',@_);
   }

=item   C<fatal(@message)>

Print a fatal error message @message.

=cut

sub fatal()
   {
   my $self=shift;
   return "fatal: ",join(' ',@_);
   }

=item   C<info(@message)>

Print an information message @message.

=cut

sub info()
   {
   my $self=shift;
   print STDOUT "SCRAM info: ",$self->msg(@_),"\n";   
   }

=item   C<scramwarning($message)>

Print a warning message string $message.

=cut

sub scramwarning()
   {
   my $self=shift;
   # Send errors to STDERR when piping:
   if ( -t STDERR )
      {
      print STDERR "SCRAM ",$self->warning(@_),"\n";   
      }
   else
      {
      print "SCRAM ",$self->warning(@_),"\n";
      }
   }

=item   C<scramerror($message)>

Print an error message string $message and exit.

=cut

sub scramerror()
   {
   my $self=shift;
   
   # Send errors to STDERR when piping:
   if ( -t STDERR )
      {
      print STDERR "SCRAM ",$self->error(@_),"\n";   
      }
   else
      {
      print "SCRAM ",$self->error(@_),"\n";  
      }
   exit(1);
   }

=item   C<scramfatal($message)>

Print a fatal error message string $message and exit.

=cut

sub scramfatal()
   {
   my $self=shift;
   print "SCRAM ",$self->fatal(@_),"\n";
   exit(1);
   }

=item   C<classverbosity($classlist)>

Turn on verbosity for all package classes in $classlist.

=cut

sub classverbosity
   {
   my $self=shift;
   my $classlist=shift;
   
   # $classlist might be a string of classes so we should split and store
   # each element, then set classverbose for each class individually:
   my @classes = split(" ",$classlist);
   
   foreach my $class (@classes)
      {
      print "Verbose mode for ",$class," switched ".$::bold."ON".$::normal."\n" ;
      # Set the verbosity via scram functions:
      $self->scramfunctions()->classverbose($class,1);
      }
   }

=item   C<fullverbosity()>

Turn on verbosity for all package classes defined
in B<PackageList.pm>.

=cut

sub fullverbosity
   {
   my $self=shift;
   
   require "PackageList.pm";
   foreach my $class (@PackageList)
      {
      $self->classverbosity($class);
      }
   }

=item   C<usage()>

Dump out a general usage message.

=cut

sub usage()
   {
   my $self=shift;
   my $usage;
   
   $usage.="*************************************************************************\n";
   $usage.="SCRAM HELP ------------- Recognised Commands\n";
   $usage.="*************************************************************************\n";
   $usage.="\n";

   map { $usage.="\t$::bold scram ".$_."$::normal\n"  } $self->showcommands();
   
   $usage.="\n";
   $usage.= "Help on individual commands is available through";
   $usage.="\n\n";
   $usage.= "\tscram <command> -help";
   $usage.="\n\n";
   $usage.="\nOptions:\n";
   $usage.="--------\n";
   $usage.=sprintf("%-28s : %-55s\n","-help","Show this help page.");
   $usage.=sprintf("%-28s : %-55s\n","-verbose <class> ",
		   "Activate the verbose function on the specified class or list of classes.");
   $usage.=sprintf("%-28s : %-55s\n","-debug ","Activate the verbose function on all SCRAM classes.");
   $usage.="\n";
   $usage.=sprintf("%-28s : %-55s\n","-arch <architecture>",
		   "Set the architecture ID to that specified.");
   $usage.=sprintf("%-28s : %-55s\n","-noreturn","Pause after command execution rather than just exitting.");
   $usage.="\n";

   return $usage;
   }

#### End of SCRAM.pm ####
1;


=back

=head1 AUTHOR/MAINTAINER

Shaun ASHBY 

=cut

