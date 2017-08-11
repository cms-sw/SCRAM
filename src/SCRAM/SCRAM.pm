#____________________________________________________________________ 
# File: SCRAM.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
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
      SCRAM_VERSIONCHECK => undef,
      SCRAM_ALLOWEDCMDS => undef,
      SCRAM_VERBOSE => 0 || $ENV{SCRAM_VERBOSE},
      SCRAM_BUILDVERBOSE => 0 || $ENV{SCRAM_BUILDVERBOSE},
      SCRAM_DEBUG => 0 || $ENV{SCRAM_DEBUG},
      SCRAM_TOOLMANAGER => undef,
      ISPROJECT => undef,
      };
   bless $self,$class;
   $self->commands();
   $ENV{SCRAM_BUILDFILE} = "BuildFile";
   return $self;
   }

=item   C<_init()>

Initialize command environment and area parameters. Called only
by new().

=cut

sub init()
   {
   my $self=shift;
   $self->_initlocalarea();
   $self->_initenv();
   $self->versioncheck();
   return $self;
   }

sub initx_()
   {
   my $self=shift;
   $self->_initlocalarea();
   $self->_initenv();
   }
=item   C<commands()>

Returns a reference to a list of supported commands which are also
defined here. Sets $self->{SCRAM_ALLOWEDCMDS} in the $::scram object.

=cut

sub commands()
   {
   my $self = shift;
   my @env_commands = qw(version arch runtime unsetenv config);
   my @info_commands = qw(list db); 
   my @buildenv_commands = qw(project setup tool);
   my @build_commands=qw(build);
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
   return sort @{$self->{SCRAM_ALLOWEDCMDS}};
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
   my @cmds = ();
   foreach my $c (@{$self->{SCRAM_ALLOWEDCMDS}}){if ($c eq $cmd){push @cmds,$c; last;}}
   if (scalar(@cmds)==0)
      {
      foreach my $c (@{$self->{SCRAM_ALLOWEDCMDS}}){if ($c=~/^$cmd/){push @cmds,$c;}}
      my $l=scalar(@cmds);
      if ($l!=1)
         {
         if ($l>1) {print STDERR "ERROR: $l commands matched '$cmd': $::bold",join(", ",@cmds),"$::normal \n";}
         else{print STDERR $self->usage();}
         return 1;
         }
      }

   $cmd = $cmds[0];
   local @ARGV = ();
   my $help=0;
   while(my $a=shift @ARGS)
      {
      my $ax=$a; $ax=~s/^-(-|)//;
      if (("help"=~/^$ax/) && (($a ne $ax) || (! $self->islocal()))){ exec("man scram"); }
      else{push @ARGV,$a;}
      }

   return $self->$cmd(@ARGV);
   }

=item   C<versioncheck(@ARGS)>

Check that the appropriate version of SCRAM is being run and
pass down all arguments to the new instance of $::scram.

=cut

sub versioncheck() {
    my $self=shift;
    if ((!defined $self->{SCRAM_VERSIONCHECK}) && ($self->islocal())) {
	my $version=$self->versioninfile($ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR});
	$self->spawnversion($version), if (defined ($version));
    }
    $self->{SCRAM_VERSIONCHECK} = 1;
    return $self;
}

=item   C<remote_versioncheck(@ARGS)>

For instances where the version of SCRAM run at the commandline and the
version used to configure an existing project are not compatible, check
and invoke the remote SCRAM version as specified in scram_version file.
Pass down all arguments to the new instance of $::scram.

=cut

sub remote_versioncheck() {
    my $self=shift;
    my ($remote_area)=shift || die "No remote area specified. Exit.\n";
    my $version = $self->versioninfile($remote_area->location()."/".$remote_area->configurationdir());
    if (!defined($version)) {
      $self->error("Unable to determine SCRAM version used to config. remote area.\n");
    }
    $self->spawnversion($version);
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
   if ($self->islocal())
      {
      $self->localarea()->copyenv(\%ENV);
      $ENV{SCRAM_TMP}="tmp";
      $ENV{SCRAM_INTwork}=$ENV{SCRAM_TMP}."/".$ENV{SCRAM_ARCH};
      $ENV{SCRAM_INTlog}="logs";
      if(!exists $ENV{SCRAM_SOURCEDIR}){$ENV{SCRAM_SOURCEDIR}="src";}
      if (exists $ENV{SCRAM_CONFIGDIR}){unshift @INC, $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR};}
      }
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

