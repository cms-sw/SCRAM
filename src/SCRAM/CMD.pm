#____________________________________________________________________ 
# File: CMD.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-24 10:28:14+0200
# Revision: $Id: CMD.pm,v 1.77.2.4 2008/04/15 07:55:34 muzaffar Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------

=head1 NAME

SCRAM::CMD - Package containing all SCRAM command functions.

=head1 METHODS

=over

=cut

package SCRAM::CMD;
require 5.004;
use Exporter;
use Utilities::Verbose;
use SCRAM::MsgLog;
use Getopt::Long ();

@ISA=qw(Exporter Utilities::Verbose);
@EXPORT_OK=qw();

=item   C<urlget($url)>

Retrieve URL information. For example, show location in the cache
of a local copy of a Tool Document.

=cut

sub urlget()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('urlget'); exit(0) } );

   local @ARGV = @ARGS;

   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram urlget -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();      
      my $url = shift(@ARGV);
      my ($uurl,$file)=$self->scramfunctions()->webget($self->localarea(),$url);

      if ($file)
	 {
	 print "$file\n";
	 }
      else
	 {
	 $self->scramwarning("No file for URL found locally.");   
	 }
      }
   
   # Return nice value:
   return 0;
   }

=item   C<arch()>

Print the current SCRAM_ARCH to STDOUT.
   
=cut

sub arch()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('arch'); exit(0) } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram arch -help\" for usage info.");
      }
   else
      {
      print $self->architecture(),"\n";
      # Return nice value:
      return (0);
      }
   }

sub tool()
   {
   my $self=shift;
   my (@ARGS) = @_;
   local @ARGV = @ARGS;
   my $rval=0;
   my %opts;
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('tool'); exit(0) } );
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram tool -help\" for usage info.");
      }
   else
      {
      my $cmd = shift(@ARGV);

      if (!$cmd)
	 {
	 $self->scramfatal("Error parsing arguments. See \"scram tool -help\" for usage info.");
	 }
      
      $cmd =~ tr/A-Z/a-z/; # Make sure we have lower case
      my $status=1;
      
      map
	 {
	 if ( $_ =~ /^$cmd/i)
	    {
	    my $subcmd="tool".$_;
	    $status=0; # Command found so OK;
	    $rval = $self->$subcmd(@ARGV);
	    }
	 } qw( list info tag remove template );
      
      # Print help and exit if no command matched:
      if ($status)
	 {
	 $self->scramfatal("Unknown command argument. See \"scram tool -help\" for usage info.");
	 $rval = 1;
	 }
      }
   
   # Return nice value:
   return $rval;
   }

=item   C<toollist()>

Print the list of tools that are set up for the current architecture.
   
=cut

sub toollist()
   {
   my $self=shift;
   # Check to see if we are in a local project area:
   $self->checklocal();
   
   # Get array of setup tools:
   my @setuptoolnames = $self->toolmanager()->toolsdata();
   
   # Exit if there aren't any tools:
   $self->scramerror(">>>> No tools set up for current arch or area! <<<<"),if ( $#setuptoolnames < 0); 
   
   # We have some tools:
   my $locationstring="Tool list for location ".$self->localarea()->location();
   my $length=length($locationstring);
   
   print "\n",$locationstring,"\n";
   print "+"x $length;
   print "\n";
   print "\n";
   
   # Show list:
   foreach $t (@setuptoolnames)
      {
      printf " %-20s %-10s\n",$t->toolname(),$t->toolversion();
      }
   
   print "\n";
   # Return nice value:
   return 0;
   }

=item   C<toolinfo($toolname)>

Print the information for tool $toolname.
   
=cut

sub toolinfo()
   {
   my $self=shift;
   my ($toolname)=@_;

   $toolname =~ tr/A-Z/a-z/; # Make sure we have lower case toolname

   $self->scramfatal("No tool name given: see \"scram tool -help\" for usage info."), if (!$toolname);

   # Check to see if we are in a local project area:
   $self->checklocal();
   
   # Get array of setup tools:
   my @setuptoolnames = $self->toolmanager()->toolsdata();
   
   # Exit if there aren't any tools:
   $self->scramerror(">>>> No tools set up for current arch or area! <<<<"),if ( $#setuptoolnames < 0); 

   # Get the setup tool object:
   if ($sut=$self->toolmanager()->checkifsetup($toolname))
      {
      # If we have a setup tool:
      my $locationstring="Tool info as configured in location ".$self->localarea()->location();
      my $length=length($locationstring);
      
      print $locationstring,"\n";
      print "+"x $length;
      print "\n";
      print "\n";
      print "Name : ".$sut->toolname();
      print "\n";
      print "Version : ".$sut->toolversion();
      print "\n";
      print "+"x20;
      print "\n";
      $sut->summarize_features();
      }
   else
      {
      $self->scramerror(">>>> Tool ".$toolname." is not defined for this project area. <<<<");
      exit(1);
      }
   
   # Return nice value:
   return 0;
   }

=item   C<tooltag($toolname [,$tagname])>

Print the list of defined variables (tags) for the current tool. These tags
can include B<LIB>, B<LIBDIR>, B<INCLUDE> and B<T_BASE> (where B<T> is the tool name).
If the optional tagname $tagname is given, only the setting for this one tag will
be shown.
   
=cut

sub tooltag()
   {
   my $self=shift;
   my ($toolname,$tagname) = @_;
   chomp ($tagname);
   $toolname =~ tr/A-Z/a-z/; # Make sure we have lower case toolname

   # Check to see if we are in a local project area:
   $self->checklocal();

   # Get array of setup tools:
   my @setuptoolnames = $self->toolmanager()->toolsdata();
  
   $self->scramerror(">>>> No tools set up for current arch or area! <<<<"),if ( $#setuptoolnames < 0); 
   $self->scramfatal("No tool name given: see \"scram tool -help\" for usage info."), if (!$toolname);

   # Get the setup tool object:
   if ($sut=$self->toolmanager()->checkifsetup($toolname))
      {
      $sut->getfeatures($tagname);
      }
   else
      {
      $self->scramerror(">>>> Tool ".$toolname." is not defined for this project area. <<<<");
      exit(1);
      }
   
   # Return nice value:
   return 0;
   }

=item   C<toolremove($toolname)>

Remove the configured tool $toolname from the current configuration.
   
=cut

sub toolremove()
   {
   my $self=shift;
   my ($toolname) = @_;

   $toolname =~ tr/A-Z/a-z/; # Make sure we have lower case toolname
  
   # Check to see if we are in a local project area:
   $self->checklocal();

   # Get array of setup tools:
   my @setuptoolnames = $self->toolmanager()->toolsdata();
    
   $self->scramerror(">>>> No tools set up for current arch or area! <<<<"),if ( $#setuptoolnames < 0); 
   $self->scramfatal("Not enough args: see \"scram tool -help\" for usage info."), if (!$toolname);
   
   if ($sut=$self->toolmanager()->checkifsetup($toolname))
      {
      print "Removing tool ",$toolname," from current project area configuration.","\n";
      # Remove the entry from our setup tools list:
      $self->toolmanager()->remove_tool($toolname);	 
      }
   else
      {
      $self->scramerror(">>>> Tool ".$toolname." is not defined for this project area. <<<<");
      exit(1);
      }
   
   # Return nice value:
   return 0;
   }

=item   C<install()>

Install the current project in the local SCRAM project database so that it will
be listed by C<scram list>.
   
=cut

sub install()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts = ( SCRAM_FORCE => 0 );
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('install'); exit(0) },
       "force|f"  => sub { $opts{SCRAM_FORCE} = 1 } );

   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram install -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();
      # Check to make sure that the project is a SCRAM V1 project:
      $self->checkareatype($self->localarea()->location(),"Area type mismatch. Trying to execute a SCRAM command in a V0 project area using a V1x version of SCRAM. Exiting.");
      
      # Install the project:
      my $project = shift(@ARGV);
      my $projectversion = shift(@ARGV);
      $self->scramfunctions()->addareatoDB($opts{SCRAM_FORCE},$self->localarea(),$project,$projectversion);

      # Also touch a register file called .installed in .SCRAM/<arch>:
      $self->register_install();
      # Return nice value:
      return 0;
      }
   }

