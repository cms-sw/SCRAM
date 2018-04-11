#____________________________________________________________________ 
# File: CMD.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
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

=item   C<arch()>

Print the current SCRAM_ARCH to STDOUT.
   
=cut

sub arch()
   {
   print $ENV{SCRAM_ARCH},"\n";
   return (0);
   }

sub config()
   {
   my $self=shift;
   my $val = undef;
   my $key = shift(@_) || "";
   if ($key eq ""){return $main::SITE->dump();}
   ($key,$val)=split("=",$key,2);
   if (defined $val){return $main::SITE->set($key,$val);}
   $val=$main::SITE->get($key);
   if (!defined $val){return(1);}
   $main::SITE->dump($key);
   return (0);
   }

sub tool()
   {
   my $self=shift;
   my (@ARGS) = @_;
   local @ARGV = @ARGS;
   my $rval=0;
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
      } qw( list info tag remove);

   # Print help and exit if no command matched:
   if ($status)
      {
      $self->scramfatal("Unknown command argument. See \"scram tool -help\" for usage info.");
      $rval = 1;
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
   my $setuptoolnames = $self->toolmanager()->toolsdata();
   
   # Exit if there aren't any tools:
   $self->scramerror(">>>> No tools set up for current arch or area! <<<<"),if ( scalar(@$setuptoolnames) <= 0); 
   
   # We have some tools:
   my $locationstring="Tool list for location ".$self->localarea()->location();
   my $length=length($locationstring);
   
   print "\n",$locationstring,"\n";
   print "+"x $length;
   print "\n";
   print "\n";
   
   # Show list:
   foreach $t (@$setuptoolnames)
      {
      printf " %-20s %-10s\n",$t->toolname(),$t->toolversion();
      }
   
   print "\n";
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
   
   # Get the setup tool object:
   my $sut;
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
      $self->scramerror(">>>> Tool ".$toolname." is not setup for this project area. <<<<");
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

   $self->scramfatal("Not enough args: see \"scram tool -help\" for usage info."), if (!$toolname);
   
   if ($sut=$self->toolmanager()->checkifsetup($toolname))
      {
      print "Removing tool ",$toolname," from current project area configuration.","\n";
      # Remove the entry from our setup tools list:
      $self->toolmanager()->remove_tool($toolname);
      $self->update_external_symlinks_(1);
      }
   else
      {
      $self->scramerror(">>>> Tool ".$toolname." is not defined for this project area. <<<<");
      exit(1);
      }
   
   # Return nice value:
   return 0;
   }

=item   C<version([ $version ])>

Print the version of SCRAM. If $version argument is given, run $version of SCRAM.
Install locally if it is not already available.
   
=cut

