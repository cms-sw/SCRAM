#____________________________________________________________________ 
# File: ToolManager.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-11-12 15:04:16+0100
# Revision: $Id: ToolManager.pm,v 1.13 2005/10/07 16:05:44 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::ToolManager;
require 5.004;

use Exporter;
use BuildSystem::ToolCache;
use BuildSystem::ToolParser;
use Utilities::AddDir;
use URL::URLhandler;
use Utilities::Verbose;

@ISA=qw(BuildSystem::ToolCache Utilities::Verbose);
@EXPORT_OK=qw( );
#

sub new
   ###############################################################
   # new                                                         #
   ###############################################################
   # modified : Wed Nov 12 10:34:10 2003 / SFA                   #
   # params   :                                                  #
   #          :                                                  #
   # function :                                                  #
   #          :                                                  #
   ###############################################################
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self=$class->SUPER::new();    # Inherit from ToolCache
   my $projectarea=shift;

   bless $self,$class;
   
   $self->{arch}=shift;
   $self->{topdir}=$projectarea->location();
   $self->{configdir}=$self->{topdir}."/".$projectarea->configurationdir();
   $self->{cache}=$projectarea->cache();    # Download tool cache
   $self->{toolfiledir}=$self->{topdir}."/.SCRAM/InstalledTools";
   $self->{datastore}=$self->{topdir}."/.SCRAM";
   $self->{archstore}=$self->{topdir}."/.SCRAM/".$ENV{SCRAM_ARCH};
   
   # Make sure our tool download dir exists:
   AddDir::adddir($self->{toolfiledir});
   AddDir::adddir($self->{archstore});
   
   # Set the tool cache file to read/write:
   $self->name($projectarea->toolcachename());

   # Check for the downloaded tools cache:
   if (exists($self->{cache}))
      {
      $self->{urlhandler}=URL::URLhandler->new($self->{cache});
      }
   
   return $self;
   }

sub clone()
   {
   my $self=shift;
   my $projectarea=shift;

   # Change cache settings to reflect the new location:
   $self->{topdir}=$projectarea->location();

   $self->{configdir}=$self->{topdir}."/".$projectarea->configurationdir();
   $self->{toolfiledir}=$self->{topdir}."/.SCRAM/InstalledTools";
   $self->{datastore}=$self->{topdir}."/.SCRAM";
   $self->{archstore}=$self->{topdir}."/.SCRAM/".$ENV{SCRAM_ARCH};

   # Change the cache name:
   $self->name($projectarea->toolcachename());
   $self->cloned_tm(1);
   
   return $self;
   }

sub arch_change_after_copy()
   {
   my $self=shift;
   my ($newarch, $cachename)=@_;
   # Make changes to arch-specific settings when copying tool manager
   # object to another arch during setup:
   $self->{arch} = $newarch;
   $self->{archstore} = $self->{topdir}."/.SCRAM/".$newarch;
   # Change the name of the cache to reflect new (arch-specific) location:
   $self->name($cachename);
   }

sub interactive()
   {
   my $self=shift;
   # Interactive mode on/off:
   @_ ? $self->{interactive} = shift
      : ((defined $self->{interactive}) ? $self->{interactive} : 0);
   }

