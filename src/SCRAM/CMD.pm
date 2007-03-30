#____________________________________________________________________ 
# File: CMD.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-24 10:28:14+0200
# Revision: $Id: CMD.pm,v 1.61 2007/02/27 12:46:01 sashby Exp $ 
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

=item   C<arch()>

Print the current SCRAM_ARCH to STDOUT.
   
=cut

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

=item   C<tooltemplate()>

Install compiler or tool templates to the current directory. This is
an out of date command.
   
=cut

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
      # Copy the template from the SCRAM template dir:
      print "Installing compiler tool template in current directory:\n";
      system("cp",$templatedir."/compiler.xml",".");
      print "Done!","\n";
      }
   elsif ($templatetype =~ /^bas/ )
      {
      print "Installing basic tool template in current directory: ","\n";
      system("cp",$templatedir."/basic_template.xml",".");
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
      # Check to make sure that the project is a SCRAM V1 project:
      $self->checkareatype($self->localarea()->location(),"Area type mismatch. Trying to execute a SCRAM command in a V0 project area using a V1x version of SCRAM. Exitting.");
      
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
      my $scramtopdir=$self->scramfunctions()->scram_topdir();      
      # Was there a version arg? If so, switch to this version:
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
	 print $ENV{SCRAM_VERSION};
	 $version=readlink $ENV{SCRAM_HOME};
	 print " ---> $version", if (defined ($version) );
	 print "\n";
	 }           
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
      ("help"	 => sub { $self->{SCRAM_HELPER}->help('list'); exit(0) },
       "oldstyle" => sub { $opts{SCRAM_OLDSTYLE} = 1 },
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
      print $self->getprojectsfromDB(),"\n";
#      $self->scramfunctions()->scramprojectdb()->link_to_db("/a/path/to/dummydb.xml");      
      # Do a test dump:
#      print $self->scramfunctions()->scramprojectdb()->dump(),"\n";
     
      

#      map { print $_->name,"\n"; } @projects;
#      return;
#      print join(" ",@projects),"\n";
      
      # We say goodbye if there aren't any projects installed:
      $self->scramerror(">>>> No locally installed projects! <<<<"), if ( $#projects < 0);
      return;
      # Otherwise, we continue. First, we see if the option SCRAM_OLDSTYLE is set. If so, we show all
      # projects (V0_x ones too) in the same manner as other SCRAM versions. If not, we use the new
      # mechanism which checks only for the .installed file.      
      # Iterate over the list of projects:
      foreach my $pr (@projects)
	 {
	 my $url='NULL';	 
	 if ( $project  eq "" || $project eq $pr->name)
	    {
	    # Check that the area exists (i.e. check that a configarea object
	    # is returned before attempting to test its' location):
	    my $possiblearea=$self->scramfunctions()->scramprojectdb()->getarea($pr->name,$pr->version);
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

=item   C<build()>

Compile the source code in the current project area. 
   
=cut

sub build()
   {
   my $self=shift;
   # Add config directory to @INC so that custom plugin packages can be used:
   unshift @INC, $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR};
   
   # The cache files:
   my $toolcache=$ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ToolCache.db";
   my $dircache=$ENV{LOCALTOP}."/.SCRAM/DirCache.db";
   my $builddatastore=$ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db";

   # The directories:
   my $workingdir=$ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork};
   my $configbuildfiledir=$ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR};

   # Default mode for graphing is package-level:
   my $graphmode||='PACKAGE';
   my $fast=0;
   my $makefilestatus=0;
   my ($packagebuilder,$dataposition,$buildstoreobject);
   my $verbose=0;
   my $trap_flag=0;
   
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
       "writegraphs=s"  => sub { $opts{WRITE_GRAPHS} = 1; $graphmode=$_[1] },
       "xmlb"     => sub {$ENV{SCRAM_XMLBUILDFILES} = 1; print "SCRAM: Will read XML versions of your BuildFiles.","\n" } );
   
   local (@ARGV) = @_;

   # Set the options:
   Getopt::Long::config qw(default no_ignore_case require_order pass_through);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram build -help\" for usage info.");
      }
   else
      {
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
	 # Install a handler for SIGINT. This is done here becuase this is the block in which
	 # the cache will be modified and written back. Anywhere in this process, the cache can
	 # be corrupted if a user hits ctrl-c. By trapping this, we at least force the block to
	 # continue until the cache is written before exit:
	 $SIG{INT}  = sub
	    {
	    ($trap_flag == 0) ? $trap_flag = 1 : $trap_flag;
	    print $::bold."\nUser interrupt: Writing cache before exit.\n".$::normal;
	    };
	 
	 if ( -r $builddatastore )
	    {
	    print "Reading cached build data","\n";	    
	    $buildstoreobject=&Cache::CacheUtilities::read($builddatastore);
	    # Update- check for changed or removed files. Also need to account for removed directories:
	    if ($buildstoreobject)
	       {
	       $buildstoreobject->init_engine(); # Restart the template engine
	       }
	    else
	       {
	       # Report an error and exit (implies that cache has disappeared):
	       $self->scramerror("SCRAM: .SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db missing. Use \"-r\".");
	       exit(1);
	       }

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
 	 # Exit cleanly here if ctrl-c was given:
	 if ($trap_flag == 1)
	    {
	    print $::bold."\nExitting on Ctrl-C.\n\n".$::normal,
	    exit(0);
	    }
	 
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

=item   C<project()>
   
Create a SCRAM developer area or bootstrap a new SCRAM project area.

=cut

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
   my %options =
      ("help"   => sub { $self->{SCRAM_HELPER}->help('project'); exit(0) },
       "dir=s"  => sub { $opts{SCRAM_INSTALL_DIR} = 1; $installdir = $_[1] },
       "name=s" => sub { $opts{SCRAM_INSTALL_NAME} = 1; $installname = $_[1] },
       "file=s" => sub { $opts{SCRAM_TOOLCONF_NAME} = 1; $toolconf = $_[1] },
       "template" => sub { $self->project_template_copy(); exit(0) },
       "update" => sub { $opts{SCRAM_UPDATE_AREA} = 1 },
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
	 $self->bootfromrelease($projectname,$projectversion,$installdir,$installname,$toolconf);
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
    my ($projectname,$projectversion,$installdir,$installname,$toolconf) = @_;
    
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
	print "Creating a developer area based on project ",$projectname,", version ",$projectversion,"\n";

	# Set RELEASETOP:
	$ENV{RELEASETOP} = $relarea->location();	
	# Set the var for project name and version:
	$ENV{SCRAM_PROJECTNAME} = $projectname;
	$ENV{SCRAM_PROJECTVERSION} = $projectversion;
	
	# Check that the areas are compatible:
	$self->checkareatype($ENV{RELEASETOP},"Project release area SCRAM version mismatch: current is V1, area is V0. Exitting.");
	$area=$self->scramfunctions()->satellite($projectname,$projectversion,$installdir,$installname);
	$ENV{SCRAM_CONFIGDIR} = $area->configurationdir();
	
	# Read the top-level BuildFile and create the required storage dirs. Do
	# this before setting up self:
	$self->create_productstores($area->location());
	# The lookup db:
	use SCRAM::AutoToolSetup;
	
	# Default path to conf file. Assume that the site name is STANDALONE if not already set:
	$ENV{SCRAM_SITENAME} = 'STANDALONE', unless (exists($ENV{SCRAM_SITENAME}));
	$toolconf ||= $area->location()."/".$ENV{SCRAM_CONFIGDIR}."/site/tools-".$ENV{SCRAM_SITENAME}.".conf";
	$::lookupdb = SCRAM::AutoToolSetup->new($toolconf);  
	
	# Need a toolmanager, then we can setup:
	my $toolmanager = $self->toolmanager($area);
	$toolmanager->setupself($area->location());
	
	# Write the cached info:
	$toolmanager->writecache();
	
	print "\n\nInstallation procedure complete.\n";
	print "Developer area located at:\n\n\t\t".$area->location()."\n\n";
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
   $ENV{'SCRAM_SITENAME'} = $area->sitename();
   $ENV{'SCRAM_PROJECTDIR'} = $area->location();
   $ENV{'SCRAM_PROJECTVERSION'} = $area->version();
   
   $::lookupdb = SCRAM::AutoToolSetup->new($toolconf);   
   
   # Now run the full setup for the area:
   print "\n","Using SCRAM toolbox version ",$area->toolboxversion(),"\n\n";
   
   # Now set up selected tools:
   print "Setting up tools in project area","\n";
   print "------------------------------------------------","\n";
   print "\n";
   
   $toolmanager->setupalltools($area->location(),1);

   # Read the top-level BuildFile and create the required storage dirs. Do
   # this before setting up self:
   $self->create_productstores($area->location());
   
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
	    
	    AddDir::adddir($backupdir);
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
	    $relarea->copywithskip($ENV{LOCALTOP},'ProjectCache.db');
	    # Also, we need to copy .SCRAM/cache from the release area. This eliminates the need
	    # to download tools again from CVS:
	    $relarea->copyurlcache($ENV{LOCALTOP});
	    # Copy the config dir:
	    AddDir::copydir($relarea->location()."/".$relarea->configurationdir(),
		      $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR});

	    # Change the project version to the new one:
	    $self->localarea()->version($pversion);
	    # Link to the release area and save the environment data:
	    $self->localarea()->linkarea($relarea);
	    $self->localarea()->save();
	    # The lookup db:
	    use SCRAM::AutoToolSetup;
	    
	    # Default path to conf file:
	    my $toolconf ||= $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR}."/site/tools-".$ENV{SCRAM_SITENAME}.".conf";
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
   my ($location) = @_;
   
   use BuildSystem::BuildFile;
   use File::Path;
   my $perms=0755;

   my $toplevelconf = BuildSystem::BuildFile->new();
   my $tlbf = $location."/".$ENV{SCRAM_CONFIGDIR}."/BuildFile.xml";
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
	       mkpath($ENV{LOCALTOP}."/".$storename, 0, $perms);
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
	       mkpath($ENV{LOCALTOP}."/".$storename, 0, $perms);
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
	    mkpath($ENV{LOCALTOP}."/".$storename, 0, $perms);
	    }
	 }
      }
   
   # Add the source dir:
   mkpath($ENV{LOCALTOP}."/".$ENV{SCRAM_SOURCEDIR},0,$perms);
   }