sub version()
   {
   print $ENV{SCRAM_VERSION},"\n";
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
      ("compact|c" => sub { $opts{SCRAM_LISTCOMPACT} = 1 },
       "all|a"     => sub { $opts{SCRAM_LISTALL} = 1 },
       "exists|e"  => sub { $opts{SCRAM_VALID_PROJECTS} = 1 } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram list -help\" for usage info.");
      exit(1);
      }
   else
      {
      # The project data:
      my $scramdb = $self->scramprojectdb();
      my $project = shift(@ARGV);
      my $projectversion = shift(@ARGV);
      if ($projectversion eq "")
         {
         $projectversion=$project;
         $project=~s/_.*//;
         if (!$scramdb->hasProject($project)){$project="";}
         }
      my $projects = $scramdb->listall(uc($project),$projectversion,$opts{SCRAM_VALID_PROJECTS},$opts{SCRAM_LISTALL});
      if (scalar(keys %$projects)==0)
         {
         my $arch_msg="";
         if ($main::FORCE_SCRAM_ARCH ne ""){$arch_msg=" for architecture $ENV{SCRAM_ARCH}";}
         if ($projectversion ne "")
            {
            $self->scramwarning(">>>> No SCRAM project $project version $projectversion available$arch_msg. <<<<");
            print STDERR "You can run \"scram list $project\" to see the available versions.\n";
            }
         elsif ($project ne "")
            {
            $self->scramwarning(">>>> No SCRAM project $project available$arch_msg. <<<<");
            print STDERR "You can run \"scram list\" to see the available projects and their versions.\n";
            }
         else
            {
            $self->scramwarning(">>>> There are no SCRAM project yet installed$arch_msg. <<<<");
            }
         exit(1);
         }

      my $headstring = sprintf("| %-12s  | %-24s | %-33s |","Project Name","Project Version","Project Location");
      my $linebold = "$::bold"."$::line"."$::normal";
      foreach my $arch (sort keys %$projects) {
         if (!$opts{SCRAM_LISTCOMPACT})
            {
            print "\n","Listing installed projects available for platform >> ".$::bold."$arch".$::normal." <<\n\n";
            print $linebold,"\n";
            print $headstring."\n";
            print $linebold,"\n\n";
            }
         foreach my $item (@{$projects->{$arch}})
            {
            my $pstring = "";
            if ($opts{SCRAM_LISTCOMPACT}){$pstring = sprintf "%-15s %-25s %-50s",$item->[0],$item->[1],$item->[2];}
            else{$pstring = sprintf "  %-15s %-25s  \n%45s%-30s",$item->[0],$item->[1],"--> ",$::bold.$item->[2].$::normal;}
            print "$pstring\n";
            }
         }
      }
   return 0;
   }

=item   C<db()>

Show the location of the local SCRAM project database and any other databases that are linked.
   
=cut