=item   C<remove($project,$projectversion)>

Remove project $project version $projectversion from the local
SCRAM project database.

=cut

sub remove()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts = ( SCRAM_FORCE => 0 );
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('remove'); exit(0) },
       "force|f"  => sub { $opts{SCRAM_FORCE} = 1 } );

   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram remove -help\" for usage info.");
      }
   else
      {
      # Remove the project:
      my $project = shift(@ARGV);
      my $projectversion = shift(@ARGV);
      
      if ($project eq "" || $projectversion eq "")
	 {
	 $self->scramfatal("Error parsing arguments. See \"scram remove -help\" for usage info.");	 
	 }
      else
	 { 
	 $self->scramfunctions()->removeareafromDB($opts{SCRAM_FORCE},$project,$projectversion);
	 # Remove the .installed file:
	 $self->unregister_install();
	 }
      
      # Return nice value:  
      return 0;
      }
   }

=item   C<version([ $version ])>

Print the version of SCRAM. If $version argument is given, run $version of SCRAM.
Install locally if it is not already available.
   
=cut

sub version()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('version'); exit(0) });
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram version -help\" for usage info.");
      exit(1);
      }
   else
      {
      print $ENV{SCRAM_VERSION},"\n";
      }
   
   # Return nice value: 
   return 0;
   }

=item   C<list()>

List the projects which are currently installed at the local site. Developer
areas can be created from any of the projects listed by this command.
   
=cut

sub list()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help|h"	 => sub { $self->{SCRAM_HELPER}->help('list'); exit(0) },
       "oldstyle|o" => sub { $opts{SCRAM_OLDSTYLE} = 1 },
       "compact|c" => sub { $opts{SCRAM_LISTCOMPACT} = 1 } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram list -help\" for usage info.");
      exit(1);
      }
   else
      {
      my $pjname = "Project Name";
      my $pjversion = "Project Version";
      my $pjlocation = "Project Location";
      my $headstring = sprintf("| %-12s  | %-24s | %-33s |",$pjname,$pjversion,$pjlocation);
      my @missingareas;
      my $projectexists=0;
      my $linebold = "$::bold"."$::line"."$::normal";
      
      # First, test to see if there is a SCRAMDB:
      $self->scramerror("No installation database available - perhaps no projects have been installed locally?"),
      if ( ! -f $ENV{SCRAM_LOOKUPDB});
      
      # The project data:
      my $project = shift(@ARGV);
      my $projectversion = shift(@ARGV);
      
      # get all project data from  SCRAMDB:
      my @projects = $self->getprojectsfromDB();
      # We say goodbye if there aren't any projects installed:
      $self->scramerror(">>>> No locally installed projects! <<<<"), if ( $#projects < 0);

      # Otherwise, we continue. First, we see if the option SCRAM_OLDSTYLE is set. If so, we show all
      # projects (V0_x ones too) in the same manner as other SCRAM versions. If not, we use the new
      # mechanism which checks only for the .installed file.      
      # Iterate over the list of projects:
      foreach my $pr (@projects)
	 {
	 my $url='NULL';	 
	 if ( $project  eq "" || $project eq $$pr[0] )
	    {
	    # Check that the area exists (i.e. check that a configarea object
	    # is returned before attempting to test its' location):
	    my $possiblearea=$self->scramfunctions()->scramprojectdb()->getarea($$pr[0],$$pr[1]);
	    $url=$possiblearea->location(), if (defined ($possiblearea));
	    
	    if ($opts{SCRAM_OLDSTYLE})
	       {
	       # See if area is readable:
	       if ( -d $url)
		  {
		  # Check path to project:
		  if ( -d "$url/bin/$ENV{SCRAM_ARCH}" || 
		       -d "$url/lib/$ENV{SCRAM_ARCH}" || -d "$url/$ENV{SCRAM_ARCH}/lib")
		     {
		     if ($project eq $$pr[0])
			{
			$projectexists=1;
			} # We've found at least one project
		     my $pstring = sprintf "  %-15s %-25s  \n%45s%-30s\n",$$pr[0],$$pr[1],"--> ",$::bold.$url.$::normal;
		     $pstring = sprintf "%-15s %-25s %-50s\n",$$pr[0],$$pr[1],$url, if ($opts{SCRAM_LISTCOMPACT});
		     push(@foundareas,$pstring);
		     }
		  }
	       else
		  {
		  # Area is missing:
		  if ($url ne 'NULL')
		     {
		     push(@missingareas,sprintf ">>  Project area MISSING:   %-10s %-20s  \n",$$pr[0],$$pr[1]);
		     }
		  }
	       }
	    else
	       {
	       # The new mechanism. We see if project was registered:
	       # See if area is readable:
	       if ( -d $url)
		  {
		  if ($self->isregistered($possiblearea))
		     {
		     if ($project eq $$pr[0])
			{
			$projectexists=1;
			} # We've found at least one project
		     my $pstring = sprintf "  %-15s %-25s  \n%45s%-30s\n",$$pr[0],$$pr[1],"--> ",$::bold.$url.$::normal;
		     $pstring = sprintf "%-15s %-25s %-50s\n",$$pr[0],$$pr[1],$url, if ($opts{SCRAM_LISTCOMPACT});
		     push(@foundareas,$pstring);
		     }
		  }
	       else
		  {
		  # Area is missing:
		  if ($url ne 'NULL')
		     {		     
		     push(@missingareas,sprintf ">>  Project area MISSING:   %-10s %-20s  \n",$$pr[0],$$pr[1]);
		     }
		  }
	       }
	    }
	 }
      
      # Now dump out the info:
      if ($opts{SCRAM_LISTCOMPACT})
	 {
	 $self->scramerror(">>>> No locally installed $project projects! <<<<"),
	 if ( ! $projectexists && $project ne "");
	 
	 foreach $p (@foundareas)
	    {
	    print $p;
	    }
	 }
      else
	 {
	 # If there weren't any projects of the name given found:
	 $self->scramerror(">>>> No locally installed $project projects! <<<<"),
	 if ( ! $projectexists && $project ne "");
	 
	 # Otherwise, dump the info:
	 print "\n","Listing installed projects....","\n\n";
	 print $linebold,"\n";
	 print $headstring."\n";
	 print $linebold,"\n\n";
	 
	 foreach $p (@foundareas)
	    {
	    print $p;
	    }
	 
	 print "\n\n","Projects available for platform >> ".$::bold."$ENV{SCRAM_ARCH}".$::normal." <<\n";
	 print "\n";
	 }
      
      # Error if there were missing areas:
      $self->scramerror("\n",@missingareas), if ( $#missingareas > -1 );
      }
   
   # Otherwise return nicely:
   return 0;
   }

=item   C<db()>

Show the location of the local SCRAM project database and any other databases that are linked.
   
=cut

sub db()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts = ( SCRAM_DB_SHOW => 0, SCRAM_DB_LINK => 0, SCRAM_DB_UNLINK => 0 );
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('db'); exit(0) },
       "show|s"   => sub { $opts{SCRAM_DB_SHOW} = 1 },
       "link|l"   => sub { $opts{SCRAM_DB_LINK} = 1 },
       "unlink|u" => sub { $opts{SCRAM_DB_UNLINK} = 1 } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram db -help\" for usage info.");
      }
   else
      {
      # First, test to see if there is a SCRAMDB:
      $self->scramerror("No installation database available - perhaps no projects have been installed locally?"),
      if ( ! -f $ENV{SCRAM_LOOKUPDB});

      my $db=shift(@ARGV);
      
      # Check the options and do something useful:   
      if ($opts{SCRAM_DB_LINK})
	 {
	 if ( -f $db )
	    {
	    print "Current SCRAM database: ",$::bold.$ENV{SCRAM_LOOKUPDB}.$::normal,"\n";
	    $self->scramfunctions()->scramprojectdb()->link($db); 
	    print "\n","Linked ",$db," to current SCRAM database.","\n\n";
	    }
	 else
	    {
	    $self->scramerror("No valid DB file given as argument. See \"scram db -help\" for usage info.");
	    }
	 }
      elsif ($opts{SCRAM_DB_UNLINK})
	 {
	 if ( -f $db )
	    {
	    print "Current SCRAM database: ",$::bold.$ENV{SCRAM_LOOKUPDB}.$::normal,"\n";
	    $self->scramfunctions()->scramprojectdb()->unlink($db); 
	    print "\n","Unlinked ",$db," from current SCRAM database.","\n\n";
	    }
	 else
	    {
	    $self->scramerror("No valid DB file given as argument. See \"scram db -help\" for usage info.");
	    }
	 }
      elsif ($opts{SCRAM_DB_SHOW})
	 {
	 print "Current SCRAM database: ",$::bold.$ENV{SCRAM_LOOKUPDB}.$::normal,"\n";
	 my @links=$self->scramfunctions()->scramprojectdb()->listlinks();
	 if (defined (@links))
	    {
	    print "\n","The following SCRAM databases are linked to the current database: ","\n\n";
	    foreach my $extdb (@links)
	       {
	       print "\t".$extdb."\n";
	       }
	    print "\n";
	    }
	 else
	    {
	    print "There are no SCRAM databases linked.","\n";
	    }
	 }
      else
	 {
	 # Didn't get a sensible sub-command:
	 $self->scramfatal("Unknown option: see \"scram db -help\" for usage info.");
	 }
      }
   
   # Return nice value:
   return 0;
   }

