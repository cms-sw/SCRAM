#____________________________________________________________________ 
# File: ToolManager.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::ToolManager;
require 5.004;

use Exporter;
use BuildSystem::ToolCache;
use BuildSystem::ToolParser;
use Utilities::AddDir;
use Utilities::Verbose;
use SCRAM::MsgLog;

@ISA=qw(BuildSystem::ToolCache Utilities::Verbose);
@EXPORT_OK=qw( );
#

sub new
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self=$class->SUPER::new();    # Inherit from ToolCache
   bless $self,$class;
   $self->init (shift);
   return $self;
   }

sub initpathvars()
   {
   my $self=shift;
   if (!exists $self->{internal}{path_variables})
      {
      my %pathvars=("PATH", 1, "LD_LIBRARY_PATH", 1, "DYLD_LIBRARY_PATH", 1, "DYLD_FALLBACK_LIBRARY_PATH", 1, "PYTHONPATH", 1);
      my $p = $self->_parsetool($self->{configdir}."/Self.xml");
      if ((exists $p->{content}) && (exists $p->{content}{CLIENT}) && (exists $p->{content}{CLIENT}{FLAGS}))
         {
         if (exists $p->{content}{CLIENT}{FLAGS}{REM_PATH_VARIABLES})
            {
            foreach my $f (@{$p->{content}{CLIENT}{FLAGS}{REM_PATH_VARIABLES}})
               {
               delete $pathvars{$f};
               }
            }
         if (exists $p->{content}{CLIENT}{FLAGS}{PATH_VARIABLES})
            {
            foreach my $f (@{$p->{content}{CLIENT}{FLAGS}{PATH_VARIABLES}})
               {
               $pathvars{$f}=1;
               }
            }
         }
      my $paths = join("|",keys %pathvars);
      if ($paths){$paths = "^($paths)\$";}
      $self->{internal}{path_variables}=$paths;
      }
   }

sub init ()
   {
   my $self=shift;
   my $projectarea=shift;
   $self->{topdir}=$projectarea->location();
   $self->{configdir}=$self->{topdir}."/".$projectarea->configurationdir();
   $self->{archstore}=$projectarea->archdir();
   $self->{toolcache}=$self->{configdir}."/toolbox/$ENV{SCRAM_ARCH}/tools";
   $self->name($projectarea->toolcachename());
   $self->initpathvars();
   $self->dirty();
   }
  
sub setupalltools()
   {
   my $self = shift;
   my @selected=();
   my $tooldir=$self->{toolcache}."/selected";
   foreach my $tool (@{&Utilities::AddDir::getfileslist($tooldir)})
      {
      if ($tool=~/^(.+)\.xml$/) {push @selected,$1;}
      }
   foreach my $tool (@selected){$self->coresetup("${tooldir}/${tool}.xml");}
   scramlogmsg("\n");
   }

sub coresetup()
   {
   my $self=shift;
   my ($toolfile) = @_;
   
   my $toolparser = $self->_parsetool($toolfile);
   my $store = $toolparser->processrawtool();
   my $toolname = $toolparser->toolname();
   my $toolversion = $toolparser->toolversion() || "UNKNOWN";
   scramlogmsg("\n",$::bold."Setting up ",$toolname," version ",$toolversion,":  ".$::normal,"\n");

   # Store the ToolData object in the cache:   
   my $srcfile=Utilities::AddDir::fixpath($toolfile);
   my $desfile=Utilities::AddDir::fixpath($self->{toolcache}."/selected/${toolname}.xml");
   use File::Copy;
   if ($srcfile ne $desfile)
      {
      use File::Copy;
      my $desfile1=Utilities::AddDir::fixpath($self->{toolcache}."/available/${toolname}.xml");
      if ($srcfile ne $desfile1)
         {
         copy($srcfile,$desfile1);
	 }
      if (-e $desfile) { unlink($desfile);}
      symlink("../available/${toolname}.xml",$desfile); 
      }
   $self->storeincache($toolname,$store);
   scramlogclean();
   return $self;
   }

sub setupself()
   {
   my $self=shift;
   # Process the file "Self" in local config directory. This is used to
   # set all the paths/runtime settings for this project:
   my $filename=$self->{configdir}."/Self.xml";

   if ( -f $filename )
      {
      scramlogmsg("\n",$::bold."Setting up SELF:".$::normal,"\n");
      # Self file exists so process it:
      my $selfparser = $self->_parsetool($filename);
      my $store = $selfparser->processrawtool();
      # If we are in a developer area, also add RELEASETOP paths:
      if (exists($ENV{RELEASETOP}))
	 {
	 print "\nAdding RELEASE area settings to self....OK","\n", if ($ENV{SCRAM_DEBUG});
	 $store->addreleasetoself();
	 }
      
      # Store the ToolData object in the cache:
      $self->storeincache($selfparser->toolname(),$store);
      scramlogmsg("\n");
      }
   else
      {
      scramlogdump();
      print STDERR "\n";
      print STDERR "SCRAM: No file config/Self.xml...nothing to do.";
      print STDERR "\n";
      return;
      }
   }