sub db()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my $db="";
   my %opts = ( SCRAM_DB_SHOW => 0, SCRAM_DB_LINK => 0, SCRAM_DB_UNLINK => 0 );
   my %options =
      ("show|s"   => sub { $opts{SCRAM_DB_SHOW} = 1 },
       "link|l=s"   => sub { $opts{SCRAM_DB_LINK} = 1; $db = $_[1] },
       "unlink|u=s" => sub { $opts{SCRAM_DB_UNLINK} = 1; $db = $_[1] } );
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order bundling);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram db -help\" for usage info.");
      }
   else
      {
      $ENV{SCRAM_LOOKUPDB} = $ENV{SCRAM_LOOKUPDB_WRITE};
      if ($opts{SCRAM_DB_LINK})
	 {
	 if ( -d $db )
	    {
	    if ($self->scramprojectdb()->link($db)==0)
	       {
	       print "Current SCRAM database: ",$::bold.$ENV{SCRAM_LOOKUPDB}.$::normal,"\n";
	       print "Linked \"$db\" to current SCRAM database.\n";
	       }
	    }
	 else
	    {
	    $self->scramerror("Can not link to SCRAM-DB. No such directory: $db");
	    }
	 }
      elsif ($opts{SCRAM_DB_UNLINK})
	 {
	 if ($self->scramprojectdb()->unlink($db)==0)
	    {
	    print "Current SCRAM database: ",$::bold.$ENV{SCRAM_LOOKUPDB}.$::normal,"\n";
	    print "Unlinked \"$db\" from current SCRAM database.\n";
	    }
	 }
      elsif ($opts{SCRAM_DB_SHOW})
	 {
	 print "Current SCRAM database: ",$::bold.$ENV{SCRAM_LOOKUPDB}.$::normal,"\n";
	 my $links=$self->scramprojectdb()->listlinks();
	 my $flag=0;
	 foreach my $type ("local","linked")
	    {
	    if (scalar(@{$links->{$type}})==0) { next;}
	    $flag=1;
	    print "The following SCRAM databases are linked ";
	    if ($type eq "local"){print "directly:\n";}
	    else {print "in-directly:\n";}
	    foreach my $extdb (@{$links->{$type}})
	       {
	       print "\t".$extdb."\n";
	       }
	    print "\n";
	    }
	 if ($flag == 0) {print "There are no SCRAM databases linked.\n";}
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
   my $dircache="${wrkdir}/DirCache.db.gz";
   my $builddatastore="${wrkdir}/ProjectCache.db.gz";
   
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
   my $ignore_arch = 0;
   my %options =
      ("verbose|v"  => sub { $ENV{SCRAM_BUILDVERBOSE} = 1 },
       "testrun|t"  => sub { $opts{SCRAM_TEST} = 1 },
       "ignore-arch"  => sub { $ignore_arch = 1 },
       "reset|r"    => sub { if ($cachereset==0){ $cachereset=1; print "Resetting caches","\n"; system("rm","-rf",$builddatastore,"${workingdir}/MakeData/DirCache* ${workingdir}/MakeData/ExtraBuilsRules")}},
       "fast|f"     => sub { print "Skipping cache scan...","\n"; $fast=1 },
       "convertxml|c"  => sub { $convertxml =1 } );
   
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
      eval "use SCRAM::Plugins::RuntimeEnv";
      my $env=SCRAM::Plugins::RuntimeEnv->new($self);
      $env->runtimebuildenv();
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

      if ( (-r $cachename) && (!$fast) )
	 {
	 print "Reading cached data","\n",if ($ENV{SCRAM_DEBUG});
	 my $xcache=&Cache::CacheUtilities::read($cachename);
	 if (defined $xcache) {$cacheobject=$xcache;}
	 }
      if (-x "$ENV{SCRAM_CONFIGDIR}/ProjectInit")
         {
	 print "Running $ENV{SCRAM_CONFIGDIR}/ProjectInit script","\n",if ($ENV{SCRAM_DEBUG});
	 my $rv = system("$ENV{SCRAM_CONFIGDIR}/ProjectInit");
	 print "Script exitted with status ",$rv,"\n",if ($ENV{SCRAM_DEBUG});
         }
      if ( (!-f $builddatastore) || (-z $builddatastore))
         {
         $cachereset=1;
         }

      # Set verbosity for cache object:
      $cacheobject->verbose($ENV{SCRAM_CACHEDEBUG});
      # Check for BuildFiles (config dir and src) and track timestamps of contents
      # of config dir (templates, for example):
      $cacheobject->checkfiles($cachereset,$convertxml) unless $fast;
      
      if ($cacheobject->cachestatus())
         {
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
	    my $xcache=&Cache::CacheUtilities::read($builddatastore);
	    if (defined $xcache) {$buildstoreobject=$xcache;}
	    }
	    # Update- check for changed or removed files. Also need to account for removed directories:
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
	 }
      if ($convertxml)
         {
	 return $self->convert2xml ($cacheobject,$buildstoreobject);
	 }
      if ( -f $ENV{SCRAM_INTwork}."/Makefile")
	 {
	 $cacheobject=();$buildstoreobject=();
	 my $chkarch = "${wrkdir}/chkarch";
	 if ($ignore_arch && (-e $chkarch))
	    {
	    if (! unlink($chkarch))
	       {
	       $self->scramerror("Could not delete $chkarch: $!");
	       }
	    }
	 if (-e $chkarch)
	    {
	    my $os = $self->cmsos();
	    if ($ENV{SCRAM_ARCH}!~/^$os/)
	       {
	       $self->scramwarning("You are trying to compile/build for architecture $ENV{SCRAM_ARCH} on ".uc($os)." OS which might not work.\n".
	                         "If you know this SCRAM_ARCH/OS combination works then please first run 'scram build --ignore-arch'.");
	       }
	    }
	 my $returnval = $MAKER->exec($ENV{SCRAM_INTwork}."/Makefile"),
	 if (! $opts{SCRAM_TEST});
	 print "MAKE not actually run: test build mode!","\n",if ($opts{SCRAM_TEST});
	 return $returnval;
	 }
      else
	 {
	 $self->scramerror("No Makefile in working dir. \nPlease delete .SCRAM/".
	                   $ENV{SCRAM_ARCH}."/ProjectCache.db.gz then rebuild.");
	 exit(1);
	 }
      }
   return 0;
   }
   