=item   C<project_template_copy()>

Copy a basic set of build templates to the current directory.
   
=cut

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
      print "         directory present already. Please delete/rename it and re-run...","\n";
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

=item   C<config()>

Dump some configuration information pertaining to the current area. Full
tool information can also be dumped.
   
=cut

sub config()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('config'); exit(0) },
       "tools"  => sub { $opts{SCRAM_DUMPCONFIG} = 1 },
       "full"   => sub { $opts{SCRAM_DUMPFULL} = 1} );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram config -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();
      my $localarea = $self->localarea();
      
      # If full info required:
      if ($opts{SCRAM_DUMPCONFIG} && $opts{SCRAM_DUMPFULL})
	 {
	 print "SCRAM_PROJECTNAME=",$localarea->name(),"\n";
	 print "SCRAM_PROJECTVERSION=",$localarea->version(),"\n";      
	 print "SCRAM_TOOLBOXVERSION=",$localarea->toolboxversion(),"\n";
	 # Perhaps show creation time. Check the timestamp of config/requirements:
	 print "SCRAM_PROJECT_TIMESTAMP=",$localarea->creationtime(),"\n";
	 print "SCRAM_PROJECT_RELEASE_TIMESTAMP=",$localarea->creationtime($ENV{RELEASETOP}),"\n"
	    ,if (exists($ENV{RELEASETOP}));
	 print "LOCALTOP=",$ENV{LOCALTOP},"\n";
	 print "RELEASETOP=",$ENV{RELEASETOP},"\n", if (exists($ENV{RELEASETOP}));	 
	 
	 $self->dumpconfig();
	 }
      elsif ($opts{SCRAM_DUMPCONFIG})
	 {
	 $self->dumpconfig();
	 }
      else
	 {
	 # Just project info:
	 print "SCRAM_PROJECTNAME=",$localarea->name(),"\n";
	 print "SCRAM_PROJECTVERSION=",$localarea->version(),"\n";      
	 print "SCRAM_TOOLBOXVERSION=",$localarea->toolboxversion(),"\n";
	 # Perhaps show creation time. Check the timestamp of config/requirements:
	 print "SCRAM_PROJECT_TIMESTAMP=",$localarea->creationtime(),"\n";
	 print "SCRAM_PROJECT_RELEASE_TIMESTAMP=",$localarea->creationtime($ENV{RELEASETOP}),"\n"
	    ,if (exists($ENV{RELEASETOP}));
	 print "LOCALTOP=",$ENV{LOCALTOP},"\n";
	 print "RELEASETOP=",$ENV{RELEASETOP},"\n", if (exists($ENV{RELEASETOP}));	 
	 }
            
      # Return nice value:
      return (0);
      }
   }

