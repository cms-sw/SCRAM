#____________________________________________________________________ 
# File: CMD.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-24 10:28:14+0200
# Revision: $Id: CMD.pm,v 1.8 2005/02/25 17:56:12 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
#
# Package for the individual subroutines for the scram commands:
#
package SCRAM::CMD;
require 5.004;

use Exporter;
use Utilities::Verbose;
use Getopt::Long ();

@ISA=qw(Exporter Utilities::Verbose);
@EXPORT_OK=qw();

sub new
  ###############################################################
  # new                                                         #
  ###############################################################
  # modified : Fri Oct 24 10:23:01 2003 / SFA                   #
  # params   :                                                  #
  #          :                                                  #
  # function :                                                  #
  #          :                                                  #
  ###############################################################
  {
  my $proto=shift;
  my $class=ref($proto) || $proto;
  my $self={};
              
  bless $self,$class;
  return $self;
  }

sub urlget()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('urlget'); exit(0) } );

   local @ARGV = @ARGS;

   Getopt::Long::config qw(default no_ignore_case require_order);
   
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

sub arch()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('arch'); exit(0) } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
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
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('tool'); exit(0) } );
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram tool -help\" for usage info.");
      }
   else
      {
      my $cmd = shift(@ARGV);
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

sub tooltemplate()
   {
   my $self=shift;
   my ($templatetype) = @_;
   my $templatedir=$ENV{SCRAM_HOME}."/Templates/toolbox";
   
   # There must be at least 1 arg:
   $self->scramfatal("Insufficient arguments: see \"scram tool -help\" for usage info."), if (!$templatetype);
   print "WARNING: This command is presently out-of-date!!","\n";
   
   # Check for a "compiler" or "basic" tag:
   if ($templatetype =~ /^comp/ )
      {
      my $tdir=$templatedir."/CompilerTools/CXX";
      # Copy the template from the SCRAM template dir:
      print "Installing compiler templates in current directory-\n";
      print "destination directory will be CompilerTemplates: ","\n";
      system("cp","-r",$tdir,"CompilerTemplates");
      # Clean up the directory (remove CVS directory):
      system("rm","-rf","CompilerTemplates/CVS");
      print "Done!","\n";
      }
   elsif ($templatetype =~ /^bas/ )
      {
      print "Installing basic tool template in current directory: ","\n";
      system("cp",$templatedir."/basic_template",".");
      print "Done!","\n";
      }
   else
      {
      $self->scramerror("Invalid template type. Please choose \"compiler\" or \"basic\"");
      exit(1);
      }
   
   # Return nice value:
   return 0;
   }

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

sub install()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts = ( SCRAM_FORCE => 0 );
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('install'); exit(0) },
       "force"  => sub { $opts{SCRAM_FORCE} = 1 } );

   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram install -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();

      # Install the project:
      my $project = shift(@ARGV);
      my $projectversion = shift(@ARGV);
      $self->scramfunctions()->addareatoDB($opts{SCRAM_FORCE},$self->localarea(),$project,$projectversion);
      # Return nice value:
      return 0;
      }
   }

sub remove()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts = ( SCRAM_FORCE => 0 );
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('remove'); exit(0) },
       "force"  => sub { $opts{SCRAM_FORCE} = 1 } );

   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
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
	 }
      
      # Return nice value:  
      return 0;
      }
   }