sub convert2xml ()
   {
   my $self=shift;
   my $dircache=shift;
   my $buildobj=shift || undef;
   my $convertor;
   my @bfs=();
   my $bfn=$ENV{SCRAM_BUILDFILE};
   foreach my $bf (keys %{$dircache->{BFCACHE}})
      {
      if ($bf=~/\/${bfn}.xml$/){next;}
      if ((!-f $bf) || (-f "${bf}.xml")){next;}
      push @bfs,$bf;
      }
   my $count=scalar(@bfs);
   if ($count)
      {
      my $convertor=undef;
      eval ("use SCRAM::Plugins::Doc2XML");
      if (!$@){$convertor = SCRAM::Plugins::Doc2XML->new(1);}
      else
         {
         print STDERR "**** WARNING: Can not convert $ENV{SCRAM_BUILDFILE} in to XML format. Missing SCRAM::Plugins::Doc2XML perl module.\n";
         return 1;
         }
      if (!defined $buildobj)
         {
	 use Cache::CacheUtilities;
	 $buildobj = &Cache::CacheUtilities::read("$ENV{LOCALTOP}/.SCRAM/$ENV{SCRAM_ARCH}/ProjectCache.db.gz");
	 }
      my $done=0;
      my $src=$ENV{SCRAM_SOURCEDIR};	 
      foreach my $bf (@bfs)
         {
	 $convertor->clean();
	 print ">> Converting $bf => ${bf}.xml\n";
	 my $xml=$convertor->convert($bf);
	 if (open($fref,">${bf}.xml"))
	    {
	    foreach my $line (@$xml){print $fref "$line\n";}
	    close($fref);
	    $done++;
	    $dircache->{BFCACHE}{"${bf}.xml"}=$dircache->{BFCACHE}{$bf};
	    delete $dircache->{BFCACHE}{$bf};
	    my $pack=$bf;
	    $pack=~s/^$src\/(.+)\/$bfn$/$1/;
	    if (exists $dircache->{PACKMAP}{$pack}){$pack = $dircache->{PACKMAP}{$pack};}
	    if ((exists  $buildobj->{BUILDTREE}{$pack}) && (exists $buildobj->{BUILDTREE}{$pack}{METABF}))
	       {
	       pop @{$buildobj->{BUILDTREE}{$pack}{METABF}};
	       push @{$buildobj->{BUILDTREE}{$pack}{METABF}},"${bf}.xml";
	       }
	    }
	 else{print STDERR "**** WARNING: Can not open file for writing: ${bf}.xml\n";}
	 }
      if ($done)
         {
	 &Cache::CacheUtilities::write($buildobj,$buildobj->{CACHENAME});
	 &Cache::CacheUtilities::write($dircache,$dircache->{CACHENAME});
	 print "$done non-XML BuildFile converted.\n"; 
	 }
      }
   }

=item   C<project()>
   
Create a SCRAM developer area or bootstrap a new SCRAM project area.

=cut