=item   C<build()>

Compile the source code in the current project area. 
   
=cut

sub build()
   {
   my $self=shift;
   
   # The cache files:
   my $wrkdir = $ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH};
   my $toolcache="${wrkdir}/ToolCache.db";
   my $dircache="${wrkdir}/DirCache.db";
   my $builddatastore="${wrkdir}/ProjectCache.db";
   
   # The directories:
   my $workingdir=$ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork};
   my $configbuildfiledir=$ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR};

   my $fast=0;
   my $makefilestatus=0;
   my ($packagebuilder,$dataposition,$buildstoreobject);
   my $verbose=0;
   my $trap_flag=0;
   my $cachereset = 0;
   if (!-e "$workingdir"){$cachereset=1; print "Resetting caches","\n"; system("rm","-f",$builddatastore);} 
   
   # Getopt variables:
   my %opts = ( SCRAM_TEST => 0 ); # test mode: don't run make;
   my $convertxml = 0;
   my %options =
      ("help|h"     => sub { $self->{SCRAM_HELPER}->help('build'); exit(0) },
       "verbose|v"  => sub { $ENV{SCRAM_BUILDVERBOSE} = 1 },
       "testrun|t"  => sub { $opts{SCRAM_TEST} = 1 },
       "reset|r"    => sub { if ($cachereset==0){ $cachereset=1; print "Resetting caches","\n"; system("rm","-rf",$builddatastore,"${workingdir}/MakeData/DirCache* ${workingdir}/MakeData/ExtraBuilsRules")}},
       "fast|f"     => sub { print "Skipping cache scan...","\n"; $fast=1 },
       "convertxml|c"  => sub { $convertxml =1 },
       "xmlb|x"     => sub {$ENV{SCRAM_XMLBUILDFILES} = 1; print "SCRAM: Will read XML versions of your BuildFiles.","\n" } );
   
   local (@ARGV) = @_;

   # Set the options:
   Getopt::Long::config qw(default no_ignore_case require_order pass_through bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram build -help\" for usage info.");
      }
   else
      {

      # BuildSystem::Make object created here to handle args passed to gmake:
      use BuildSystem::MakeInterface;
      my $MAKER = BuildSystem::MakeInterface->new(@ARGV);

      if ($convertxml || $cachereset){$fast=0;}
      # Check to see if we are in a local project area, then set the
      # runtime environment. The environments are set in %ENV:
      $self->checklocal();
      $self->runtimebuildenv_();
      $self->create_productstores($ENV{LOCALTOP});
      # Set location variables:
      use Cwd;
      my $current_dir = cwd();
      
      # Set THISDIR. If we have a full match on LOCALTOP, set THISDIR to src:
      ($ENV{THISDIR}) = ($current_dir =~ m|^\Q$ENV{LOCALTOP}\E/(.*)$|);
      if ($ENV{THISDIR} eq '')
	 {
	 $ENV{THISDIR} = $ENV{SCRAM_SOURCEDIR};
	 }
      
      # Set up file cache object:
      use Cache::Cache;
      use Cache::CacheUtilities;      
      use Utilities::AddDir;

      my $cacheobject=Cache::Cache->new();
      my $cachename=$cacheobject->name($dircache);

      # Where to search for BuildFiles (from src):
      chdir($ENV{LOCALTOP});
      # Create the working dir if it doesn't exist
      Utilities::AddDir::adddir($workingdir), if (! -d $workingdir);

      if ( -r $cachename )
	 {
	 print "Reading cached data","\n",if ($ENV{SCRAM_DEBUG});
	 $cacheobject=&Cache::CacheUtilities::read($cachename);
	 }
      elsif (-x "$ENV{SCRAM_CONFIGDIR}/ProjectInit")
         {
	 print "Running $ENV{SCRAM_CONFIGDIR}/ProjectInit script","\n",if ($ENV{SCRAM_DEBUG});
	 my $rv = system("$ENV{SCRAM_CONFIGDIR}/ProjectInit");
	 print "Script exitted with status ",$rv,"\n",if ($ENV{SCRAM_DEBUG});
         }

      # Set verbosity for cache object:
      $cacheobject->verbose($ENV{SCRAM_CACHEDEBUG});
      # Check for BuildFiles (config dir and src) and track timestamps of contents
      # of config dir (templates, for example):
      $cacheobject->checkfiles($cachereset,$convertxml) unless $fast;
      
      #if asked for xml based file creation then no need to run make
      if ($convertxml)
         {
	 my $nonxml=$cacheobject->get_nonxml();
	 if ($nonxml == 0)
	    {
	    print "There are no Non-XML based BuildFiles.\n";
	    }
         else
	    {
	    print "$nonxml Non-XML based BuildFile(s) processed.\n";
	    }
	 return 0;
	 }
            
      # Now check the file status (BuildFiles in src tree) and config
      # file status (contents of config dir). We only reparse everything
      # and rebuild the makefiles if something changed:
      if ($cacheobject->cachestatus())
	 {
	 my $buildfiles = $cacheobject->get_data("ADDEDBF");
	 my $filecache = $cacheobject->dircache();
	 # Arrayref pointing to list of changed parent dirs:
	 my $changeddirs = $cacheobject->modified_parentdirs();
	 # Array of added dirs:
	 my $addeddirs = $cacheobject->added_dirs();
	 # Array of files removed:
	 my $removedfiles = $cacheobject->schedremoval();
	 
	 use BuildSystem::BuildDataStorage;
	 $buildstoreobject=BuildSystem::BuildDataStorage->new($configbuildfiledir);
	 $buildstoreobject->name($builddatastore);
	 # Install a handler for SIGINT. This is done here becuase this is the block in which
	 # the cache will be modified and written back. Anywhere in this process, the cache can
	 # be corrupted if a user hits ctrl-c. By trapping this, we at least force the block to
	 # continue until the cache is written before exit:
	 $SIG{INT}  = sub
	    {
	    ($trap_flag == 0) ? $trap_flag = 1 : $trap_flag;
	    print $::bold."\nUser interrupt: Writing cache before exit.\n".$::normal;
	    };
	 
	 
	 if ( -r $builddatastore)    
	    {
	    print "Reading cached build data","\n";
	    $buildstoreobject=&Cache::CacheUtilities::read($builddatastore);
	    }
	    # Update- check for changed or removed files. Also need to account for removed directories:
	 if (!$buildstoreobject)
	    {
	    # Report an error and exit (implies that cache has disappeared):
	    $self->scramerror("SCRAM: .SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db missing. Use \"-r\".");
	    exit(1);
	    }
	    
	 $buildstoreobject->init_engine(); # Restart the template engine

	 # Run in update mode:
	 $buildstoreobject->update($cacheobject);
	 
	 # Now write to the file cache. From here on, we're done with it:
	 print "\nUpdating cache","\n",if ($ENV{SCRAM_DEBUG});
	 $cacheobject->cachestatus(0); # We've updated the cache so reset the status
	 &Cache::CacheUtilities::write($cacheobject,$cachename);
	 
	 # Write to build data cache:
	 $buildstoreobject->save();
	 print "\nUpdating build cache","\n",if ($ENV{SCRAM_DEBUG});
	 $buildstoreobject->cachestatus(0);
 	 &Cache::CacheUtilities::write($buildstoreobject,$builddatastore);
 	 # Exit cleanly here if ctrl-c was given:
	 if ($trap_flag == 1)
	    {
	    print $::bold."\nExiting on Ctrl-C.\n\n".$::normal,
	    exit(0);
	    }
	 
	 # At this point, all the data will have been processed and Makefiles generated.
	 # So here's where we will run gmake (use -r to turn of implicit rules):
	 my $returnval = $MAKER->exec($ENV{SCRAM_INTwork}."/Makefile"),
	 if (! $opts{SCRAM_TEST});
	 print "MAKE not actually run: test build mode!","\n",if ($opts{SCRAM_TEST});

	 # Return a value:
	 return $returnval;
	 }
      else
	 {
	 print "No changes to the cache....","\n",if ($ENV{SCRAM_DEBUG});
	 # Everything is already up-to-date so we just build. Check to make sure we really
	 # have a Makefile (it might've been cleaned away somehow):
	 if ( -f $ENV{SCRAM_INTwork}."/Makefile")
	    {
	    my $returnval = $MAKER->exec($ENV{SCRAM_INTwork}."/Makefile"),
	    if (! $opts{SCRAM_TEST});
	    print "MAKE not actually run: test build mode!","\n",if ($opts{SCRAM_TEST});

	    # Return a value:
	    return $returnval;
	    }
	 else
	    {
	    $self->scramerror("SCRAM: No Makefile in working dir. \nPlease delete .SCRAM/".
			      $ENV{SCRAM_ARCH}."/ProjectCache.db then rebuild.");
	    exit(1);
	    }
	 }
      }
   
   # Return nice value:
   return 0;
   }