sub version()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('version'); exit(0) },
       "cvsparam"  => sub { require Installation::SCRAM_SITE; &Installation::SCRAM_SITE::site_dump() },
       "info" => sub { print "This is SCRAM, ",$self->{SCRAM_CVSID},"\n"});
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram version -help\" for usage info.");
      exit(1);
      }
   else
      {
      ($thisversion=$ENV{SCRAM_HOME}) =~ s/(.*)\///;
      my $scramtopdir=$1;
      
      # Was there a version arg?:
      my ($version) = shift(@ARGV);
      
      if (defined ($version))
	 {
	 if ( -d $scramtopdir."/".$version )
	    {
	    print "Version $version already installed under ",$scramtopdir,"\n";
	    }
	 else
	    {
	    # Try downloading new version from CVS repository. Get settings from
	    # our site configuration (SCRAM_SITE.pm):
	    require Installation::SCRAM_SITE;
	    
	    my $cvs_settings = &Installation::SCRAM_SITE::CVS_site_parameters();
	    
	    print "Version $version not installed locally: attempting\n";
	    print "download from the SCRAM CVS repository....\n\n";
	    print "(CVSROOT = \"",$cvs_settings->{CVSROOT},"\", AUTH mode = \"",
	    $cvs_settings->{AUTHMODE},"\", USER = \"",$cvs_settings->{USERNAME},"\")\n";
	    print "\n";
	    
	    # set up and configure the cvs module for SCRAM
	    require Utilities::CVSmodule;
	    $cvsobject=Utilities::CVSmodule->new();
	    
	    $cvsobject->set_base($cvs_settings->{CVSROOT});
	    $cvsobject->set_auth($cvs_settings->{AUTHMODE});
	    $cvsobject->set_user($cvs_settings->{USERNAME});
	    $cvsobject->set_passkey($cvs_settings->{PASSKEY});
	    
	    # Now check it out in the right place
	    chdir $scramtopdir or die "Unable to change to $scramtopdir: $!\n";
	    $cvsobject->invokecvs( ( split / /, 
				     "co -d $version -r $version SCRAM" ));
	    
	    # Get rid of cvs object now we've finished
	    $cvsobject=undef;
	    }
	 }
      else
	 {
	 # Deal with links:
	 print "$thisversion";
	 $version=readlink $ENV{SCRAM_HOME};
	 print " ---> $version", if (defined ($version) );
	 print "\n";
	 }           
      }
   
   # Return nice value: 
   return 0;
   }

sub list()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help"	 => sub { $self->{SCRAM_HELPER}->help('list'); exit(0) },
       "compact" => sub { $opts{SCRAM_LISTCOMPACT} = 1 } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
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

      # Otherwise, we continue:
      # Iterate over the list of projects
      foreach my $pr (@projects)
	 {
	 my $url='NULL';
	 
	 if ( $project  eq "" || $project eq $$pr[0] )
	    {
	    # Check that the area exists (i.e. check that a configarea object
	    # is returned before attempting to test its' location):
	    my $possiblearea=$self->scramfunctions()->scramprojectdb()->getarea($$pr[0],$$pr[1]);
	    $url=$possiblearea->location(), if (defined ($possiblearea));
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
	       push(@missingareas,sprintf ">>  Project area MISSING:   %-10s %-20s  \n",$$pr[0],$$pr[1]);
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
      }
  
   # Error if there were missing areas:
   $self->scramerror("\n",@missingareas), if ( $#missingareas > -1 );
   
   # Otherwise return nicely:
   return 0;
   }


sub db()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts = ( SCRAM_DB_SHOW => 0, SCRAM_DB_LINK => 0, SCRAM_DB_UNLINK => 0 );
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('db'); exit(0) },
       "show"   => sub { $opts{SCRAM_DB_SHOW} = 1 },
       "link"   => sub { $opts{SCRAM_DB_LINK} = 1 },
       "unlink" => sub { $opts{SCRAM_DB_UNLINK} = 1 } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
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