=item   C<_initlocalarea()>

Initialise the local area. Once this function has been run, a
call to $self->islocal() will return true or false depending on
whether the current area is a SCRAM project area.
This sets the local Configuration::ConfigArea  object so that
calls to $self->localarea() can be used to access it.
   
=cut

sub _initlocalarea() {
    my $self=shift;
    if ( ! defined ($self->localarea()) ) {
	require Configuration::ConfigArea;
	my $area = Configuration::ConfigArea->new($main::FORCE_SCRAM_ARCH);
	my $loc = $area->location();
	if ( ! defined $loc ) {
	    $self->islocal(0);
	} else {
	    $ENV{LOCALTOP} = $loc;
	    $area->bootstrapfromlocation($loc);
	    $ENV{SCRAM_ARCH} = $area->{arch};
	    ($ENV{THISDIR}=cwd) =~ s/^\Q$loc\L//;
	    $ENV{THISDIR} =~ s/^\///;
	    $ENV{BASE_PATH} = $loc;
	    my $name=$area->name(); $version=$area->version();
	    $self->projectname($name);
	    $self->projectversion($version);
	    $self->localarea($area);
	    $self->islocal(1);
	    my $rel=$area->releasetop();
	    if (defined $rel) {
	       my $pfile="$rel/".$area->admindir()."/".$ENV{SCRAM_ARCH}."/ProjectCache.db.gz";
	       if (!-f $pfile) {
		  my $vregexp=$version;
		  $vregexp=~s/^(([^\d]*\d+_\d+)_).*$/$1/; my $relseries=$2;
	          print STDERR "********** ERROR: Missing Release top ************\n",
		               "  The release area \"$rel\"\n",
		               "  for \"$name\" version \"$version\" is not available/usable.\n";
		  my $res=$self->scramprojectdb()->listall("$name","${vregexp}.+");
		  if (scalar(@{$res->{$ENV{SCRAM_ARCH}}})>0) {
		     my @rels = ();
		     foreach my $item (@{$res->{$ENV{SCRAM_ARCH}}}) {
		       if ($item->[1] ne $version){push @rels, $item->[1];}
		     }
		     if (@rels>0) {
			print STDERR "  In case this release has been deprecated, you can move your code to\n",
			             "  one of the following release(s) of release series \"$relseries\".\n\n",
			             "  ",join("\n  ",@rels),"\n";
		     }
		     else {
		       print STDERR "  Sorry, there is no other release installed which you can use for this release series \"$relseries\".\n";
		     }
		     print STDERR "***********************************************\n";
		  }
	       }
	    }
	}
    }
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

=item   C<debuglevel()>

Set or retrieve the debug level. Not yet used.

=cut

sub debuglevel()
   {
   my $self=shift;

   @_ ? $self->{SCRAM_DEBUG} = shift # Modify or
      : $self->{SCRAM_DEBUG};        # retrieve
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

=item   C<toolmanager($location)>

Reload the BuildSystem::ToolManager object from the tool cache file.
   
=cut

sub toolmanager()
   {
   my $self = shift;
   my ($location)=@_;
   $location||=$self->localarea();
   
   if (!exists $self->{toolmanager})
      {
      if ( -r $location->toolcachename() )
         {
         # Cache exists, so read it:
         $self->info("Reading tool data from ToolCache.db.gz") if ($self->{SCRAM_DEBUG});
         use Cache::CacheUtilities;
         $self->{toolmanager}=&Cache::CacheUtilities::read($location->toolcachename());
         $self->{toolmanager}->initpathvars();
         }
      else
         {
	 print STDERR "You are trying to build/setup tools for SCRAM_ARCH $ENV{SCRAM_ARCH}.\n",
	       "while your project area is currently setup for following SCRAM_ARCH(s):\n";
	 my $archs = $self->availablearch ($location->location());
         if (scalar(@$archs)>0){print STDERR "\t",join("\n\t",@$archs),"\n";}
         else{print STDERR "  No tools setup for any SCRAM_ARCH (seems like your area is curpted).\n";}
	 print STDERR "Please make sure your SCRAM_ARCH environment variable is correct.\n";
	 exit 1;
         }
      }
   return $self->{toolmanager};
   }

=item   C<checklocal()>

Check that the current area is a project area and continue or exit otherwise.

=cut

sub checklocal()
   {
   my $self=shift;
   $self->scramfatal("Unable to locate the top of local release. Please run this command from a SCRAM-based area."), if (! $self->islocal());   
   }

=item   C<checkareatype()>

Check that the current area is a SCRAM Version 1.0 series project area and continue or exit otherwise.

=cut
   
sub checkareatype()
   {
   my $self=shift;
   my ($areapath, $message)=@_;
   my $version=$self->versioninfile($areapath."/".$ENV{SCRAM_CONFIGDIR});
   if ($version=~/^V0/){$self->scramfatal($message);}
   }

sub scramprojectdb {
	my $self=shift;
        if ( ! defined $self->{scramprojectsdb} ) {
          require SCRAM::ScramProjectDB;
          $self->{scramprojectsdb}=SCRAM::ScramProjectDB->new();
        }
        return $self->{scramprojectsdb};
}

sub versioninfile
   {
   my $self=shift;
   my $area=shift;
   my $versionfile="${area}/scram_version";
   my $version=undef;
   if ( -f "${area}/scram_version" )
      {
      open (VERSION, "< ${area}/scram_version");
      $version=<VERSION>;
      close(VERSION);
      chomp $version;
      }
   return $version;
   }

sub spawnversion
   {
   my $self=shift;
   my $version=shift;
   my $rv=0;

   if (defined $version)
      {
      $ENV{SCRAM_VERSION}=~/^V(\d+)_(\d+)_\d+.*$/o;
      my $cmajor=$1; my $cminor=$2;
      $version=~/^V(\d+)_(\d+)_\d+.*$/o;
      my $nmajor=$1; my $nminor=$2;
      if (($cmajor != $nmajor) ||
          (($cmajor<3) && ($cminor != $nminor) && (($cmajor<2) || ($cminor<2) || ($nminor<2))))
	 {
	 $ENV{SCRAM_VERSION}=$version;
	 $self->verbose("Spawning SCRAM version $version");
	 my $rv=system("scram", @$main::ORIG_ARGV)/256;
	 exit $rv;
	 }
      }
   else
      {
      $self->error("Undefined value for version requested");
      $rv=1;
      }
   return $rv;
   }
   
sub availablearch
   {
   my $self=shift;
   my $dir=shift || "$ENV{LOCALTOP}";
   my $toolbox = "${dir}/$ENV{SCRAM_CONFIGDIR}/toolbox";
   my $archs=[];
   if (-d $toolbox)
      {
      my $dref;
      opendir($dref,$toolbox) || die "Can not open directory for reading: $toolbox";
      foreach my $dir (readdir ($dref)) 
         {
	 if ($dir=~/^\./){next;}
	 if (-d "${toolbox}/${dir}/tools") {push @$archs,$dir;}
	 }
      closedir($dref);
      }
   return $archs;
   }

sub cmsos {
  my $os=`$main::installPath/common/cmsos`; chomp $os;
  $os=~s/_.*$//;
  return $os;
}

sub classverbose {
	my $self=shift;
	my $class=shift;
	my $val=shift;

	$ENV{"VERBOSE_".$class}=$val;
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
   print STDERR "SCRAM ",$self->fatal(@_),"\n";
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
      $self->classverbose($class,1);
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
   $usage.="***************************************************\n";
   $usage.="SCRAM HELP ------------- Recognised Commands\n";
   $usage.="***************************************************\n";
   $usage.="\n";
   map { $usage.="\t$::bold scram ".$_."$::normal\n"  } $self->showcommands();
   $usage.="\n";
   $usage.= "See scram manual pages for detail documentation about these commands.\n";
   return $usage;
   }

#### End of SCRAM.pm ####
1;


=back

=head1 AUTHOR/MAINTAINER

Shaun ASHBY 

=cut