=item   C<project()>
   
Create a SCRAM developer area or bootstrap a new SCRAM project area.

=cut

sub project()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my ($installdir, $installname);
   my ($toolconf,$bootfile,$bootstrapfile);
   my $symlinks=0;
   my %opts = (
	       SCRAM_INSTALL_DIR => 0,
	       SCRAM_INSTALL_NAME => 0,
	       SCRAM_TOOLCONF_NAME => 0,
	       SCRAM_UPDATE_AREA => 0,
	       SCRAM_BOOTSTRAPFILE_NAME => 0
	       );
   # Here are the options for the project command. We need to support changing the location
   # of the new installation and cloning a release (and possibly giving it a new name).
   # So the -dir option is used to give a directory as the installation dir (if unused, cwd is the default).
   # 
   # Note that it only makes sens to use the -name option when cloning since it would seem silly
   # to be bootstrapping a new project and then wanting to change its name (after all, one could
   # just do this in the bootfile!):
   #
   scramloginteractive(0);
   my %options =
      ("help|h"   => sub { $self->{SCRAM_HELPER}->help('project'); exit(0) },
       "dir|d=s"  => sub { $opts{SCRAM_INSTALL_DIR} = 1; $installdir = $_[1] },
       "name|n=s" => sub { $opts{SCRAM_INSTALL_NAME} = 1; $installname = $_[1] },
       "file|f=s" => sub { $opts{SCRAM_TOOLCONF_NAME} = 1; $toolconf = $_[1] },
       "update|u" => sub { $opts{SCRAM_UPDATE_AREA} = 1 },
       "log|l"    => sub { scramloginteractive(1); },
       "symlinks|s"=> sub { $symlinks=1; },
       "boot|b=s" => sub { $opts{SCRAM_BOOTSTRAPFILE_NAME} = 1; $bootstrapfile = 'file:'.$_[1]; $bootfile = $_[1] }
       );

   local @ARGV = @ARGS;
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram project -help\" for usage info.");
      }
   else
      {
      # Check install dir/name:
      use Cwd;
      $installdir ||= cwd(); # Current working dir unless set above
      
      # Check to see which type of boot we should do or whether we should do an update:
      if ($opts{SCRAM_UPDATE_AREA})
	 {
	 # See if we hav a version arg:
	 my $projectversion = shift(@ARGV);
	 # We must be in a project area to start with:
	 $self->checklocal();
	 $self->update_project_area($installdir, $projectversion);
	 }
      elsif ($opts{SCRAM_BOOTSTRAPFILE_NAME})
	 {
	 $self->bootnewproject($bootstrapfile,$installdir,$toolconf);
	 }
      else
	 {
	 my $projectname = shift(@ARGV);
	 my $projectversion = shift(@ARGV);	 
	 $self->bootfromrelease($projectname,$projectversion,$installdir,$installname,$toolconf,$symlinks);
	 }     
      }
   
   # Return nice value:
   return 0;
   }

=item   C<bootfromrelease()>

Function to create a developer area from an existing release (only used locally).
   
=cut