sub build()
   {
   my $self=shift;
   unshift @INC, $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR};
   # The cache files:
   my $toolcache=$ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ToolCache.db";
   my $dircache=$ENV{LOCALTOP}."/.SCRAM/DirCache.db";
   my $builddatastore=$ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db";
   # Default mode for graphing is package-level:
   my $graphmode||='PACKAGE';
   my $fast=0;
   my $workingdir=$ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork};
   my $makefilestatus=0;
   my ($packagebuilder,$dataposition,$buildstoreobject);
   my $verbose=0;
   my $configbuildfiledir=$ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR};
   
   # Getopt variables:
   my %opts = ( WRITE_GRAPHS => 0, # No graphs produced by default;
		SCRAM_TEST => 0 ); # test mode: don't run make;
   my %options =
      ("help"     => sub { $self->{SCRAM_HELPER}->help('build'); exit(0) },
       "verbose"  => sub { $ENV{SCRAM_BUILDVERBOSE} = 1 },
       "testrun"  => sub { $opts{SCRAM_TEST} = 1 },
       "reset"    => sub { print "Resetting caches","\n"; system("rm","-f",$builddatastore,$dircache)
			      if (-f $builddatastore) ;
			   $now = time; utime $now, $now, $toolcache },
       "fast"     => sub { print "Skipping cache scan...","\n"; $fast=1 },
       "writegraphs=s"  => sub { $opts{WRITE_GRAPHS} = 1; $graphmode=$_[1] });
   
   local (@ARGV) = @_;

   # Set the options:
   Getopt::Long::config qw(default no_ignore_case require_order pass_through);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram build -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();
      # Set location variables:
      use Cwd;
      my $current_dir = cwd();
      
      # Set THISDIR. If we have a full match on LOCALTOP, set THISDIR to src:
      ($ENV{THISDIR}) = ($current_dir =~ m|^$ENV{LOCALTOP}/(.*)$|);
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

      if ( -r $cachename )
	 {
	 print "Reading cached data","\n",if ($ENV{SCRAM_DEBUG});
	 $cacheobject=&Cache::CacheUtilities::read($cachename);
	 }

      # Set verbosity for cache object:
      $cacheobject->verbose($ENV{SCRAM_CACHEDEBUG});
      # Check for BuildFiles (config dir and src) and track timestamps of contents
      # of config dir (templates, for example):
      $cacheobject->checkfiles() unless $fast;

      # Create the working dir if it doesn't exist
      AddDir::adddir($workingdir), if (! -d $workingdir);

      # BuildSystem::Make object created here to handle args passed to gmake:
      use BuildSystem::MakeInterface;
      my $MAKER = BuildSystem::MakeInterface->new(@ARGV);
      
      # Now check the file status (BuildFiles in src tree) and config
      # file status (contents of config dir). We only reparse everything
      # and rebuild the makefiles if something changed:
      if ($cacheobject->configstatus() ||    # config out of date; 
	  $cacheobject->filestatus() ||      # BuildFile out of date
	  $cacheobject->cachestatus())       # Files added/removed from src dir
	 { 
	 my $buildfiles = $cacheobject->bf_for_scanning();
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
	 
	 if ( -r $builddatastore )
	    {
	    print "Reading cached build data","\n";
	    
	    $buildstoreobject=&Cache::CacheUtilities::read($builddatastore);
	    # Update- check for changed or removed files. Also need to account for removed directories:
	    $buildstoreobject->init_engine(); # Restart the template engine
	    # Set graph mode for the grapher:
	    $buildstoreobject->grapher($graphmode,$opts{WRITE_GRAPHS});

	    # Run in update mode:
	    $buildstoreobject->update($changeddirs,
				      $addeddirs,
				      $buildfiles,
				      $removedfiles,
				      $self->toolmanager(), $filecache);
	    }
	 else
	    {
	    # We populate our build data cache:
	    print "Parsing BuildFiles\n";
	    # Set graph mode for the grapher:
	    $buildstoreobject->grapher($graphmode,$opts{WRITE_GRAPHS});
	    # We don't have any build data yet so we need to initialize the object:
	    $buildstoreobject->populate($cacheobject->paths(), $filecache, $self->toolmanager());	    
	    # Do stuff with build cache and data. Iterate over the entire directory structure,
	    # doing whatever we need to do (collect metadata, for example). The raw data will
	    # have already been extracted earlier, so the iteration over the directories
	    # serves to resolve the build data and make it persistent. The final element
	    # of any branch (e.g. bin, test, module, python), which will correspond to
	    # the template class to be applied, is the final resting place of the parsed data.
	    # Once this data is in place, the corresponding template can be processed and Makefile text
	    # written out to the main Makefile...note that this means that the project template is
	    # processed first, followed by all subsystems, then packages, then real build products.
	    # THUS, we ensure that all build metadata is available once we arrive at the level of the
	    # build product. So, we iterate:
	    $buildstoreobject->processtree();
	    }
	 
	 # Now write to the file cache. From here on, we're done with it:
	 print "\nUpdating cache","\n",if ($ENV{SCRAM_DEBUG});
	 $cacheobject->cachestatus(0); # We've updated the cache so reset the status
	 &Cache::CacheUtilities::write($cacheobject,$cachename);
	 
	 # Handle graphing:
	 if ($opts{WRITE_GRAPHS} && $graphmode !~ /^[Pp].*?/) # Graph printing required
	    {
	    $buildstoreobject->global_graph_writer();
	    }
	 
	 # Write to build data cache:
	 $buildstoreobject->save();
	 print "\nUpdating build cache","\n",if ($ENV{SCRAM_DEBUG});
	 $buildstoreobject->cachestatus(0);
 	 &Cache::CacheUtilities::write($buildstoreobject,$builddatastore);
 	 
	 # At this point, all the data will have been processed and Makefiles generated.
	 # So here's where we will run gmake (use -r to turn of implicit rules):
	 my $returnval = $MAKER->exec($ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork}."/Makefile"),
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
	 if ( -f $ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork}."/Makefile")
	    {
	    my $returnval = $MAKER->exec($ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork}."/Makefile"),
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