sub setupalltools()
   {
   my $self = shift;
   my ($arealocation,$setupopt) = @_;
   my (@localtools);
   my $selected;
   
   # Get the selected tool list. Handle the case where there might not be
   # any selected tools: //FIXME: need to handle case where there are no
   # selected tools (not very often but a possibility):
   my $sel = $self->selected();
   
   if (defined ($sel))
      {
      $selected = [ keys %{$sel} ];
      }
   
   # Setup option "setupopt" directs the setup: 1 is for booting from
   # scratch, 0 is when just doing "scram setup" (in this case we don't
   # want to pick up everything from any scram-managed projects):
   if ($setupopt == 1) # We're booting from scratch
      {
      # Check to see if there are any SCRAM-managed projects in our local requirements:
      my $scramprojects = $::scram->_loadscramdb();
      
      # Look for a match in the scram db:
      foreach my $S (@$selected)
	 {
	 if (exists ($scramprojects->{$S}))
	    {
	    # Now check the version required exists in
	    # list of scram projects with this name:
	    while (my ($pdata,$plocation) = each %{$scramprojects->{$S}})
	       {
	       # Split the $pdata string to get the real name and the version:
	       my ($pname,$pversion) = split(":",$pdata);
	       if ($pversion eq $self->defaultversion($S))
		  {
		  # Get the tool manager for the scram project:
		  my $sa=$::scram->scramfunctions()->scramprojectdb()->getarea($pname,$pversion);
		  # Load the tool cache:
		  if ( -r $sa->toolcachename())
		     {
		     use Cache::CacheUtilities;
		     my $satoolmanager=&Cache::CacheUtilities::read($sa->toolcachename());
		     # Copy needed content from toolmanager for scram-managed project only
		     # if the projects have compatible configurations (compare first set of
		     # digits):
		     if ($self->check_compatibility($satoolmanager))
			{
			print "DEBUG: $pname and current project have compatible configurations.\n";
			$self->inheritcontent($satoolmanager);
			}
		     else
			{			
			print "DEBUG: $pname and current project do NOT have compatible configurations. Skipping...\n";
			}
		     }
		  }
	       }
	    # Also add this scram-managed project to list of tools to set up:
	    push(@localtools,$S);
	    }
	 else
	    {
	    # Store other tools in ReqDoc in separate array. We will set up these tools later:
	    push(@localtools,$S);
	    }
	 }
      
      # Set up extra tools required in this project, in addition to
      # any scram-managed projects
      foreach my $localtool (@localtools)
	 {
	 # First check to see if it's already set up (i.e., was contained
	 # in list of requirements for scram project):
	 if (! $self->definedtool($localtool))
	    {
	    $self->toolsetup($arealocation,$localtool,$self->defaultversion($localtool));
	    $self->addtoselected($localtool);
	    }
	 else
	    {
	    print $localtool," already set up.","\n",if ($ENV{SCRAM_DEBUG});
	    }
	 }
      }
   else
      {
      # Just loop over all tools and setup again:
      foreach my $localtool (@{$selected})
	 {
	 $self->toolsetup($arealocation,$localtool,$self->defaultversion($localtool));	 
	 }
      }
   
   print "\n";
   }

sub coresetup()
   {
   my $self=shift;
   my ($toolname, $toolversion, $toolfile, $force) = @_;
   my ($toolcheck, $toolparser);
   
   print "\n";
   print $::bold."Setting up ",$toolname," version ",$toolversion,":  ".$::normal,"\n";
   
   # New ToolParser object for this tool if there isn't one already.
   # Look in array of raw tools to see if this tool has a ToolParser object:
   $toolcheck=0;
   
   map
      {
      if ($_->toolname() eq $toolname) {$toolcheck = 1; $toolparser = $_;}
      } $self->rawtools();
   
   # Tool not known so we create a new ToolParser object and parse it:
   if ($toolcheck != 1 || $force == 1)
      {
      $toolparser = BuildSystem::ToolParser->new();
      # We only want to store the stuff relevant for one particular version:
      $toolparser->parse($toolname, $toolversion, $toolfile);
      # Store the ToolParser object in the cache:
      $self->store($toolparser);
      print "\nFile $toolfile reparsed (modified)","\n",if ($ENV{SCRAM_DEBUG});
      }
   
   # Next, set up the tool:
   my $store = $toolparser->processrawtool($self->interactive());
   # Make sure that we have this tool in the list of selected tools (just in case this tool was
   # set up by hand afterwards):
   $self->addtoselected($toolname);

   # Check to see if this tool is a compiler. If so, store it.
   # Also store the language that this compiler supprots, and a
   # compiler name (e.g. gcc323) which, in conjunction with a stem
   # architecture name like slc3_ia32_, can be used to build a complete arch string:
   if ($store->scram_compiler() == 1)
      {
      my @supported_language = $store->flags("SCRAM_LANGUAGE_TYPE");
      my @compilername = $store->flags("SCRAM_COMPILER_NAME");
      $self->scram_compiler($supported_language[0],$toolname,$compilername[0]);
      }
   
   # Store the ToolData object in the cache:
   $self->storeincache($toolparser->toolname(),$store);
   return $self;
   }