sub bootfromrelease() {
    my $self=shift;
    my ($projectname,$projectversion,$installdir,$installname,$toolconf,$symlinks) = @_;
    
    if ($projectname && $projectversion) {
	my $relarea=$self->scramfunctions()->scramprojectdb()->getarea($projectname,$projectversion);
	
	if ( ! defined $relarea ) {
	    print "Error...no release area!","\n";
	    $self->scramfatal("No release area found.");
	} else {
	    # Here we check the scram version that was used for the remote project area (the one we're trying
	    # to base a developer area on). We then invoke whichever version is required and pass all argumnents
	    # on down:
	    $self->remote_versioncheck($relarea,"project",$projectname,$projectversion,$installdir,$installname,$toolconf);	    
	}	

	# From here, we're creating a new area which uses the same version of SCRAM as is accessed from the commandline (i.e.
	# the current version):
	scramlogclean();
	scramlogmsg("Creating a developer area based on project ",$projectname,", version ",$projectversion,"\n");

	# Set RELEASETOP:
	$ENV{RELEASETOP} = $relarea->location();	
	# Set the var for project name and version:
	$ENV{SCRAM_PROJECTNAME} = $projectname;
	$ENV{SCRAM_PROJECTVERSION} = $projectversion;
	
	# Check that the areas are compatible:
	$self->checkareatype($ENV{RELEASETOP},"Project release area SCRAM version mismatch: current is V1, area is V0. Exiting.");
	$area=$self->scramfunctions()->satellite($projectname,$projectversion,$installdir,$installname,$symlinks);
	$ENV{SCRAM_CONFIGDIR} = $area->configurationdir();
	
	# Read the top-level BuildFile and create the required storage dirs. Do
	# this before setting up self:
	$self->create_productstores($area->location(),$symlinks);
	# The lookup db:
	use SCRAM::AutoToolSetup;
	
	$toolconf ||= $area->location()."/".$ENV{SCRAM_CONFIGDIR}."/site/tools.conf";
	$::lookupdb = SCRAM::AutoToolSetup->new($toolconf);  
	# Need a toolmanager, then we can setup:

	my $toolmanager = $self->toolmanager($area);
	$toolmanager->setupself($area->location());

	# Write the cached info:
	$toolmanager->writecache();
	
        my $temp=$area->location()."/".$area->{admindir}."/".$area->arch();
        if (-f "${temp}/MakeData/Tools.mk")
           {
           my $t1=(stat("${temp}/MakeData/Tools.mk"))[9];
           if (-e "${temp}/timestamps")
              {
              my $t2=(stat("${temp}/MakeData/Tools.mk"))[9];
              utime $t2+1,$t2+1,"${temp}/MakeData/Tools.mk";
              if (-f "${temp}/timestamps/self")
                 {
                 utime $t2+2,$t2+2,"${temp}/timestamps/self";
                 }
              }
           }
	
	scramlogmsg("\n\nInstallation procedure complete.\n");
	scramlogmsg("Developer area located at:\n\n\t\t".$area->location()."\n\n");
	#scramlogdump();
    } else {
	$self->scramfatal("Insufficient arguments: see \"scram project -help\" for usage info.");
    }
    
    # Return nice value:
    return 0;
}

=item   C<bootnewproject()>

Function to create a new SCRAM project area from a boot file (only used locally).

=cut

sub bootnewproject()
   {
   my $self=shift;
   my $areaname="";
   my ($bootstrapfile,$installarea,$toolconf)=@_;

   use SCRAM::AutoToolSetup;
   use BuildSystem::ToolManager;
   use Configuration::Requirements;
   use Configuration::BootStrapProject;
   use ActiveDoc::ActiveStore;
   # Set up a cache (old-style, for URLs):
   my $globalcache = URL::URLcache->new($ENV{HOME}."/.scramrc/globalcache");
   
   # Set up the bootstrapper:
   my $bs=Configuration::BootStrapProject->new($globalcache, $installarea);
   my $area=$bs->boot($bootstrapfile, $installarea);

   $area->archname($ENV{'SCRAM_ARCH'});

   my $name=$area->location();
   my $doc=$area->requirementsdoc();
   my $cache=$area->cache();
   my $db=$area->objectstore();
   my $astore=ActiveDoc::ActiveStore->new($db, $cache);
   my $req = Configuration::Requirements->new($astore, "file:".$doc, 
					      $ENV{SCRAM_ARCH});

   $area->toolboxversion($req->configversion());

   # Add ToolManager object to store all tool info:
   my $toolmanager = BuildSystem::ToolManager->new($area, $ENV{SCRAM_ARCH});

   # Add the configuration version to the tool manager:
   $toolmanager->configversion($req->configversion());
   
   # Tell the Requirements class that there's a ToolManager to use:
   $req->toolmanager($toolmanager);

   # FIXME: (duplication) Add the configuration version to the tool manager:
   $toolmanager->configversion($req->configversion());
   
   # download the tools:
   $req->download();
   # Need an autotoolssetup object:
   $ENV{'SCRAM_PROJECTDIR'} = $area->location();
   $ENV{'SCRAM_PROJECTVERSION'} = $area->version();
   
   $::lookupdb = SCRAM::AutoToolSetup->new($toolconf);   
   
   # Now run the full setup for the area:
   scramlogmsg("\n","Using SCRAM toolbox version ",$area->toolboxversion(),"\n\n");
   
   # Now set up selected tools:
   scramlogmsg("Setting up tools in project area","\n");
   scramlogmsg("------------------------------------------------\n\n");

   $toolmanager->setupalltools($area->location(),1);

   # Read the top-level BuildFile and create the required storage dirs. Do
   # this before setting up self:
   $self->create_productstores($area->location(),0);
   # Now setup SELF:
   $toolmanager->setupself($area->location());

   # New tm's are not clones:
   $toolmanager->cloned_tm(0);
   # Write the cached info:
   $toolmanager->writecache();
   # Save the area info (toolbox version):
   $area->save();

   scramlogmsg("\n>> Installation Located at: ".$area->location()." <<\n\n");

   # Return nice value:
   return 0;
   }

=item   C<update_project_area()>

Function to update a developer area to a new, compatible, release. A message
is issued to warn if no compatible area exists. Only used internally.
   
=cut

sub update_project_area()
   {
   my $self=shift;
   my ($installdir, $pversion) = @_;
   my %compatvers;

   # Get list of all project versions from database
   # and store the compatible projects in an array.
   # This information is needed whether the user is
   # just querying or actually updating:
   my @pdb = $self->getprojectsfromDB();

   foreach my $p (@pdb)
      {
      # Check the project name and config version matches
      # FIXME: what about the case where area was renamed (-n xx)?
      if ($p->[0] eq $self->projectname() && $p->[1] ne $self->projectversion())
	 {
	 my $parea=$self->scramfunctions()->scramprojectdb()->getarea($p->[0], $p->[1]);

	 if (defined($parea))
	    {
	    if ($parea->toolboxversion() eq $self->configversion())
	       {
	       # Save the corresponding compatible area objects:
	       $compatvers{$p->[1]} = $parea;
	       }
	    }
	 }
      }
   
   # Check to make sure that the returned array is valid, i.e. that there are versions that
   # one can update to:
   print "SCRAM Project update mode: ","\n\n";
   my ($nkeys) = scalar(keys %compatvers);
   if ($nkeys > 0)
      {      
      # If no args then it's a query:
      if (! $pversion)
	 {
	 print "You can update to one of the following versions","\n";
	 print "\n";
	 map
	    {
	    print "\t".$_."\n";
	    } keys %compatvers;
	 }
      else
	 {
	 # Otherwise we try to update to a version:
	 if (grep($pversion eq $_, keys %compatvers))
	    {
	    print "Going to update current area to version ",$pversion,"\n";
	    # Create backup dir with name of current version:
	    use Utilities::AddDir;
	    my $backupdir = $ENV{LOCALTOP}."/.".$self->projectversion();
	    # Delete the dir if the backup already exists (i.e. only
	    # keep last backup):
	    if (-d $backupdir)
	       {
	       system("rm","-rf",$backupdir);
	       }
	    
	    Utilities::AddDir::adddir($backupdir);
	    # Move .SCRAM and config dirs there
	    system("mv",$ENV{SCRAM_CONFIGDIR},$backupdir);
	    system("mv",$self->localarea()->admindir(),$backupdir);

	    # Create the new version. Basically create a satellite area in
	    # the current (i.e. project) area:
	    my $relarea = $compatvers{$pversion};

	    # Set RELEASETOP:
	    $ENV{RELEASETOP} = $relarea->location();
	    $self->versioncheck($relarea->scramversion());

	    # Copy the admin dir (and with it, the ToolCache):   
	    $relarea->copywithskip($ENV{LOCALTOP},['ProjectCache.db','DirCache.db','MakeData/DirCache','MakeData/DirCache.mk','MakeData/src.mk']);
	    # Also, we need to copy .SCRAM/cache from the release area. This eliminates the need
	    # to download tools again from CVS:
	    $relarea->copyurlcache($ENV{LOCALTOP});
	    # Copy the config dir:
	    Utilities::AddDir::copydir($relarea->location()."/".$relarea->configurationdir(),
		      $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR});

	    # Change the project version to the new one:
	    $self->localarea()->version($pversion);
	    # Link to the release area and save the environment data:
	    $self->localarea()->linkarea($relarea);
	    $self->localarea()->save();
	    # The lookup db:
	    use SCRAM::AutoToolSetup;
	    
	    # Default path to conf file:
	    my $toolconf ||= $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR}."/site/tools.conf";
	    $::lookupdb = SCRAM::AutoToolSetup->new($toolconf);  
	    
	    # Update Self and write the updated cache info:
	    my $toolmanager = $self->toolmanager();
	    $toolmanager->setupself($ENV{LOCALTOP}); # FIXME// The toolmanager should be reloaded before setting up self....
	    $toolmanager->writecache();	    
	    print "\n\nUpdate procedure complete.\n";	    
	    }
	 else
	    {
	    print "Version \"".$pversion."\" of ".$self->projectname()." is not valid.","\n";
	    print "\n";
	    return 1;
	    }
	 }
      print "\n";
      }
   else
      {
      print "No compatible versions of ".$self->projectname()." found to update to.","\n";      
      print "\n";
      return 1;
      }
   }