sub update()
   {
   my $self=shift;
   my $area=shift;
   $self->init($area);
   $self->setupself();
   $self->dirty ()
   }
   
sub storeincache()
   {
   my $self=shift;
   my ($toolname,$dataobject)=@_;

   # Store ToolData object (for a set-up tool) in cache:
   if (ref($dataobject) eq 'BuildSystem::ToolData')
      {
      $self->updatetooltimestamp($dataobject, $toolname);
      delete $self->{SETUP}->{$toolname};
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
   $self->{internal}{donetools}={};
   $self->{internal}{scram_tools}={};
   foreach my $tool (sort keys %{$self->{SETUP}})
      {
      if ($self->{SETUP}{$tool}->scram_project()) {$self->{internal}{scram_tools}{$tool}=1;}
      elsif ($tool ne "self")
	 {
	 $self->_toolsdata($tool,$tooldata);
	 }
      }
   foreach my $tool (keys %{$self->{internal}{scram_tools}})
      {
      $self->_toolsdata_scram($tool,$tooldata);
      }
   delete $self->{internal}{donetools};
   delete $self->{internal}{scram_tools};
   my $data=[];
   foreach my $d (@$tooldata)
      {
      if (ref($d) eq "ARRAY")
         {
	 foreach my $t (@$d) {push @$data,$t;}
	 }
      }
   return $data;
   }

sub _parsetool()
   {
   my ($self,$filename)=@_;
   my $p = BuildSystem::ToolParser->new($self->{internal}{path_variables});
   $p->filehead ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><doc type="BuildSystem::ToolDoc" version="1.0">');
   $p->filetail ('</doc>');
   $p->parse($filename);
   return $p;
   }

sub _toolsdata()
   {
   my $self = shift;
   my $tool=shift;
   my $data=shift || [];
   my $order=-1;
   if(exists $self->{internal}{donetools}{$tool}){return $self->{internal}{donetools}{$tool};}
   $self->{internal}{donetools}{$tool}=$order;
   if (exists $self->{SETUP}{$tool})
      {
      if (exists $self->{SETUP}{$tool}{USE})
         {
	 foreach my $use (@{$self->{SETUP}{$tool}{USE}})
	    {
	    my $o=$self->_toolsdata(lc($use),$data);
	    if ($o>$order){$order=$o;}
	    }
	 }
      $order++;
      if(!defined $data->[$order]){$data->[$order]=[];}
      push @{$data->[$order]},$self->{SETUP}{$tool};
      $self->{internal}{donetools}{$tool}=$order;
      }
   return $order;
   }

sub _toolsdata_scram()
   {
   my $self = shift;
   my $tool=shift;
   my $data=shift || [];
   my $order=-1;
   if(exists $self->{internal}{donetools}{$tool}){return $self->{internal}{donetools}{$tool};}
   $self->{internal}{donetools}{$tool}=$order;
   if(!exists $self->{internal}{scram_tools}{$tool}){return $order;}
   use Configuration::ConfigArea;
   use Cache::CacheUtilities;
   my $cache=uc($tool)."_BASE";
   $cache=$self->{SETUP}{$tool}{$cache};
   if (!-d $cache)
      {
      print STDERR "ERROR: Release area \"$cache\" for \"$tool\" is not available.\n";
      return $order;
      }
   my $area=Configuration::ConfigArea->new();
   $area->location($cache);
   my $cachefile=$area->toolcachename();
   if (!-f $cachefile)
      {
      print STDERR "ERROR: Tools cache file for release area \"$cache\" is not available.\n";
      return $order;
      }
   $cache=&Cache::CacheUtilities::read($cachefile);
   my $tools=$cache->setup();
   $order=scalar(@$data)-1;
   foreach my $use (keys %$tools)
      {
      if ($tools->{$use}->scram_project() == 1)
	 {
	 my $o=$self->_toolsdata_scram($use,$data);
	 if ($o>$order){$order=$o;}
	 }
      }
   $order++;
   if(!defined $data->[$order]){$data->[$order]=[];}
   push @{$data->[$order]},$self->{SETUP}{$tool};
   $self->{internal}{donetools}{$tool}=$order;
   return $order;
   }
   
sub checkifsetup()
   {
   my $self=shift;
   my ($tool)=@_;
   # Return the ToolData object if the tool has been set up:
   (exists $self->{SETUP}->{$tool}) ? return ($self->{SETUP}->{$tool})
      : return undef;
   }

sub remove_tool()
   {
   my $self=shift;
   my ($toolname)=@_;
   delete $self->{SETUP}{$toolname};
   print "Deleting $toolname from cache.","\n";
   $self->updatetooltimestamp (undef, $toolname);
   $self->writecache();
   my $file1=$self->{toolcache}."/selected/${toolname}.xml";
   my $file2=$self->{toolcache}."/available/${toolname}.xml";
   if ((!-f $file2) && (-f $file1))
      {
      use File::Copy;
      copy ($file1,$file2);
      }
   unlink ($file1);
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

sub _tool_changed_wrt_release ()
   {
   my ($self,$toolname)=@_;
   if ((exists $ENV{SCRAM_FORCE}) || (!exists $ENV{RELEASETOP}) || ($ENV{RELEASETOP} eq "")){return 1;}
   my $tfile = "$ENV{SCRAM_CONFIGDIR}/toolbox/$ENV{SCRAM_ARCH}/tools/selected/${toolname}.xml";
   my $diff;
   my $changed=0;
   if ((-e "$ENV{RELEASETOP}/${tfile}") && (open($diff,"diff $ENV{LOCALTOP}/${tfile} $ENV{RELEASETOP}/${tfile} |")))
      {
      while (my $buf=<$diff>){$changed=1;last;}
      close($diff);
      }
   else {$changed=1;}
   return $changed;
   }

sub updatetooltimestamp ()
   {
   my $self=shift;
   my $obj=shift;
   my $toolname=shift;
   my $samevalues=0;
   my $stampdir = $self->{archstore}."/timestamps";
   my $stampfile="${stampdir}/${toolname}";
   if (exists $self->{SETUP}->{$toolname})
      {
      $samevalues=$self->comparetoolsdata($self->{SETUP}->{$toolname},$obj);
      }
   if ($toolname ne "self")
      {
      my $instdir = $self->{archstore}."/InstalledTools";
      my $tfile = "${instdir}/${toolname}";
      my $flag=0;
      if (!defined $obj)
         {
         if (-f $tfile) {$flag=-1;}
         }
      else
         {
         my $chg = $self->_tool_changed_wrt_release ($toolname);
         if ($chg)
            {
            if (!-f $tfile){$flag=1;}
            }
         elsif (-f $tfile){$flag=-1;}
         }
      if ($flag!=0)
         {
         $self->tooldirty();
         if ($flag>0)
            {
            Utilities::AddDir::adddir($instdir);
            my $ref;
            open($ref,">$tfile");
            close($ref);
            }
         else {unlink $tfile;}
         }
      }
   if ((!$samevalues) || (!-f $stampfile))
      {
      if (!-d $stampdir)
	 {
	 Utilities::AddDir::adddir($stampdir);
	 }
      my $ref;
      open($ref,">$stampfile");
      close($ref);
      if (!$samevalues){$self->dirty();}
      }
   }

sub comparetoolsdata ()
   {
   my $self=shift;
   my $data1=shift || ();
   my $data2=shift || ();
  
   my $ref1=ref($data1);
   my $ref2=ref($data2);
  
   if ($ref1 ne $ref2)
      {
      return 0;
      }
   elsif ($ref1 eq "CODE")
      {
      return 1;
      }
   elsif(($ref1 eq "SCALAR") || ($ref1 eq ""))
      {
      if ($data1 eq $data2)
         {
	 return 1;
 	 }
      return 0;
      }
   elsif ($ref1 eq "ARRAY")
      {
      my $count = scalar(@$data1);
      if ($count != scalar(@$data2))
         {
	 return 0;
	 }
      for (my $i=0; $i<$count; $i++)
	  {
	  if (! $self->comparetoolsdata($data1->[$i],$data2->[$i]))
	     {
	     return 0;
	     }
	  }
      return 1;
      }
   else
      {
      foreach my $k (keys %{$data1})
         {
         if (! exists $data2->{$k})
	    {
	    return 0;
	    }
 	 }
      foreach my $k (keys %{$data2})
         {
	 if (! exists $data1->{$k})
	    {
	    return 0;
	    }
         }
      foreach my $k (keys %{$data2})
         {
         if (! $self->comparetoolsdata($data1->{$k},$data2->{$k}))
	    {
	    return 0;
	    }
         }
      return 1;
      }
   }

1;