sub project()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my ($installdir, $installname);
   my ($bootfile,$bootstrapfile);
   my $symlinks=0;
   my %opts = ();
   my $force=0;
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
      ("force|f"  => sub { $force = 1; },
       "dir|d=s"  => sub { $installdir = $_[1] },
       "name|n=s" => sub { $installname = $_[1] },
       "log|l"    => sub { scramloginteractive(1); },
       "symlinks|s"=> sub { $symlinks=1; },
       "boot|b=s" => sub { $bootstrapfile = 'file:'.$_[1]; $bootfile = $_[1] },
       "update|u" => sub { $self->scramerror("Command-line argument \"--update\" is no more supported."); }
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
      if (defined $bootstrapfile)
	 {
	 $self->bootnewproject($bootstrapfile,$installdir);
	 }
      else
	 {
	 my $projectname = shift(@ARGV);
	 my $projectversion = shift(@ARGV) || undef;
	 my $projPath=undef;
	 if (!defined $projectversion)
	    {
	    if ((-d $projectname) && ($projectname=~/^\//o))
	       {
	       require Configuration::ConfigArea;
	       $projPath = Configuration::ConfigArea->new()->searchlocation($projectname);
	       if (!defined $projPath){$self->scramerror("Not a valid scram-based release area: $projectname");}
	       $projectname=basename($projPath);
	       }
	    $projectversion=$projectname; $projectname=~s/_.*$//;
	    }
	 $self->bootfromrelease(uc($projectname),$projectversion,$installdir,$installname,$symlinks,$projPath,$force);
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
    my ($projectname,$projectversion,$installdir,$installname,$symlinks,$projPath,$force) = @_;
    my $iname=$installname || $projectversion;
    if ($projectname && $projectversion) {
	my $scramdb = $self->scramprojectdb();
	my $relarea=undef;
	if ($projPath)
	{$relarea=$scramdb->getAreaObject([$projectname,$projectversion, $projPath, undef], undef);}
	else{$relarea=$scramdb->getarea($projectname,$projectversion,$force);}
	if ((!defined $relarea) || (!-d $relarea->archdir()))
	   {
	   if ((exists $scramdb->{deprecated}) && ($scramdb->{deprecated}==0)){exit 1;}
	   my $list = $scramdb->{listcache};
	   my @archs=keys %$list;
	   if (scalar(@archs)>1)
	      {
	      print STDERR "ERROR: Project \"$projectname\" version \"$projectversion\" is not available for arch $ENV{SCRAM_ARCH}.\n",
	                   "       \"$projectversion\" is currently available for following archs.\n",
			   "       Please set SCRAM_ARCH properly and re-run the command.\n    ",join("\n    ",@archs),"\n";
	      }
	   else
	      {
	      print STDERR "ERROR: Unable to find release area for \"$projectname\" version \"$projectversion\" for arch $ENV{SCRAM_ARCH}.\n",
	                   "       Please make sure you have used the correct name/version.\n",
			   "       You can run \"scram list $projectname\" to get the list of available versions.\n";
	      }
	   exit 1;
	   }
	my $xarch = $ENV{SCRAM_ARCH};
	$ENV{SCRAM_ARCH} = $relarea->archname();
	if (-d "${installdir}/${iname}/".$relarea->admindir()."/$ENV{SCRAM_ARCH}")
	   {
	   print STDERR "WARNING: There already exists ${installdir}/${iname} area for SCRAM_ARCH $ENV{SCRAM_ARCH}.\n";
	   exit 0;
	   }
	$self->remote_versioncheck($relarea);

	# From here, we're creating a new area which uses the same version of SCRAM as is accessed from the commandline (i.e.
	# the current version):
	scramlogclean();
	scramlogmsg("Creating a developer area based on project ",$projectname,", version ",$projectversion,"\n");

	# Set RELEASETOP:
	$ENV{RELEASETOP} = $relarea->location();
	# Check that the areas are compatible:
	$self->checkareatype($ENV{RELEASETOP},"Project release area SCRAM version mismatch: current is V1, area is V0. Exiting.");
	$area = $relarea->satellite($installdir,$installname,$symlinks,$self->localarea());
	chdir ($area->location());
	$self->initx_();
	# Read the top-level BuildFile and create the required storage dirs. Do
	# this before setting up self:
	$self->create_productstores($area->location(),$symlinks);
        if (exists $relarea->{basedir})
           {
           my $basedir_file;
           if (open($basedir_file, "> ".$area->location()."/".$area->{configurationdir}."/scram_basedir"))
              {
              print $basedir_file $relarea->{basedir};
              close($basedir_file);
              }
           }
	my $toolmanager = $self->toolmanager($area);
	$toolmanager->update ($area);

	# Write the cached info:
	$toolmanager->writecache();
	
        my $temp=$area->location()."/".$area->{admindir}."/".$ENV{SCRAM_ARCH};
        if (-f "${temp}/MakeData/Tools.mk")
           {
	   my $t1=(stat("${temp}/MakeData/Tools.mk"))[9];
	   utime $t1-1,$t1-1,"${temp}/MakeData/Tools.mk";
	   if (-f "${temp}/timestamps/self")
	      {
	      utime $t1,$t1,"${temp}/timestamps/self";
	      }
           }
	
	scramlogmsg("\n\nInstallation procedure complete.\n");
	scramlogmsg("Developer area located at:\n\n\t\t".$area->location()."\n\n");
	if ($xarch ne $ENV{SCRAM_ARCH}) 
	   {
	   print "WARNING: Release $projectversion is not available for architecture $xarch.\n";
	   print "         Developer's area is created for available architecture $ENV{SCRAM_ARCH}.\n";
	   }
	my $os = $self->cmsos();
	if ($ENV{SCRAM_ARCH}!~/^$os/)
	   {
	   print "WARNING: Developer's area is created for architecture $ENV{SCRAM_ARCH} while your current OS is ",uc($os),".\n";
	   }
	if (! $force)
	   {
	   $os = $scramdb->productionArch($projectname,$projectversion, $relarea->location());
	   if ((defined $os) && ($ENV{SCRAM_ARCH} ne $os))
	      {
	      print "WARNING: Developer's area is created for non-production architecture $ENV{SCRAM_ARCH}. Production architecture for this release is $os.\n";
	      }
	   }
        my $tc = $scramdb->getProjectModule($projectname);
        if (defined $tc) { $tc->getData($projectversion, $ENV{RELEASETOP}); }
        if (! exists $ENV{SCRAM_IGNORE_PROJECT_HOOK})
           {
           my $proj_hook = $area->location()."/".$area->{configurationdir}."/SCRAM/hooks/project-hook";
           if (-x $proj_hook){system($proj_hook);}
           }
        if ( $ENV{'SCRAM_TOOL_HOME'} =~ /^\/afs\/cern\.ch\// )
           {
           print "****************************** WARNING ******************************\n";
           print "You are using CMSSW from CERN AFS space. Please note that, by the start of 2017, new CMSSW releases shall only be available via CVMFS.\n";
           print "See the announcement https://hypernews.cern.ch/HyperNews/CMS/get/swDevelopment/3374.html \n";
           }
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
   my ($bootstrapfile,$installarea)=@_;

   use BuildSystem::ToolManager;
   use Configuration::BootStrapProject;
   # Set up the bootstrapper:
   my $bs=Configuration::BootStrapProject->new($installarea);
   my $area=$bs->boot($bootstrapfile, $installarea);
   my $name=$area->location();

   # Add ToolManager object to store all tool info:
   my $toolmanager = BuildSystem::ToolManager->new($area);

   # Need an autotoolssetup object:
   $ENV{'SCRAM_PROJECTDIR'} = $area->location();
   $ENV{'SCRAM_PROJECTVERSION'} = $area->version();
   $ENV{'LOCALTOP'} = $ENV{'SCRAM_PROJECTDIR'};
   
   # Now set up selected tools:
   scramlogmsg("Setting up tools in project area","\n");
   scramlogmsg("------------------------------------------------\n\n");

   $toolmanager->setupalltools();

   # Read the top-level BuildFile and create the required storage dirs. Do
   # this before setting up self:
   $self->create_productstores($area->location(),0);
   # Now setup SELF:
   $toolmanager->setupself();

   # Write the cached info:
   $toolmanager->writecache();

   scramlogmsg("\n>> Installation Located at: ".$area->location()." <<\n\n");

   # Return nice value:
   return 0;
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

sub setupnewarch_()
   {
   my $self=shift;
   my $interactive=shift;
   scramloginteractive(0);
   my $toolbox="$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/toolbox";
   if (!-d "${toolbox}/$ENV{SCRAM_ARCH}")
      {
      use File::Basename;
      my $area=$self->localarea();
      my $loc = $area->location();
      $self->bootfromrelease($area->name(),$area->version(),dirname($loc),basename($loc),$area->symlinks());
      return 1;
      }
   else
      {
      return 0;
      }
   }
=item   C<setup()>

Set up tools in the current project area.
   
=cut

sub setup()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my %opts;
   my %options =
      ("force|f" => sub { $ENV{SCRAM_FORCE}=1 },
       "interactive|i" => sub { print STDERR "****WARNING: obsolete command-line argument '-i'\n"});
   
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

      my $tool = shift(@ARGV);
      if ($tool ne "")
         {
	 my $file=0;
         if ($tool=~s/^\s*file://i)
	    {
	    $file=1;
	    if ($tool!~/^\//) {$tool=cwd()."/$tool";}
	    }
	 if ($file)
	    {
	    if (!-f $tool){die "ERROR: Can not setup tool. No such file found: $tool.";}
	    }
	 elsif (!-f $tool)  
	    {
	    my $lctool=lc($tool);
	    if ($lctool ne "self")
	       {
	       $tool = "$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/toolbox/$ENV{SCRAM_ARCH}/tools/selected/${lctool}.xml";
               if (!-f $tool)
                  {
	          $tool = "$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/toolbox/$ENV{SCRAM_ARCH}/tools/available/${lctool}.xml";
	          if (!-f $tool)
	             {
		     die "ERROR: Can not setup tool \"$lctool\" because of missing \"${lctool}.xml\" file under $ENV{SCRAM_CONFIGDIR}/toolbox/$ENV{SCRAM_ARCH}/tools directory.\n";
		     }
	          }
	       }
	    else{$tool=$lctool;}
	    }
	 elsif($tool!~/^\//) {$tool=cwd()."/$tool";}
         }
      elsif ($self->setupnewarch_ ())
         {
	 return;
	 }
      
      # Get the tool manager:
      my $toolmanager = $self->toolmanager();
      
      if ($tool)
	 {
	 if ($tool ne "self"){$toolmanager->coresetup($tool);}
	 else
	    {
	    $self->create_productstores($self->localarea()->location());
	    $toolmanager->setupself();
	    }
	 }
      else
	 {
	 print "Setting up all tools in current area","\n";

	 # If there isn't a ToolCache.db.gz file where we expect it, it implies that
	 # we are setting up tools for the n'th platform:
	 if (! -f $self->localarea()->toolcachename())
	    {
	    $self->create_productstores($self->localarea()->location());	    
	    $toolmanager->setupself();
	    }
	 
	 $toolmanager->setupalltools();
	 }
      
      # Write to the tool cache and exit:
      my $dirty=$toolmanager->isdirty() || $toolmanager->istooldirty();
      $toolmanager->writecache();
      $self->update_external_symlinks_($dirty);
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
   my $SCRAM_RT_SHELL="";
   #
   # NB: Overall environment/path ordering: SELF, TOOLS, USER
   #     Eventually sort topologically (by going through list of tools and
   #     seeing which tools those tools depend on, then sorting the list)
   #
   my %opts = ( SCRAM_RT_DUMP => "" );
   my %options =
      ("sh"     => sub { $SCRAM_RT_SHELL = 'BOURNE' },
       "csh"    => sub { $SCRAM_RT_SHELL = 'TCSH'  },
       "win"    => sub { $SCRAM_RT_SHELL = 'CYGWIN' },
       "dump=s" => sub { $opts{SCRAM_RT_DUMP} = $_[1] } );
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram runtime -help\" for usage info.");
      }
   else
      {
      local @ARGV;
      foreach my $a (@ARGS)
        {
        if (($a=~/^\//) && (-d $a)) {chdir $a; $self->{localarea}=undef; $self->initx_();}
        else{push @ARGV,$a;}
        }
      # Check to see if we are in a local project area:
      $self->checklocal();

      # Also check to see that we received a shell argument:
      $self->scramfatal("No shell type given! See \"scram runtime -help\" for usage info."), if ($SCRAM_RT_SHELL eq '');
      
      eval "use SCRAM::Plugins::RuntimeEnv";
      die "Cache $file load error: ",$@,"\n", if ($@);
      my $env=SCRAM::Plugins::RuntimeEnv->new ($self);
      $env->optional_env(@ARGV);
      $env->save ($SCRAM_RT_SHELL);
      
      print "Using ",$SCRAM_RT_SHELL," shell syntax","\n", if ($ENV{SCRAM_DEBUG});
      my $ref;
      if ($opts{SCRAM_RT_DUMP} ne "")
	 {
	 print "Dumping RT environment to file ",$opts{SCRAM_RT_DUMP},"\n";
	 open($ref,"> ".$opts{SCRAM_RT_DUMP} ) || die $!,"\n";
	 }
      $env->setenv($SCRAM_RT_SHELL,$ref);
      if ($main::ORIG_SCRAM_ARCH ne $ENV{SCRAM_ARCH})
      {
        my $sd = $env->{shell}{$SCRAM_RT_SHELL};
	my $cmd = $sd->{EXPORT}." SCRAM_ARCH".$sd->{EQUALS}."\"".$ENV{SCRAM_ARCH}."\";\n";
	if ($ref){print $ref "$cmd";}
	else{print STDOUT "$cmd";}
      }
      if ($ref){close($ref);}
      }
   return 0;
   }

=item   C<runtime()>

Set the runtime environment for the current area.
   
=cut

sub unsetenv()
   {
   my $self=shift;
   my (@ARGS) = @_;
   my $SCRAM_RT_SHELL="";
   my %opts = ();
   my %options =
      ("sh"     => sub { $SCRAM_RT_SHELL = 'BOURNE' },
       "csh"    => sub { $SCRAM_RT_SHELL = 'TCSH'  },
       "win"    => sub { $SCRAM_RT_SHELL = 'CYGWIN' });
   
   local @ARGV = @ARGS;
   
   Getopt::Long::config qw(default no_ignore_case require_order);
   
   if (! Getopt::Long::GetOptions(\%opts, %options))
      {
      $self->scramfatal("Error parsing arguments. See \"scram unsetenv -help\" for usage info.");
      }
   else
      {
      $self->scramfatal("No shell type given! See \"scram unsetenv -help\" for usage info."), if ($SCRAM_RT_SHELL eq '');
      
      eval "use SCRAM::Plugins::RuntimeEnv";
      die "Cache $file load error: ",$@,"\n", if ($@);
      my $env=SCRAM::Plugins::RuntimeEnv->new ($self);
      print "Using ",$SCRAM_RT_SHELL," shell syntax","\n", if ($ENV{SCRAM_DEBUG});
      $env->unsetenv($SCRAM_RT_SHELL);
      }
   return 0;
   }

sub update_external_symlinks_()
   {
   my ($self,$dirty)=@_;
   if (($dirty) &&
       (-x "$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/SCRAM/linkexternal.pl"))
      {
      print "Updating symlinks under external/$ENV{SCRAM_ARCH}\n";
      system("cd $ENV{LOCALTOP}; $ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/SCRAM/linkexternal.pl  --arch $ENV{SCRAM_ARCH}");
      }
   }

#### End of CMD.pm ####
1;


=back
   
=head1 AUTHOR/MAINTAINER

Shaun ASHBY

=cut