=item   C<create_productstores()>

Create all product storage directories defined in the top-level project
BuildFile (B<config/BuildFile>).

=cut

sub create_productstores()
   {
   my $self=shift;
   my $location = shift;
   my $symlinks=shift;
   
   if ((!defined $symlinks) && (exists $ENV{SCRAM_SYMLINKS})){$symlinks=$ENV{SCRAM_SYMLINKS} || 0;}
   my $sym=0;
   if ($symlinks)
   {
     use SCRAM::ProdSymLinks;
     $sym=new SCRAM::ProdSymLinks();
   }
   
   use BuildSystem::BuildFile;
   use File::Path;
   my $perms=0755;

   my $toplevelconf = BuildSystem::BuildFile->new();
   my $tlbf = $location."/".$ENV{SCRAM_CONFIGDIR}."/".$ENV{SCRAM_BUILDFILE}.".xml";
   if (!-f $tlbf) { $tlbf = $location."/".$ENV{SCRAM_CONFIGDIR}."/".$ENV{SCRAM_BUILDFILE};}
   $toplevelconf->parse($tlbf);
   $ENV{LOCALTOP} ||= $location;
   my $stores = $toplevelconf->productstore();
   
   # Iterate over the stores:
   foreach my $H (@$stores)  
      {
      my $storename="";
      if ($$H{'type'} eq 'arch')
	 {
	 if ($$H{'swap'} eq 'true')
	    {
	    if (exists $$H{'path'})
	       {
	       $storename .= $$H{'path'}."/".$$H{'name'}."/".$ENV{SCRAM_ARCH};
	       mkpath($storename, 0, $perms);
	       symlink $$H{'path'}."/".$$H{'name'},$$H{'name'};
	       }
	    else
	       {
	       $storename .= $$H{'name'}."/".$ENV{SCRAM_ARCH};
	       if (!$sym){mkpath($ENV{LOCALTOP}."/".$storename, 0, $perms);}
	       else{$sym->mklink($storename);}
	       }
	    }
	 else
	    {
	    if (exists $$H{'path'})
	       {
	       $storename .= $$H{'path'}."/".$ENV{SCRAM_ARCH}."/".$$H{'name'};
	       }
	    else
	       {
	       $storename .= $ENV{SCRAM_ARCH}."/".$$H{'name'};
	       if (!$sym){mkpath($ENV{LOCALTOP}."/".$storename, 0, $perms);}
	       else{$sym->mklink($storename);}
	       }
	    }
	 }
      else
	 {
	 if (exists $$H{'path'})
	    {
	    $storename .= $$H{'path'}."/".$$H{'name'};
	    mkpath($ENV{LOCALTOP}."/".$storename, 0, $perms);
	    symlink $$H{'path'}."/".$$H{'name'},$$H{'name'};
	    }
	 else
	    {
	    $storename .= $$H{'name'};
	    if (!$sym){mkpath($ENV{LOCALTOP}."/".$storename, 0, $perms);}
	    else{$sym->mklink($storename);}
	    }
	 }
      }
   
   # Add the source dir:
   if (!$sym){mkpath($ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork}, 0, $perms);}
   else{$sym->mklink($ENV{SCRAM_INTwork});}
   mkpath($ENV{LOCALTOP}."/".$ENV{SCRAM_SOURCEDIR},0,$perms);
   }

=item   C<setup()>

Set up tools in the current project area.
   
=cut

sub setup()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my $interactive = 0;
   my $toolconf;
   my %opts;
   my %options =
      ("help|h"	=> sub { $self->{SCRAM_HELPER}->help('setup'); exit(0) },
       "file|f=s" => sub { $toolconf = $_[1] },
       "interactive|i" => sub { $interactive = 1 });
   
   local @ARGV = @ARGS;
   
   scramloginteractive(1);
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram setup -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();

      # Set project directory:
      $ENV{'SCRAM_PROJECTDIR'} = $self->localarea()->location();

      my $toolname = shift(@ARGV);
      my $toolversion = shift(@ARGV);
      my $toolurl = shift(@ARGV);

      # Get the tool manager:
      my $toolmanager = $self->toolmanager();
      # Set interactive option:
      $toolmanager->interactive($interactive);
      
      # Initialize the lookup table:
      use SCRAM::AutoToolSetup;
      $::lookupdb = SCRAM::AutoToolSetup->new($toolconf);

      if ($toolname && $toolversion && $toolurl)
	 {	 
	 $toolmanager->toolsetup($self->localarea()->location(),
				 $toolname,
				 $toolversion,
				 $toolurl);
	 }
      elsif ($toolname)
	 {
	 if ($toolname eq 'self')
	    {
	    # First, create the productstore directories if they do not already exist:
	    $self->create_productstores($self->localarea()->location());	    
	    $toolmanager->setupself($self->localarea()->location());
	    }
	 else
	    {
	    $toolmanager->toolsetup($self->localarea()->location(),$toolname,$toolversion);
	    }
	 print "\n";
	 }
      else
	 {
	 print "Setting up all tools in current area","\n";

	 # If there isn't a ToolCache.db file where we expect it, it implies that
	 # we are setting up tools for the n'th platform:
	 if (! -f $self->localarea()->toolcachename())
	    {
	    $self->create_productstores($self->localarea()->location());	    
	    $toolmanager->setupself($self->localarea()->location());
	    }
	 
	 $toolmanager->setupalltools($self->localarea()->location(),0);
	 }
      
      # Write to the tool cache and exit:
      $toolmanager->writecache();
      }
   
   # Return nice value: 
   return 0;
   }

=item   C<runtime()>

Set the runtime environment for the current area.
   
=cut