sub project()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my ($installdir, $installname);
   my ($toolconf,$bootfile,$bootstrapfile);   
   my %opts = (
	       SCRAM_INSTALL_DIR => 0,
	       SCRAM_INSTALL_NAME => 0,
	       SCRAM_TOOLCONF_NAME => 0,
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
   my %options =
      ("help"   => sub { $self->{SCRAM_HELPER}->help('project'); exit(0) },
       "dir=s"  => sub { $opts{SCRAM_INSTALL_DIR} = 1; $installdir = $_[1] },
       "name=s" => sub { $opts{SCRAM_INSTALL_NAME} = 1; $installname = $_[1] },
       "file=s" => sub { $opts{SCRAM_TOOLCONF_NAME} = 1; $toolconf = $_[1] },
       "template" => sub { $self->project_template_copy(); exit(0) },
       "boot=s" => sub { $opts{SCRAM_BOOTSTRAPFILE_NAME} = 1; $bootstrapfile = 'file:'.$_[1]; $bootfile = $_[1] }
       );

   local @ARGV = @ARGS;
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram project -help\" for usage info.");
      }
   else
      {
      # Check install dir/name:
      use Cwd;
      $installdir ||= cwd(); # Current working dir unless set above
      
      # Check to see which type of boot we should do:
      if ($opts{SCRAM_BOOTSTRAPFILE_NAME})
	 {
	 print "Bootstrapping a new project from ",$bootfile,"\n";
	 print "NB: The -name option is not supported when booting a new project from scratch!","\n",
	 if ($opts{SCRAM_INSTALL_NAME});	 
	 print "\n";
	 $self->bootnewproject($bootstrapfile,$installdir,$toolconf);
	 }
      else
	 {
	 my $projectname = shift(@ARGV);
	 my $projectversion = shift(@ARGV);
	 
	 $self->bootfromrelease($projectname,$projectversion,$installdir,$installname,$toolconf);
	 }     
      }
   
   # Return nice value:
   return 0;
   }

sub bootfromrelease()
   {
   my $self=shift;
   my ($projectname,$projectversion,$installdir,$installname,$toolconf) = @_;
   
   if ($projectname && $projectversion)
      {
      print "Creating a developer area based on project ",$projectname,", version ",$projectversion,"\n";
      print "Getting project release area....","\n";
      my $relarea=$self->scramfunctions()->scramprojectdb()->getarea($projectname,$projectversion);

      if ( ! defined $relarea )
	 {
	 print "Error...no release area!","\n";
	 $self->scramfatal("No release area found.");
	 }

      # Set RELEASETOP:
      $ENV{RELEASETOP} = $relarea->location();
      
      print "Checking SCRAM version....","\n";

      $self->versioncheck($relarea->scramversion());
      $area=$self->scramfunctions()->satellite($projectname,$projectversion,$installdir,$installname);
      $ENV{SCRAM_CONFIGDIR} = $area->configurationdir();
      
      # Read the top-level BuildFile and create the required storage dirs. Do
      # this before setting up self:
      $self->create_productdirs($area->location());
      # The lookup db:
      use Scram::AutoToolSetup;

      # Default path to conf file:
      $toolconf ||= $area->location()."/".$ENV{SCRAM_CONFIGDIR}."/site/tools-".$ENV{SCRAM_SITENAME}.".conf";
      $::lookupdb = Scram::AutoToolSetup->new($toolconf);  
      
      # Need a toolmanager, then we can setup:
      my $toolmanager = $self->toolmanager($area);
      $toolmanager->setupself($area->location());

      # Write the cached info:
      $toolmanager->writecache();
      
      print "\n\nInstallation procedure complete.\n";
      print "Developer area located at:\n\n\t\t".$area->location()."\n\n";
      }
   else
      {
      $self->scramfatal("Insufficient arguments: see \"scram project -help\" for usage info.");
      }
   
   # Return nice value:
   return 0;
   }