=item   C<dumpconfig()>

Dump configuration information for the current B<SCRAM_ARCH>. Only used internally.

=cut

sub dumpconfig()
   {
   my $self=shift;

   print "##\n## Dumping configuration information for SCRAM_ARCH=",$ENV{SCRAM_ARCH},"\n##\n";

   # Get array of setup tools:
   my @setuptoolnames = $self->toolmanager()->toolsdata();
   
   # Exit if there aren't any tools:
   $self->scramerror(">>>> No tools set up for current arch or area: unable to dump config. <<<<"),
   if ( $#setuptoolnames < 0); 
   
   # Show list: format is "tool:toolversion:scram_project[0/1]:<base path>:<dependencies>
   foreach $t (@setuptoolnames)
      {
      my $info = $t->toolname().":".$t->toolversion().":".$t->scram_project();

      # Get the base path for this tool:
      my $tname = $t->toolname();
      $tname =~ tr/-/_/; # Some tools contain hyphens in name;
      my $basepath = $t->variable_data(uc($tname)."_BASE");
      ($basepath eq '') ? ($info .= ":<SYSTEM>") : ($info .= ":".$basepath);
      
      my @deps = $t->use();
      
      if ($#deps < 0)
	 {
	 $info .= ":<NONE>";
	 }
      else
	 {
	 $info .= ":";
	 map { $_ =~ tr/A-Z/a-z/; $info .= $_." " } @deps;	 
	 }
      
      print $info,"\n";	 
      }
   }

=item   C<gui()>

Function to create a GUI to allow interaction with build metadata.
   
=cut

sub gui()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my $interactive = 0;
   my ($class, $showmeta);
   my %opts;
   my %options =
      ("help"	=> sub { $self->{SCRAM_HELPER}->help('gui'); exit(0) },
       "show=s" => sub { $opts{SHOWMETA}=1; $showmeta = $_[1] },
       "edit=s" => sub { $opts{EDITMETA}=1; $class = $_[1] }
       );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram gui -help\" for usage info.");
      }
   else
      {
      # Check to see if we are in a local project area:
      $self->checklocal();

      # Do we want to edit metadata? This option for compilers:
      if ($opts{EDITMETA} && $class =~ /^[Cc].*/)
	 {
	 my $dummy=1;
	 $self->show_compiler_gui();
	 } # End of EDITMETA for compiler  
      elsif ($opts{EDITMETA} && $class =~ /^[Tt].*/)
	 {
	 my $dummy=1;
	 $self->show_tools_gui();
	 } # End of EDITMETA for tools
      elsif ($opts{SHOWMETA})
	 {
	 print "Do something for showmeta for class \"".$showmeta."\"","\n";
	 }
      else
	 {
	 $self->{SCRAM_HELPER}->help('gui'); exit(0);
	 }
      }
   }