sub runtime()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my $runtimefile = "";
   my $rtdumpfile ||= "runtime";
   my $SCRAM_RT_SHELL="";
   my $rtvarname="";
   my $paths={}; 
   my $variables={};
   my $rtstring;
   
   local *RTFH = *STDOUT;
   #
   # NB: Overall environment/path ordering: SELF, TOOLS, USER
   #     Eventually sort topologically (by going through list of tools and
   #     seeing which tools those tools depend on, then sorting the list)
   #
   my %opts = ( SCRAM_RT_DUMP => 0 );
   my $shelldata =
      {
      BOURNE =>
	 {
	 EQUALS => '=',
	 SEP => ':',
	 EXPORT => 'export',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ':$'.'SCRAMRT_'.$_[0] : return '' },
	 QUOTE => sub { return "\"$_[0]\";" }
	 },
      TCSH =>
	 {
	 EQUALS => ' ',
	 SEP => ':',
	 EXPORT => 'setenv',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ':{$'.'SCRAMRT_'.$_[0].'}' : return '' },
	 QUOTE => sub { return "\"$_[0]\";" }
	 },
      CYGWIN =>
	 {
	 EQUALS => '=',
	 SEP => ';',
	 EXPORT => 'set',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ';%'.'SCRAMRT_'.$_[0] : return '' },
	 QUOTE => sub { return "\"$_[0]\";" }
	 }
      };
   
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('runtime'); exit(0) },
       "sh"     => sub { $SCRAM_RT_SHELL = 'BOURNE' },
       "csh"    => sub { $SCRAM_RT_SHELL = 'TCSH'  },
       "win"    => sub { $SCRAM_RT_SHELL = 'CYGWIN' },
       "dump=s" => sub { $opts{SCRAM_RT_DUMP} = 1; $rtdumpfile = $_[1] } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram runtime -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();
      
      # Also check to see that we received a shell argument:
      $self->scramfatal("No shell type given! See \"scram runtime -help\" for usage info."), if ($SCRAM_RT_SHELL eq '');

      
      # Save the current environment:
      $self->save_environment($shelldata->{$SCRAM_RT_SHELL}); # Probably have to do the restore here too so
                                           # that all previous settings are restored before
                                           # applying the runtime environment

      # Some preliminary stuff. Check to see which shell we're using and
      # where we're dumping the RT to:
      print "Using ",$SCRAM_RT_SHELL," shell syntax","\n", if ($ENV{SCRAM_DEBUG});

      # If we're dumping to a file, open the file here:
      if ($opts{SCRAM_RT_DUMP})
	 {
	 print "Dumping RT environment to file ",$rtdumpfile,"\n";
	 open(RTFH,"> $rtdumpfile" ) || die $!,"\n";
	 }

      # We need to process ourself. Check to see if tool "self" is
      # defined and if so, process it first.
      my $rawselected = $self->toolmanager()->selected();
      # Get list of setup tools:
      my $tools = $self->toolmanager()->setup();
      # NB: At the moment, all SELF settings (i.e. local ones) come before
      # any other runtime envs from tools:
      if (exists ($tools->{'self'}) && (my $toolrt = $tools->{'self'}->runtime()))
	 {
	 while (my ($toolrt, $trtval) = each %{$toolrt})
	    {
	    if ($toolrt =~ /^PATH:(.*?)$/)
	       {
	       # Need an array where we can store the path elements:
	       (! exists $rtstring->{$1}) ? $rtstring->{$1} = [] : undef;
	       
	       # $trtval is an array reference so we need to
	       # iterate over the elements of the array:
	       map
		  {
		  if (! exists ($paths->{$1}->{$_}))
		     {
		     # Keep track of which paths we've already seen:
		     $paths->{$1}->{$_} = 1 ;
		     # Add the path element onto the array:
		     push(@{$rtstring->{$1}},$_);
		     }
		  } @$trtval; 
	       }
	    else
	       {
	       # Ordinary variable:
	       if (! exists ($variables->{$toolrt}))
		  {
		  $variables->{$toolrt} = 1;
		  print RTFH $shelldata->{$SCRAM_RT_SHELL}->{EXPORT}." ".$toolrt.
		     $shelldata->{$SCRAM_RT_SHELL}->{EQUALS}.$shelldata->{$SCRAM_RT_SHELL}->{QUOTE}(@$trtval)."\n";
		  }
	       }
	    }
	 }
      
      # Since we want to prepend to any existing paths, we want to append
      # ":${VAR}" or suchlike. We start with the tools.
      # Sort according to the order in which the tools were selected (i.e., the order in which
      # they appear in RequirementsDoc):
      foreach $tool ( sort { %{$rawselected}->{$a}
			     <=> %{$rawselected}->{$b}}
		      keys %{$rawselected} )
	 {
	 # Extract the runtime content for this tool:
	 my $toolrt = $tools->{$tool}->runtime(), if (exists $tools->{$tool});
	 
	 # If we really have a some runtime data, continue:
	 if (defined ($toolrt))
	    {
	    while (my ($toolrt, $trtval) = each %{$toolrt})
	       {
	       if ($toolrt =~ /^PATH:(.*?)$/)
		  {
		  # Need an array where we can store the path elements:
		  (! exists $rtstring->{$1}) ? $rtstring->{$1} = [] : undef;

		  # $trtval is an array reference so we need to
		  # iterate over the elements of the array:
		  map
		     {
		     if (! exists ($paths->{$1}->{$_}))
			{
			# Keep track of which paths we've already seen:
			$paths->{$1}->{$_} = 1 ;
			# Add the path element onto the array:
			push(@{$rtstring->{$1}},$_);
			}
		     } @$trtval; 
		  }
	       else
		  {
		  # Ordinary variable:
		  if (! exists ($variables->{$toolrt}))
		     {
		     $variables->{$toolrt} = 1;
		     print RTFH $shelldata->{$SCRAM_RT_SHELL}->{EXPORT}." ".$toolrt.
			$shelldata->{$SCRAM_RT_SHELL}->{EQUALS}.$shelldata->{$SCRAM_RT_SHELL}->{QUOTE}(@$trtval)."\n";
		     }
		  }
	       }
	    }
	 }
     
      # Now dump out the path settings in the appropriate flavoured syntax:   
      map
	 {
	 print "";
	 print RTFH $shelldata->{$SCRAM_RT_SHELL}->{EXPORT}." ".$_.
	    $shelldata->{$SCRAM_RT_SHELL}->{EQUALS}.$shelldata->{$SCRAM_RT_SHELL}->{QUOTE}
	 (join("$shelldata->{$SCRAM_RT_SHELL}->{SEP}",@{$rtstring->{$_}}).$shelldata->{$SCRAM_RT_SHELL}->{PRINTVAR}($_))."\n";
	 } keys %{$rtstring};
      }
   
   # Return nice value: 
   return 0;
   }

=item   C<save_environment()>

Save the current runtime environment. This function is used to
restore an environment to its original state, usually before
setting the runtime for a new area. Only used internally.
 
=cut