sub bootnewproject()
   {
   my $self=shift;
   my $areaname="";
   my ($bootstrapfile,$installarea,$toolconf)=@_;

   use Scram::AutoToolSetup;
   use BuildSystem::ToolManager;
   use BuildSystem::Requirements;
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
   my $req = BuildSystem::Requirements->new($astore, "file:".$doc, 
			$ENV{SCRAM_ARCH});

   $area->toolboxversion($req->configversion());

   # Add ToolManager object to store all tool info:
   my $toolmanager = BuildSystem::ToolManager->new($area, $ENV{SCRAM_ARCH});

   # Tell the Requirements class that there's a ToolManager to use:
   $req->toolmanager($toolmanager);

   # download the tools:
   $req->download();

   # Need an autotoolssetup object:
   $ENV{'SCRAM_SITENAME'} = $area->sitename();
   $ENV{'SCRAM_PROJECTDIR'} = $area->location();
   $::lookupdb = Scram::AutoToolSetup->new($toolconf);   
   
   # Now run the full setup for the area:
   print "\n","Using SCRAM toolbox version ",$area->toolboxversion(),"\n\n";
   
   # Now set up selected tools:
   print "Setting up tools in project area","\n";
   print "------------------------------------------------","\n";
   print "\n";
   
   $toolmanager->setupalltools($area->location(),1);

   # Read the top-level BuildFile and create the required storage dirs. Do
   # this before setting up self:
   $self->create_productdirs($area->location());
      
   # Now setup SELF:
   $toolmanager->setupself($area->location());

   # New tm's are not clones:
   $toolmanager->cloned_tm(0);
   
   # Write the cached info:
   $toolmanager->writecache();
   # Save the area info (toolbox version):
   $area->save();

   print "\n";
   print ">> Installation Located at: ".$area->location()." <<\n\n";

   # Return nice value:
   return 0;
   }

sub create_productdirs()
   {
   my $self=shift;
   my ($location) = @_;
   
   use BuildSystem::BuildFile;
   use Utilities::AddDir;      

   my $toplevelconf = BuildSystem::BuildFile->new();
   my $tlbf = $location."/".$ENV{SCRAM_CONFIGDIR}."/BuildFile";
   $toplevelconf->parse($tlbf);
   $ENV{LOCALTOP} = $location;
   my $stores = $toplevelconf->productstore();
   
   print "\nChecking/creating local storage directories","\n";
   print "\n";
   
   # Iterate over the stores:
   foreach my $H (@$stores)  
      {
      my $storename="";
      # Probably want the store value to be set to <name/<arch> or <arch>/<name> with
      # <path> only prepending to this value rather than replacing <name>: FIXME...
      if ($$H{'type'} eq 'arch')
	 {
	 if ($$H{'swap'} eq 'true')
	    {
	    (exists $$H{'path'}) ? ($storename .= $$H{'path'}."/".$ENV{SCRAM_ARCH})
	       : ($storename .= $$H{'name'}."/".$ENV{SCRAM_ARCH});
	    }
	 else
	    {
	    (exists $$H{'path'}) ? ($storename .= $ENV{SCRAM_ARCH}."/".$$H{'path'})
	       : ($storename .= $ENV{SCRAM_ARCH}."/".$$H{'name'});
	    }
	 }
      else
	 {
	 (exists $$H{'path'}) ? ($storename .= $$H{'path'})
	    : ($storename .= $$H{'name'});
	 }
      
      # Create the dir:
      if (! -d "$ENV{LOCALTOP}/$storename")
	 {
	 print "Creating directory $ENV{LOCALTOP}/$storename","\n";	 
	 AddDir::adddir($ENV{LOCALTOP}."/".$storename);
	 }
      }
   # Add the source dir:
   AddDir::adddir($ENV{LOCALTOP}."/".$ENV{SCRAM_SOURCEDIR});
   }

sub project_template_copy()
   {
   my $self=shift;
   use Cwd qw(&cwd);
   
   print "SCRAM: Copying basic start config to current directory...","\n";

   # Check to see if there's already a config dir. If so warn and return:
   if ( -d cwd()."/config")
      {
      print "\n";
      print "Warning: unable to install templates because you appear to have a config","\n";
      print "         directory present already. Please delete it and re-run...","\n";
      return;
      }
   else
      {
      my $tdir = $ENV{SCRAM_HOME}."/src/main/config";
      my $dest = cwd()."/config";
      print "SCRAM: Copying config templates from local SCRAM installation area","\n";
      print "       ",$tdir,"\n";
      &AddDir::copydir($tdir,$dest);
      }
   print "\nSuccesfully done!","\n";

   # Return nice value:
   return 0;
   }