sub toolsetup()
   {
   my $self=shift;
   my ($arealocation, $toolname, $toolversion, $toolurl) = @_;
   my ($urlcache, $url, $filename, $tfname);
   my $toolfile;
   my $force = 0; # we may have to force a reparse of a tool file
   
   $toolname =~ tr[A-Z][a-z];
   $toolversion ||= $self->defaultversion($toolname);
   $urlcache=URL::URLcache->new($arealocation."/.SCRAM/cache"); # Download tool cache
   
   # Check for the downloaded tools cache:
   if (defined($urlcache))
      {
      $self->{urlhandler}=URL::URLhandler->new($urlcache);
      }

   $url = $self->toolurls()->{$toolname};
   $filename = $self->{toolfiledir}."/".$toolname;
   
   # If .SCRAM/InstalledTools doesn't exist, create it:
   if (! -d $self->{toolfiledir})
      {
      AddDir::adddir($self->{toolfiledir});
      }
   
   # First, check to see if there was a tool URL given. If so, we might need to read
   # from http or from a file: type URL:
   if (my ($proto, $urlv) = ($toolurl =~ /(.*):(.*)/))
      {      
      # See what kind of URL (file:, http:, cvs:, svn:, .. ):
      if ($proto eq 'file')
	 {
	 # Check to see if there is a ~ and substitute the user
	 # home directory if there is (file:~/xyz):	 
	 if (my ($urlpath) = ($urlv =~ m|^\~/(.*)$|))
	    {
	    $urlv = $ENV{HOME}."/".$urlpath;
	    }
	 elsif (my ($urlpath) = ($urlv =~ m|^\./(.*)$|))
	    {
	    # Relative to current directory (file:./xyz):
	    use Cwd qw(&cwd);
	    $urlv = cwd()."/".$urlpath;
	    }
	 
	 # If the tool url is a file and the file exists,
	 # copy it to .SCRAM/InstalledTools and set the
	 # filename accordingly:
	 if ( -f $urlv)
	    {
	    use File::Copy;
	    copy($urlv, $filename);
	    my $mode = 0644; chmod $mode, $filename;
	    $toolfile=$filename;
	    # Here we must account for the fact that the file tool doc may be
	    # a modified version of an existing tool in the current config. we
	    # make sure that this file is reparsed, even if there is already a
	    # ToolParser object for the tool:
	    $force = 1;
	    }
	 else
	    {
	    $::scram->scramerror("Unable to set up $toolname from URL \"$toolurl\" - $urlv does not exist!");		    
	    }
	 }
      elsif ($proto eq 'http')
	 {
	 print "SCRAM: downloading $toolname from $toolurl","\n";
	 # Download from WWW first:
	 use LWP::Simple qw(&getstore);
	 my $http_response_val = &getstore($toolurl, $filename);
	 
	 # Check the HTTP status. If doc not found, exit:
	 if ($http_response_val != 200)
	    {
	    my ($server,$doc) = ($urlv =~ m|//(.*?)/(.*)|);	    
	    $::scram->scramerror("Unable to set up $toolname: $doc not found on $server!");
	    }
	 else
	    {
	    $toolfile=$filename;
	    }
	 }
      elsif ($proto eq 'cvs')
	 {
	 print "SCRAM: downloading $toolname from $urlv using protocol $proto.","\n";
	 print "[ not yet supported ]","\n";
	 exit(0);
	 }
      elsif ($proto eq 'svn')
	 {
	 print "SCRAM: downloading $toolname from $urlv using protocol $proto.","\n";
	 print "[ not yet supported ]","\n";
	 exit(0);
	 }
      else
	 {
	 $::scram->scramerror("Unable to download $urlv! Unknown protocol \"$proto\". Bye.");
	 }
      }
   else
      {
      # Copy the downloaded tool file to InstalledTools directory:
      if ( ! -f $filename )
	 {
	 # If the URL is empty, the chances are that this tool was not downloaded to .SCRAM/InstalledTools.
	 # We signal an error and exit:
	 if ($url eq '')
	    {
	    $::scram->scramerror("$toolname was selected in project requirements but is not in the configuration!");
	    }
	 else
	    {
	    # Otherwise, we try to download it:
	    $self->verbose("Attempting Download of $url");
	    # Get file from download cache:
	    ($url,$filename)=$self->{urlhandler}->get($url);	    	    
	    use File::Copy;
	    $tfname=$self->{toolfiledir}."/".$toolname;	 
	    copy($filename, $tfname);
	    my $mode = 0644; chmod $mode, $tfname;
	    $toolfile=$tfname;
	    }
	 }
      else
	 {
	 # File already exists in the .SCRAM/InstallTools directory:
	 $toolfile=$filename;
	 }
      }
   
   # Run the core setup routine:
   $self->coresetup($toolname, $toolversion, $toolfile,$force);
   return $self;
   }

sub setupself()
   {
   my $self=shift;
   my ($location)=@_;
   # Process the file "Self" in local config directory. This is used to
   # set all the paths/runtime settings for this project:
   my $filename=$location."/config/Self";

   if ( -f $filename )
      {
      print "\n";
      print $::bold."Setting up SELF:".$::normal,"\n";
      # Self file exists so process it:
      $selfparser = BuildSystem::ToolParser->new();
      $selfparser->parse('self','SELF',$filename);

      # Next, set up the tool:
      $store = $selfparser->processrawtool($self->interactive());
      
      # If we are in a developer area, also add RELEASETOP paths:
      if (exists($ENV{RELEASETOP}))
	 {
	 print "\nAdding RELEASE area settings to self....OK","\n", if ($ENV{SCRAM_DEBUG});
	 $store->addreleasetoself();
	 }
      
      # Store the ToolData object in the cache:
      $self->storeincache($selfparser->toolname(),$store);
      print "\n";
      }
   else
      {
      print "\n";
      print "SCRAM: No file config/Self...nothing to do.";
      print "\n";
      return;
      }
   }

sub defaultversion()
   {
   my $self = shift;
   my ($tool) = @_;
   # Return default versions as taken from configuration:
   return (%{$self->defaultversions()}->{$tool});
   }

sub storeincache()
   {
   my $self=shift;
   my ($toolname,$dataobject)=@_;

   # Store ToolData object (for a set-up tool) in cache:
   if (ref($dataobject) eq 'BuildSystem::ToolData')
      {
      $self->{SETUP}->{$toolname} = $dataobject;
      }
   else
      {
      $::scram->scramerror("ToolManager: BuildSystem::ToolData object reference expected.")
      }
   }

sub tools()
   {
   my $self = shift;
   my @tools;
   
   map
      {
      if ($_ ne "self")
	 {
	 push(@tools, $_);
	 }
      } keys %{$self->{SETUP}};
   
   # Return list of set-up tools:
   return @tools;
   }

sub toolsdata()
   {
   my $self = shift;
   my $tooldata = [];
   my $rawsel = $self->selected();
   
   foreach my $tool ( sort { %{$rawsel}->{$a}
			     <=> %{$rawsel}->{$b}}
		      keys %{$rawsel} )
      {
      # Return tool data objects of all set-up tools, skipping the tool "self":
      if ($_ ne "self")
	 {
	 # Keep only tools that have really been set up:
	 if (exists $self->{SETUP}->{$tool})
	    {
	    push(@tooldata,$self->{SETUP}->{$tool});
	    }
	 }
      }
   
   # Return the array of tools, in order that they appear in RequirementsDoc:
   return @tooldata;
   }

sub definedtool()
   {
   my $self=shift;
   my ($tool)=@_;
   
   # Check to see if tool X is an external tool:
   grep ($_ eq $tool, keys %{$self->{SETUP}}) ? return 1
      : return 0;
   }

sub checkifsetup()
   {
   my $self=shift;
   my ($tool)=@_;
   # Return the ToolData object if the tool has been set up:
   (exists $self->{SETUP}->{$tool}) ? return ($self->{SETUP}->{$tool})
      : return undef;
   }

sub cloned_tm()
   {
   my $self=shift;
   # Has this area already been cloned and brought in-line with current location:
   @_ ? $self->{CLONED} = $_[0]
      : $self->{CLONED};
   }

sub remove_tool()
   {
   my $self=shift;
   my ($toolname)=@_;
   my $tools = $self->{SETUP};
   my $newtlist = {};
   
   while (my ($tool, $tooldata) = each %$tools)
      {
      if ($tool ne $toolname)
	 {
	 $newtlist->{$tool} = $tooldata;
	 }
      else
	 {
	 # Is this tool a compiler?
	 if ($tooldata->scram_compiler() == 1)
	    {
	    # Also remove this from the compiler info if there happens to be an entry:
	    while (my ($langtype, $ctool) = each %{$self->{SCRAM_COMPILER}})
	       {
	       if ($toolname eq $ctool->[0])
		  {
		  delete $self->{SCRAM_COMPILER}->{$langtype};
		  print "Deleting compiler $toolname from cache.","\n";
		  }
	       }
	    }
	 else
	    {
	    print "Deleting $toolname from cache.","\n";
	    }
	 }
      }
   
   $self->{SETUP} = $newtlist;
   
   # Now remove from the RAW tool list:
   $self->cleanup_raw($toolname);
   print "ToolManager: Updating tool cache.","\n";
   $self->writecache();
   }

sub scram_projects()
   {
   my $self=shift;
   my $scram_projects={};

   foreach my $t ($self->tools())
      {
      # Get the ToolData object:
      my $td=$self->{SETUP}->{$t};
      $scram_projects->{$t}=$td->variable_data(uc($t)."_BASE"), if ($td->scram_project());
      }
   
   return $scram_projects;
   }

sub scram_compiler()
   {
   my $self=shift;
   my ($langtype, $toolname, $compilername)=@_;

   if ($langtype)
      {
      # Store the compiler info according to supported
      # language types.
      #
      # ---------------------- e.g C++      cxxcompiler    gcc323
      $self->{SCRAM_COMPILER}->{$langtype}=[ $toolname, $compilername ];
      }
   else
      {
      return $self->{SCRAM_COMPILER};
      }
   }

sub updatetool()
   {
   my $self=shift;
   my ($name, $obj) = @_;

   # Replace the existing copy of the tool with the new one:
   if (exists $self->{SETUP}->{$name})
      {
      # Check to make sure that we were really passed a compiler with
      # the desired name:
      if ($obj->toolname() eq $name)
	 {
	 print "ToolManager: Updating the cached copy of ".$name."\n";
	 delete $self->{SETUP}->{$name};
	 $self->{SETUP}->{$name} = $obj;
	 $self->writecache();
	 }
      else
	 {
	 print "WARNING: Tool name (".$name.") and tool obj name (".$obj->toolname().") don't match!","\n";
	 print "         Not making any changes.","\n";
	 }
      }
   else
      {
      print "WARNING: No entry in cache for ".$name.". Not making any updates.\n";
      }
   }

sub check_compatibility()
   {
   my $self=shift;
   my ($itoolmgr)=@_;
   # Get the version of the toolmanager. If the project fails to return a version
   # string we return 0 for no compatibility (in which case, all tools will be set
   # up in the traditional way):
   my $itm_configversion = $itoolmgr->configversion();
   if ($itm_configversion)
      {
      # The configurations won't be identical. We must compare the digits:
      my ($numeric_version) = ($itm_configversion =~ /[a-zA-Z]*\_([0-9a-z]*).*?/);
      my $current_configversion = $self->configversion();
      my ($current_numeric_version) = ($current_configversion =~ /[a-zA-Z]*\_([0-9a-z]*).*?/);
      ($current_numeric_version == $numeric_version) && return 1; # OK, compatible;
      }
   # Project does not define configuration version so just return:
   return 0;
   }

sub configversion()
   {
   my $self=shift;
   @_ ? $self->{CONFIGVERSION} = shift
      : $self->{CONFIGVERSION};
   }

1;