sub save_environment()
   {
   # The SCRAMRT_x variables must also be written out in
   # the required shell flavour
   my $self=shift;
   my ($shelldata)=@_;
   
   # Use combination of project name and version to set unique ID
   # for SCRAMRT_SET variable:
   my $rtkey =$ENV{SCRAM_PROJECTNAME}.":".$ENV{SCRAM_PROJECTVERSION};
   
   # Check to see if runtime environment has already been set.
   # If it has, no need to save the environment:
   if (exists($ENV{SCRAMRT_SET}))
      {
      if ($ENV{SCRAMRT_SET} ne $rtkey)
	 {
	 $self->restore_environment();
	 delete $ENV{SCRAMRT_SET};
	 # Save the environment:
	 $self->save_environment($shelldata);
	 }
      else
	 {
	 $self->restore_environment();
	 }
      }
   else
      {
      # Save the environment.
      # Store all environment variables as SCRAMRT_x so
      # that environment can be reset to original (pre-scram runtime)
      # settings:
      while (my ($varname, $varvalue) = each %ENV)
	 {
	 # We must skip any internal SCRAM environment settings, including
	 # LOCALTOP and RELEASETOP
	 next if ($varname eq "_"); # Also, makes no sense to store "_", the last command run:
	 next if ($varname eq "PWD"); # Also, don't want to override PWD!
	 next if ($varname eq "PROMPT_COMMAND"); # A feature of bash.

	 if ($varname !~ /^SCRAM_.*/ && $varname !~ /^SCRAM$/ && $varname !~ /^LOCALTOP$|^RELEASETOP$|^LOCALRT$|^BASE_PATH$/)
	    {
	    # Check to see if the value of the variable contains quotes. If so, handle them properly:
	    $varvalue =~ s/\"/\\\"/g;
	    # Also handle backticks:
	    $varvalue =~ s/\`/\\\`/g;	    

	    # Print out var:
	    print RTFH $shelldata->{EXPORT}." ".'SCRAMRT_'.$varname.$shelldata->{EQUALS}.$shelldata->{QUOTE}($varvalue)."\n";
	    }
	 }
      
      # Set the key that says "RTDONE":
      print RTFH $shelldata->{EXPORT}." ".'SCRAMRT_SET'.$shelldata->{EQUALS}.$shelldata->{QUOTE}($rtkey)."\n";
      }
   }

=item   C<restore_environment()>

Restore the original runtime environment. This function is used to
restore an environment to its original state, usually before
setting the runtime for a new area. Only used internally.

=cut

sub restore_environment()
   {
   my $self=shift;
   my %currentenv=%ENV;
   my %restoredenv;
   
   # Restore the environment from the SCRAMRT_x variables. We start with a clean slate, copying
   # all SCRAM_x variables, SCRAMRT_x variables and expanding the SCRAMRT_x variables so that x
   # is restored:
   while (my ($varname, $varvalue) = each %currentenv)
      {
      if ($varname =~ /^SCRAMRT_(.*)/)
	 {
	 my $var=$1;
	 $currentenv{$var} =~ s/\Q$currentenv{$varname}\E//g;
	 $currentenv{$var} =~ s/^:*//;  # Deal with any Path variables
	 $restoredenv{$var} = $currentenv{$varname};
	 }
      else
	 {
	 # These are the internal SCRAM variables that should be kept:
	 if ($varname =~ /^SCRAM_.*/ || $varname =~ /^SCRAM$/ || $varname =~ /^LOCALTOP$|^RELEASETOP$/)
	    {
	    $restoredenv{$varname} = $currentenv{$varname};
	    }
	 }
      }
   
   # Copy the new env to ENV:
   %ENV=%restoredenv;
   }

=item   C<runtimebuildenv_()>

Set the build runtime environment.
   
=cut

sub runtimebuildenv_()
   {
   my $self=shift;
   my $SCRAM_RT_SHELL="BOURNE"; # Make shell is /bin/sh
   my $paths={}; 
   my $variables={};
   my $rtstring={};
   my $shelldata =
      {
      BOURNE =>
	 {
	 EQUALS => '=',
	 SEP => ':',
	 EXPORT => 'export',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ':'.$ENV{$_[0]} : return '' },
	 QUOTE => sub { return "\"$_[0]\";" },
	 SETSTRING => sub { return "$_[0]" }
	 }
      };
   
   # We need to process ourself. Check to see if tool "self" is
   # defined and if so, process it first.
   my $rawselected = $self->toolmanager()->selected();
   # Get list of setup tools:
   my $tools = $self->toolmanager()->setup();
   # NB: At the moment, all SELF settings (i.e. local ones) come before
   # any other runtime envs from tools:
   if (exists ($tools->{'self'}) && (my $toolrt = $tools->{'self'}->runtime()))
      {
      while (my ($toolrt, $trtval) = each %{$toolrt})
	 {
	 if ($toolrt =~ /^PATH:(.*?)$/)
	    {
	    # Need an array where we can store the path elements:
	    (! exists $rtstring->{$1}) ? $rtstring->{$1} = [] : undef;
	    
	    # $trtval is an array reference so we need to
	    # iterate over the elements of the array:
	    map
	       {
	       if (! exists ($paths->{$1}->{$_}))
		  {
		  # Keep track of which paths we've already seen:
		  $paths->{$1}->{$_} = 1 ;
		  # Add the path element onto the array:
		  push(@{$rtstring->{$1}},$_);
		  }
	       } @$trtval; 
	    }
	 else
	    {
	    # Ordinary variable:
	    if (! exists ($variables->{$toolrt}))
	       {
	       $variables->{$toolrt} = 1;
	       $ENV{$toolrt} = $shelldata->{$SCRAM_RT_SHELL}->{SETSTRING}(@$trtval);
	       }
	    }
	 }
      }
   
   # Since we want to prepend to any existing paths, we want to append
   # ":${VAR}" or suchlike. We start with the tools.
   # Sort according to the order in which the tools were selected (i.e., the order in which
   # they appear in RequirementsDoc):
   my $gmakebase="";
   foreach $tool ( sort { %{$rawselected}->{$a}
			  <=> %{$rawselected}->{$b}}
		   keys %{$rawselected} )
      {
      # Extract the runtime content for this tool:
      my $toolrt = $tools->{$tool}->runtime(), if (exists $tools->{$tool});
      
      # If we really have a some runtime data, continue:
      if (defined ($toolrt))
	 {
	 while (my ($toolrt, $trtval) = each %{$toolrt})
	    {
	    if ($toolrt =~ /^PATH:(.*?)$/)
	       {
	       # Need an array where we can store the path elements:
	       (! exists $rtstring->{$1}) ? $rtstring->{$1} = [] : undef;
	       
	       # $trtval is an array reference so we need to
	       # iterate over the elements of the array:
	       map
		  {
		  if (($tool eq "gmake") && ($1 eq "PATH") && ($gmakebase eq "") && (-x $_."/gmake")){$gmakebase=$_;}
		  if (! exists ($paths->{$1}->{$_}))
		     {
		     # Keep track of which paths we've already seen:
		     $paths->{$1}->{$_} = 1 ;
		     # Add the path element onto the array:
		     push(@{$rtstring->{$1}},$_);
		     }
		  } @$trtval; 
	       }
	    else
	       {
	       # Ordinary variable:
	       if (! exists ($variables->{$toolrt}))
		  {
		  $variables->{$toolrt} = 1;
		  $ENV{$toolrt} = $shelldata->{$SCRAM_RT_SHELL}->{SETSTRING}(@$trtval);
		  }
	       }
	    }
	 }
      }
   
   # Now dump out the path settings in the appropriate flavoured syntax:   
   map
      {
      print "";
      $ENV{$_} = $shelldata->{$SCRAM_RT_SHELL}->{SETSTRING}
      (join("$shelldata->{$SCRAM_RT_SHELL}->{SEP}",@{$rtstring->{$_}}).$shelldata->{$SCRAM_RT_SHELL}->{PRINTVAR}($_));
      } keys %{$rtstring};
   $ENV{SCRAM_GMAKE_PATH}=$gmakebase;
   # Return nice value: 
   return 0;
   }


#### End of CMD.pm ####
1;


=back
   
=head1 AUTHOR/MAINTAINER

Shaun ASHBY

=cut

