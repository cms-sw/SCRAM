#____________________________________________________________________ 
# File: ToolManager.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-11-12 15:04:16+0100
# Revision: $Id: ToolManager.pm,v 1.19.2.2 2008/02/19 15:06:03 muzaffar Exp $ 
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

sub init ()
   {
   my $self=shift;
   my $projectarea=shift;
   $self->{topdir}=$projectarea->location();
   $self->{configdir}=$self->{topdir}."/".$projectarea->configurationdir();
   $self->{archstore}=$projectarea->archdir();
   $self->{toolcache}=$self->{configdir}."/toolbox/".$projectarea->arch()."/tools";
   $self->name($projectarea->toolcachename());
   $self->dirty();
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
   my @selected=();
   my $tooldir=$self->{toolcache}."/selected";
   foreach my $tool (@{&getfileslist($tooldir)})
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
   
   my $toolparser = BuildSystem::ToolParser->new();
   $toolparser->filehead('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><doc type="BuildSystem::ToolDoc" version="1.0">');
   $toolparser->filetail('</doc>');
   $toolparser->parse($toolfile);
   my $toolname = $toolparser->toolname();
   my $toolversion = $toolparser->toolversion();
   scramlogmsg("\n",$::bold."Setting up ",$toolname," version ",$toolversion,":  ".$::normal,"\n");
   
   # Next, set up the tool:
   my $store = $toolparser->processrawtool($self->interactive());

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
   $self->storeincache($toolname,$store);
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
      symlink("../available/${toolname}.xml",$desfile); 
      }
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
      $selfparser = BuildSystem::ToolParser->new();
      $selfparser->filehead ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><doc type="BuildSystem::ToolDoc" version="1.0">');
      $selfparser->filehead ('</doc>');
      $selfparser->parse($filename);

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
      scramlogmsg("\n");
      }
   else
      {
      scramlogdump();
      print "\n";
      print "SCRAM: No file config/Self.xml...nothing to do.";
      print "\n";
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
   return $tooldata;
   }

sub _toolsdata()
   {
   my $self = shift;
   my $tool=shift;
   my $data=shift || [];
   if(exists $self->{internal}{donetools}{$tool}){return;}
   $self->{internal}{donetools}{$tool}=1;
   if (exists $self->{SETUP}{$tool})
      {
      if (exists $self->{SETUP}{$tool}{USE})
         {
	 foreach my $use (@{$self->{SETUP}{$tool}{USE}}){$self->_toolsdata(lc($use),$data);}
	 }
      push @$data,$self->{SETUP}{$tool};
      }
   }

sub _toolsdata_scram()
   {
   my $self = shift;
   my $tool=shift;
   my $data=shift || [];
   if(exists $self->{internal}{donetools}{$tool}){return;}
   if(!exists $self->{internal}{scram_tools}{$tool}){return;}
   $self->{internal}{donetools}{$tool}=1;
   use Configuration::ConfigArea;
   use Cache::CacheUtilities;
   my $cache=uc($tool)."_BASE";
   $cache=$self->{SETUP}{$tool}{$cache};
   if (!-d $cache)
      {
      print "ERROR: Release area \"$cache\" for \"$tool\" is not available.\n";
      return;
      }
   my $area=Configuration::ConfigArea->new();
   $area->location($cache);
   my $cachefile=$area->toolcachename();
   if (!-f $cachefile)
      {
      print "ERROR: Tools cache file for release area \"$cache\" is not available.\n";
      $self->{internal}{donetools}{$tool}=1;
      return;
      }
   $cache=&Cache::CacheUtilities::read($cachefile);
   my $tools=$cache->setup();
   foreach my $use (keys %$tools)
      {
      if ($tools->{$use}->scram_project() == 1)
	 {
	 $self->_toolsdata_scram($use,$data);
	 }
      }
   push @$data,$self->{SETUP}{$tool};
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
   my $tool = $self->{SETUP}{$toolname};
   if ($tool->scram_compiler() == 1)
      {
      while (my ($langtype, $ctool) = each %{$self->{SCRAM_COMPILER}})
         {
	 if ($toolname eq $ctool->[0]){delete $self->{SCRAM_COMPILER}->{$langtype};}
	 }
      }
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
      if ((!defined $obj) && (-f $tfile)) {unlink $tfile;}
      elsif ((defined $obj) && (!-f $tfile))
         {
         Utilities::AddDir::adddir($instdir);
	 my $ref;
         open($ref,">$tfile");
         close($ref);
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