sub setup()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my $interactive = 0;
   my $toolconf;
   my %opts;
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('setup'); exit(0) },
       "file=s" => sub { $toolconf = $_[1] },
       "interactive" => sub { $interactive = 1 });
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram setup -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();

      # Set sitename and project directory:
      $ENV{'SCRAM_SITENAME'} = $self->localarea()->sitename();
      $ENV{'SCRAM_PROJECTDIR'} = $self->localarea()->location();

      my $toolname = shift(@ARGV);
      my $toolversion = shift(@ARGV);
      my $toolurl = shift(@ARGV);

      # Get the tool manager:
      my $toolmanager = $self->toolmanager();
      # Set interactive option:
      $toolmanager->interactive($interactive);
      
      # Initialize the lookup table:
      use Scram::AutoToolSetup;
      $::lookupdb = Scram::AutoToolSetup->new($toolconf);

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
	    $self->create_productdirs($self->localarea()->location());	    
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
	    $self->create_productdirs($self->localarea()->location());	    
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
   my %opts = ( SCRAM_RT_FILE => 0, SCRAM_RT_DUMP => 0 );
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
       "file=s" => sub { $opts{SCRAM_RT_FILE} = 1; $runtimefile = $_[1] },
       "info=s" => sub { $opts{SCRAM_RT_INFO} = 1; $rtvarname = $_[1] },
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

      # If we're reading from s runtime file, check that it exists:
      if ($opts{SCRAM_RT_FILE} && ! -f $runtimefile)
	 {
	 $self->scramfatal("Runtime file $runtimefile cannot be found or is not readable!");
	 }
      
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

      # Process runtime file arguments, if any. Using the info option only makes sense
      # if we're reading from a file:
      if ($opts{SCRAM_RT_INFO} && ! $opts{SCRAM_RT_FILE})
	 {
	 $self->scramfatal("Using the -info <varname> option only makes sense when reading from a file!");
	 }
      
      # Read from runtime file:
      if ($opts{SCRAM_RT_FILE})
	 {
	 use RuntimeFile;
	 my $rtfile = RuntimeFile->new($runtimefile);
	 
	 # Read the file:
	 $rtfile->read();

	 # See if we have other args too:
	 if ($opts{SCRAM_RT_INFO})
	    {
	    $rtfile->info($rtvarname);
	    # And return:
	    return 0;
	    }
	 else
	    {
	    # If info not required, dump the content to the rest of the runtime
	    # process:
	    my $rtcontent = $rtfile->content();
	    
	    while (my ($toolrt, $trtval) = each %{$rtcontent})
	       {
	       if (! exists ($variables->{$toolrt}))
		  {
		  $variables->{$toolrt} = 1;
		  # When we print, we also use the same check via $shelldata->{$SCRAM_RT_SHELL}->{PRINTVAR}
		  # so that we enable prepending of data to existing vars...just in case people want to do
		  # this for things like LD_LIBRARY_PATH etc.:
		  print RTFH $shelldata->{$SCRAM_RT_SHELL}->{EXPORT}." ".$toolrt.
		     $shelldata->{$SCRAM_RT_SHELL}->{EQUALS}.$shelldata->{$SCRAM_RT_SHELL}->{QUOTE}($trtval->{'value'}.
												    $shelldata->{$SCRAM_RT_SHELL}->{PRINTVAR}($toolrt))."\n";
		  }
	       }
	    # Return:
	    return 0;
	    }
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
	 
	 if ($varname !~ /^SCRAM_.*/ && $varname !~ /^SCRAM$/ && $varname !~ /^LOCALTOP$|^RELEASETOP$/)
	    {
	    # Print out var:
	    print RTFH $shelldata->{EXPORT}." ".'SCRAMRT_'.$varname.$shelldata->{EQUALS}.$shelldata->{QUOTE}($varvalue)."\n";
	    }
	 }
      
      # Set the key that says "RTDONE":
      print RTFH $shelldata->{EXPORT}." ".'SCRAMRT_SET'.$shelldata->{EQUALS}.$shelldata->{QUOTE}($rtkey)."\n";
      }
   }

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

#### End of CMD.pm ####
1;