=item   C<show_compiler_gui()>

=cut

sub show_compiler_gui()
   {
   my $self=shift;
   
   eval "use Tk;"; $self->missing_package('Tk') if $@;   
   eval "use Tk::NoteBook;"; $self->missing_package('Tk::NoteBook') if $@;
   eval "use Tk::BrowseEntry;"; $self->missing_package('Tk::BrowseEntry') if $@;
   
   #
   # Notes:
   # ------
   #
   # Could also use this interface as a way to clone other tools and apply some 
   # customisation (e.g. cloning boost_python to make a boost_regex which differs
   # in which lib it provides)
   #
   # Would need to provide:
   # - A menu with a list of setup tools
   #
   #
   # Initial Implementation
   # ----------------------
   #
   # - Handle a list of supported languages and the compilers which support
   #   each language type. Note that there should be support for more than
   #   one compiler version (e.g. gcc323 vs. gcc 344 via same cxxcompiler tool)
   #
   # - Separate tabs for each compiler type. Also separate into categories of flags
   #   (e.g. for linking, for compilation, for linking binaries, plugins(?) etc.).
   #
   # - Implement the mechanism for changing the architecture via a selection panel
   #   where a user can choose which compiler to use as default (and each compiler
   #   already has a default string like "_gccXXX" which would be added to the arch
   #   stem).
   #
   # Must have the following variables set in the compiler tools:
   #
   #        SCRAM_COMPILER_NAME e.g., gcc323
   #        SCRAM_LANGUAGE_TYPE e.g., C++ (upper-case)
   #
   #
   my $help_string = "";
   $help_string .= "This GUI can be used to modify compiler settings\n";
   $help_string .= "and to set compiler-dependent architectures.\n";
   
   # To record whether something was modified:
   my $tool_cache_status={};
   
   my $compiler_tools = {};
   my $compiler_db = $self->toolmanager()->scram_compiler();
   my $supported_lang_list = [ sort keys %$compiler_db ];
   my $comp_data_content = {};
   my $comp_data_content_new = {};

   while (my ($langtype, $ctool) = each %$compiler_db)
      {
      print "LANG TYPE $langtype provided by ".$ctool->[0]." with arch suffix ".$ctool->[1]."\n",
      if ($ENV{SCRAM_DEBUG});
      # Now get the tool corresponding to the this lang type:
      $compiler_tools->{$langtype} = $self->toolmanager()->checkifsetup($ctool->[0]);
      # Populate a hash with the data for the compiler tool for this lang type:
      $comp_data_content->{$langtype} = $compiler_tools->{$langtype}->allflags();
      # Set the status of the tool object to 0. Change it to 1 if something in the
      # tool was changed:
      $tool_cache_status->{$langtype} = 0;
      }

   # Set the initial page to be the first supported language type:
   my $sel_lang_type=uc($supported_lang_list->[0]);

   # Geometry is set automatically:
   my $mw = MainWindow->new();
   $mw->title("SCRAM Compiler Option Window");
   
   # The notebook widget and its tabs:
   my $notebook = $mw->NoteBook();

   # Add the tabs:
   my $comp_opts_tab = $notebook->add( "Sheet 1", -label => "Compilation Options" );
   my $link_opts_tab = $notebook->add( "Sheet 2", -label => "Linker Options" );
   my $debug_opts_tab= $notebook->add( "Sheet 3", -label => "Debugging Options" );
   my $arch_opts_tab = $notebook->add( "Sheet 4", -label => "Architecture Options" );

   # We want a frame at the top for buttons:
   my $f = $mw->Frame(-relief => 'ridge', -bd => 2)
      ->pack(-side => 'top', -anchor => 'n', -expand => 1, -fill => 'x');
   
   # We want a frame at the bottom for status messages:
   my $f_bottom = $mw->Frame(-relief => 'ridge', -bd => 2)
      ->pack(-side => 'bottom', -anchor => 'n', -expand => 1, -fill => 'x');
   
   # A menu button inside the top frame, for exitting:
   my $exit_b = $f->Button(-text => "Save&Exit",
			   -background => "red",
			   -foreground => 'yellow',
			   -activebackground => 'orange',
			   -activeforeground => 'black',			
			   -command => sub {

			   foreach my $langt (keys %{$tool_cache_status})
			      {
			      # Only write the changes to the cache if our status flag changed:
			      if ($tool_cache_status->{$langt})
				 {
				 print "SAVE/EXIT: Updating toolmanager copy of ".$compiler_db->{$langt}->[0]."\n",
				 if ($ENV{SCRAM_DEBUG});				 
				 $self->toolmanager()->updatetool($compiler_db->{$langt}->[0], $compiler_tools->{$langt});
				 }
			      }
			   exit;
			   })->pack(-side => 'right');
   
   my $help_b = $f->Button(-text => "Help",
			   -background => "lightblue",
			   -foreground => 'black',
			   -activebackground => 'white',
			   -activeforeground => 'black',
			   -command => sub
			      {
			      $f->messageBox(-title => "help", -message => $help_string, -type => 'ok');
			      })->pack(-side => 'left');
   
   my $top_label_message = "Select a language type to display compiler metadata.";
   my $top_label_region = $mw->Label(-textvariable => \$top_label_message,
				     -anchor => 'w',
				     -relief => 'flat',
				     -width => 90)->pack(-anchor => 'n');

   # Pack the notebook widget:
   $notebook->pack( -fill => 'y', -expand => 1);
   
   # Main comp widget embedded in the notebook tab. This is the widget in which the
   # label widgets are added:
   my $comp_entrymain = $comp_opts_tab->Text(-width => 90,
					     -wrap => 'none')->pack(-expand => 1, -fill => 'both');
   my %comp_dataentry_label;
   my %comp_dataentry_entry;
   
   # Set up the compiler window first:
   foreach my $f (keys %{$comp_data_content->{$sel_lang_type}})      
      {
      $comp_data_content_new->{$sel_lang_type}->{$f}=join(" ",@{$comp_data_content->{$sel_lang_type}->{$f}});
      
      $comp_dataentry_label{$f} = $comp_entrymain->Label(-text => $f,
							 -anchor => 'w',
							 -relief => 'flat',
							 -width => 25);
      $comp_entrymain->windowCreate('end', -window => $comp_dataentry_label{$f});
      
      $comp_dataentry_entry{$f} = $comp_entrymain->Entry(-width => 63,
							 -background => 'lemonchiffon',
							 -textvariable => $comp_data_content_new->{$sel_lang_type}->{$f});
      $comp_entrymain->windowCreate('end', -window => $comp_dataentry_entry{$f});
      $comp_entrymain->insert('end', "\n");      
      }
   
   my $lang_b = $f->Menubutton(-textvariable => \$sel_lang_type,
			       -background => 'grey70',
			       -relief => 'raised',
			       -foreground => 'darkgreen',
			       -activebackground => 'grey18',
			       -activeforeground => 'ivory',			
			       -menuitems => [ map { [ 'command' => $_,
						       -command => [ sub
									{
									$top_label_message = "Showing compiler info for ".$_[0]."\n";
									$sel_lang_type=uc($_[0]);

									# Delete the existing text widget and re-generate it:
									$comp_entrymain->destroy() if Tk::Exists($comp_entrymain);
									$comp_entrymain = $comp_opts_tab->Text(-width => 90,
													       -wrap => 'none')->pack(-expand => 1, -fill => 'both');
									
									# Set up the compiler window first:
									foreach my $f (keys %{$comp_data_content->{$sel_lang_type}})
									   {
									   $comp_data_content_new->{$sel_lang_type}->{$f}=join(" ",@{$comp_data_content->{$sel_lang_type}->{$f}});
									   
									   $comp_dataentry_label{$f} = $comp_entrymain->Label(-text => $f,
															      -anchor => 'w',
															      -relief => 'flat',
															      -width => 25);
									   $comp_entrymain->windowCreate('end', -window => $comp_dataentry_label{$f});
									   
									   $comp_dataentry_entry{$f} = $comp_entrymain->Entry(-width => 63,
															      -background => 'lemonchiffon',
															      -textvariable => $comp_data_content_new->{$sel_lang_type}->{$f});
									   $comp_entrymain->windowCreate('end', -window => $comp_dataentry_entry{$f});
									   $comp_entrymain->insert('end', "\n");
									   
									   # When the cursor leaves the entry widget, track the event:
									   $comp_dataentry_entry{$f}->bind('<Leave>', [
														       sub {
														       my $new_value = $_[0]->get();
														       
														       if ($new_value ne $comp_data_content_new->{$sel_lang_type}->{$f})
															  {
															  $comp_data_content->{$sel_lang_type}->{$f} = [ split(' ',$new_value) ];
															  # Write the changes to the compiler tool object:
															  $compiler_tools->{$sel_lang_type}->updateflags($f,$comp_data_content->{$sel_lang_type}->{$f}),"\n";
															  # This compiler tool was changed:
															  $tool_cache_status->{$sel_lang_type} = 1;
															  }
														       }, $e ]
													   );						   
									   }
									
									# Disable the text widget:
									$comp_entrymain->configure( -state => 'disabled');									
									}, $_ ]
						       ],
									   } @$supported_lang_list ]
			       )->pack(-side => 'left');
   
   # Finally disable the text widget (not the entry widgets, obviously):
   $comp_entrymain->configure( -state => 'disabled');
   
   # The architecture opts:
   my $arch_entrymain = $arch_opts_tab->Text(-width => 90,
					     )->pack(-expand => 1, -fill => 'both');
   my $arch_dataentry;
   my $sysarch=$self->system_architecture();
   my $current_arch_string="Current system architecture is: ".$sysarch."_";

   $arch_dataentry = $arch_entrymain->Label(-text => $current_arch_string,
					    -anchor => 'w',
					    -relief => 'flat',
					    -width => length($current_arch_string));
   
   $arch_entrymain->windowCreate('end', -window => $arch_dataentry);

   # Add a browse entry widget for each compiler arch name:
   my $compiler_arch_name="gcc323";
   my $known_comp_types=[qw( gcc323 gcc344 icc81 )];

   my $arch_be = $arch_entrymain->BrowseEntry( -variable => \$compiler_arch_name,
					       -choices => $known_comp_types,
					       -state => 'normal' )->pack(-side => 'right');
   
   $arch_entrymain->windowCreate('end', -window => $arch_be);

   my $arch_status_message = "Selected SCRAM_ARCH is ".$sysarch."_";


   my $arch_msg_b = $arch_entrymain->Label(-text => $arch_status_message,
					      -anchor => 'w',
					      -relief => 'flat',
					      -width => length($arch_status_message)-2);
   
   $arch_entrymain->windowCreate('end', -window => $arch_msg_b);

   my $arch_status_b = $arch_entrymain->Label(-textvariable => \$compiler_arch_name,
					      -anchor => 'w',
					      -relief => 'flat',
					      -width => length(\$compiler_arch_name));
   
   $arch_entrymain->windowCreate('end', -window => $arch_status_b);

   # Disable at the end:
   $arch_entrymain->configure( -state => 'disabled');
   
   my $silly_b = $arch_entrymain->Button(-text => "OK",
					 -background => "orange",
					 -foreground => 'black',
					 -activebackground => 'black',
					 -activeforeground => 'orange',			
					 -command => sub
					    {
					    # Interact with the rest of SCRAM by setting the architecture
					    # in the main block. Then, make the change persistent via
					    # a file(?) or %ENV entry:
					    
					    print "Full arch = ",$sysarch."_".$compiler_arch_name,"\n";
					    })->pack(-side => 'bottom');
   

   # Pack the status label into bottom frame:
   my $statusmessage;
   my $statuscolour="Red";
   my $status_label = $f_bottom->Label(-foreground => $statuscolour,
				       -textvariable => \$statusmessage)
      ->pack(-side => 'left', -fill => 'x');
   
   # Track mouse and react when buttons are focussed:
   $status_label->bind('<Enter>', [ sub {$statusmessage = ""}, $message]);   
   $exit_b->bind('<Enter>', [ sub {$statusmessage = "Save changes (if any) and exit.";}, $message]);
   $help_b->bind('<Enter>', [ sub {$statusmessage = "Show help";}, $message]);
   $lang_b->bind('<Enter>', [ sub {$statusmessage = "Select the language type (e.g. F77, C, C++)";}, $message]);

   $comp_opts_tab->bind('<Enter>', [ sub {$statusmessage = "Make changes to compiler flags";}, $message]);
   $link_opts_tab->bind('<Enter>', [ sub {$statusmessage = "Make changes to linker flags";}, $message]);
   $debug_opts_tab->bind('<Enter>', [ sub {$statusmessage = "Set debug options";}, $message]);
   $arch_opts_tab->bind('<Enter>', [ sub {$statusmessage = "Set architecture options";}, $message]);

   $exit_b->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $help_b->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $lang_b->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);

   $comp_opts_tab->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $link_opts_tab->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $debug_opts_tab->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $arch_opts_tab->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);

   foreach my $f (keys %{$comp_data_content->{$sel_lang_type}})
      {
      # When the cursor leaves the entry widget, track the event:
      $comp_dataentry_entry{$f}->bind('<Leave>', [
						  sub {
						  my $new_value = $_[0]->get();
						  
						  if ($new_value ne $comp_data_content_new->{$sel_lang_type}->{$f})
						     {
						     $comp_data_content->{$sel_lang_type}->{$f} = [ split(' ',$new_value) ];
						     # Write the changes to the compiler tool object:
						     $compiler_tools->{$sel_lang_type}->updateflags($f,$comp_data_content->{$sel_lang_type}->{$f}),"\n";
						     # This compiler tool was changed:
						     $tool_cache_status->{$sel_lang_type} = 1;
						     }
						  }, $e ]
				      );
      }
   
   # Enter the main loop:
   MainLoop();   
   }

=item   C<show_tools_gui()>

GUI functions.
   
=cut

sub show_tools_gui()
   {
   my $self=shift;

   eval "use Tk;"; $self->missing_package('Tk') if $@;   
   eval "use Tk::NoteBook;"; $self->missing_package('Tk::NoteBook') if $@;
   eval "use Tk::BrowseEntry;"; $self->missing_package('Tk::BrowseEntry') if $@;
   eval "use Tk::DialogBox;"; $self->missing_package('Tk::DialogBox') if $@;

   # Notes:
   # ------
   #
   # Could also use this interface as a way to clone other tools and apply some 
   # customisation (e.g. cloning boost_python to make a boost_regex which differs
   # in which lib it provides)
   #   
   my $help_string = "";
   $help_string .= "This GUI can be used to modify tool settings\n";
   $help_string .= "or clone tools and modify them to create new tools.\n";
   
   # Geometry is set automatically:
   my $mw = MainWindow->new();
   $mw->title("SCRAM Tool Editor Window");

   my $t_db = [ $self->toolmanager()->tools() ];

   # We want a frame at the top for buttons:
   my $f = $mw->Frame(-relief => 'ridge', -bd => 2)
      ->pack(-side => 'top', -anchor => 'n', -expand => 1, -fill => 'x');
   
   # We want a frame at the bottom for status messages:
   my $f_bottom = $mw->Frame(-relief => 'ridge', -bd => 2)
      ->pack(-side => 'bottom', -anchor => 'n', -expand => 1, -fill => 'x');

   # A menu button inside the top frame, for exitting:
   my $exit_b = $f->Button(-text => "Save&Exit",
			   -background => "red",
			   -foreground => 'yellow',
			   -activebackground => 'orange',
			   -activeforeground => 'black',			
			   -command => sub { exit; })->pack(-side => 'right');
   
   # Pop up a message box with help:
   my $help_b = $f->Button(-text => "Help",
			   -background => "lightblue",
			   -foreground => 'black',
			   -activebackground => 'white',
			   -activeforeground => 'black',			
			   -command => sub
			      {
			      $f->messageBox(-title => "help", -message => $help_string, -type => 'ok');
			      })->pack(-side => 'left');
   
   # The tools menu:
   my $tool_entrymain;
   my $bf_entrymain;   
   my $top_label_message = "Select an action: clone/edit a tool or create a BuildFile.\n";

   # The notebook widget and its tabs:
   my $notebook = $mw->NoteBook()->pack( -fill => 'y', -expand => 1);
   
   $tool_editor_tab = $notebook->add( "Sheet 1", -label => "Tool Editor", -raisecmd => sub { });
   $buildfile_helper_tab = $notebook->add( "Sheet 2", -label => "BuildFile Helper",
					   -raisecmd => sub
					      {
					      $top_label_message="Create a BuildFile for the current package by scanning the source files";
					      use SCRAM::DepTracker;
					      # Eventually the source and include dir names should
					      # be defined in the site defaults:
					      my $dtracker = SCRAM::DepTracker->new("src","interface");
					      $bf_entrymain->delete('1.0','end');
					      $bf_entrymain->insert('end',$dtracker->show_buildfile());
					      });
   
   # Main widgets in the notebook:
   $tool_entrymain = $tool_editor_tab->Text(-width => 90,
					    -wrap => 'none')->pack(-expand => 1, -fill => 'both');
   
   $bf_entrymain = $buildfile_helper_tab->Text(-width => 90,
					       -wrap => 'none')->pack(-expand => 1, -fill => 'both');

   my ($tool_option_b, $tool_option_b_c,$tool_option_b_e);
   my $tool_loaded;
   my $tool_selector_b = $tool_editor_tab->Menubutton(-text => "Tools",
						      -relief => 'ridge',
						      -background => "grey18",
						      -foreground => 'ivory',
						      -activebackground => 'white',
						      -activeforeground => 'black',
						      -menuitems => [ map { [ 'command' => $_,
									      -command => [ sub
											       {
											       $tool_loaded = $_[0];
											       # Allow text in the widget to be edited:
											       $tool_entrymain->configure(-state => 'normal');
											       # Delete all existing text:
											       $tool_entrymain->delete('1.0','end');
											       # Load up the file into the text widget. Sometimes the file will
											       # not exist locally so good idea to warn if this is so << FIXME:
											       open(TOOL,"< ".$ENV{LOCALTOP}."/.SCRAM/InstalledTools/".$_[0]);
											       while (<TOOL>)
												  {
												  next if ($_ =~ /^\#.*/);
												  $tool_entrymain->insert('end',$_);
												  }
											       
											       close(TOOL);
											       
											       # Set status message:
											       $top_label_message="Tool ".$_[0]." loaded.\n";
											       # Now that a tool is loaded, activate the buttons:
											       $tool_option_b->configure( -state => 'normal');
											       $tool_option_b_c->configure( -state => 'normal');
											       $tool_option_b_e->configure( -state => 'normal');
											       # Disable until we actually want to edit:
											       $tool_entrymain->configure(-state => 'disabled');
											       }, $_ ]
									      ],
												  } @$t_db ]
						      )->pack(-side => 'left');
   
   
   # Now pack new button into top button bar:
   $tool_option_b = $tool_editor_tab->Button(-text => "New",
					     -background => "blue",
					     -foreground => 'yellow',
					     -activebackground => 'yellow',
					     -activeforeground => 'blue',			
					     -command => sub
						{
						$top_label_message="Creating a new tool from $tool_loaded\n";
						$tool_entrymain->configure(-state => 'normal');
						$tool_entrymain->insert('end',"\n##### < just to test text insertion > ####");
						   })
      ->pack(-side => 'left', -anchor => 'n');
   
   $tool_option_b_c = $tool_editor_tab->Button(-text => "Clone",
					       -background => "magenta",
					       -foreground => 'yellow',
					       -activebackground => 'yellow',
					       -activeforeground => 'magenta',			
					       -command => sub
						  {
						  $top_label_message="Creating a new tool by cloning $tool_loaded\n";						  
						  })
      ->pack(-side => 'left', -anchor => 'n');
   
   $tool_option_b_e = $tool_editor_tab->Button(-text => "Edit",
					       -background => "lightyellow",
					       -foreground => 'grey15',
					       -activebackground => 'grey15',
					       -activeforeground => 'lightyellow',			
					       -command => sub
						  {
						  $top_label_message="Editing $tool_loaded\n";

						  my $dialog = $mw->DialogBox(-title => "Editing tool $tool_loaded",
									      -buttons => ["OK", "Cancel"]);						  
						  my $t_edit_main = $dialog->Text(-width => 90,
										  -wrap => 'none')->pack(-expand => 1, -fill => 'both');
						  my $this_tool = $self->toolmanager()->checkifsetup($tool_loaded);						  

						  # If someone tries to edit a compiler tool, return (perhaps with
						  # a nice warning message):
						  if ($this_tool->scram_compiler())
						     {
						     $top_label_message="Warning: unable to edit a compiler tool with this GUI.\nUse \"scram ui -edit comp\" instead.";
						     return;
						     }
						  
						  # Get the features:
						  my $tool_features = $this_tool->allfeatures();
						  my $t_dt_label_content={};
						  my $t_dt_label_entry={};
						  
						  foreach my $f (keys %$tool_features)
						     {
						     $t_dt_label_content->{$f} = $tool_features->{$f};
						     $t_dt_label= $dialog->Label(-text => $f, -anchor => 'w', -relief => 'flat', -width => 25);
						     $t_edit_main->windowCreate('end', -window => $t_dt_label);						     
						     $t_dt_label_entry->{$f} = $t_edit_main->Entry(-width => 63,
												   -background => 'lemonchiffon',
												   -textvariable => $t_dt_label_content->{$f});
						     $t_edit_main->windowCreate('end', -window => $t_dt_label_entry->{$f});
						     $t_edit_main->insert('end', "\n");
						     }
						  
						  # Disable the rest of the text widget:
						  $t_edit_main->configure( -state => 'disabled' );

						  # Finally, display the dialog box:
						  my $button_pressed=$dialog->Show();

						  if ($button_pressed =~ /OK/)
						     {
						     my $update_status=0;
						     foreach my $f (keys %$tool_features)
							{						     
							my $new_value = $t_dt_label_entry->{$f}->get();							

							if ($new_value ne $t_dt_label_content->{$f})
							   {
							   $update_status=1;
							   if ($this_tool->can(lc($f)))
							      {
							      my $subrtn=lc($f);
							      # Reset the array:
							      $this_tool->reset($f);
							      $this_tool->$subrtn([ split(" ", $new_value) ]);
							      }
							   else
							      {
							      $this_tool->variable_data($f,$new_value);
							      }
							   }
							}
						     # Update the copy of the tool in the cache
						     # if some value really changed:
						     $self->toolmanager()->updatetool($tool_loaded, $this_tool), if ($update_status);
						     }
						  })->pack(-side => 'left', -anchor => 'n');
   
   # Both buttons are disabled until a tool is selected:
   $tool_option_b->configure( -state => 'disabled');
   $tool_option_b_c->configure( -state => 'disabled');
   $tool_option_b_e->configure( -state => 'disabled');
   
   # The top-level message widget:
   my $top_label_region = $mw->Label(-textvariable => \$top_label_message,
				     -anchor => 'w',
				     -relief => 'flat',
				     -width => 90)->pack(-anchor => 'n');
   
   # Pack the status label into bottom frame:
   my $statusmessage;
   my $statuscolour="Red";
   my $status_label = $f_bottom->Label(-foreground => $statuscolour,
				       -relief => 'flat',
				       -textvariable => \$statusmessage)
      ->pack(-side => 'left', -fill => 'x', -anchor => 'w');
   
   # Track mouse and react when buttons are focussed:
   $status_label->bind('<Enter>', [ sub {$statusmessage = ""}, $message]);   
   
   $exit_b->bind('<Enter>', [ sub {$statusmessage = "Save changes (if any) and exit.";}, $message]);
   $help_b->bind('<Enter>', [ sub {$statusmessage = "Show help";}, $message]);

   $tool_selector_b->bind('<Enter>', [ sub {$statusmessage = "Select a tool to modify or clone";}, $message]);
   $tool_editor_tab->bind('<Enter>', [ sub {$statusmessage = "Create, edit or clone tools";}, $message]);
   $buildfile_helper_tab->bind('<Enter>', [ sub {$statusmessage = "Create a BuildFile for the current package"; $top_label_message="";}, $message]);
   
   $exit_b->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $help_b->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);

   $tool_selector_b->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $tool_editor_tab->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   $buildfile_helper_tab->bind('<Leave>', [ sub {$statusmessage = "";}, $message]);
   
   # Enter the main loop:
   MainLoop();
   }

sub dbghook_()
   {
   my $self=shift;
   my (@ARGS) = @_;
   local @ARGV = @ARGS;
   # Return nice value:
   return 0;
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
      
   # Return nice value: 
   return 0;
   }


#### End of CMD.pm ####
1;


=back
   
=head1 AUTHOR/MAINTAINER

Shaun ASHBY

=cut

