#____________________________________________________________________ 
# File: ToolCache.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-28 10:14:08+0100
# Revision: $Id: ToolCache.pm,v 1.1.2.6 2004/11/23 13:17:16 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::ToolCache;
require 5.004;

use Exporter;
@ISA=qw(Exporter);
#
sub new()
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;   
   my $self =
      {
      DOWNLOADED => { tools => undef, url => undef },     # Downloaded tool infos;
      SELECTED => undef,     # The selected tools (info from RequirementsDoc);
      DEFAULTVERSIONS => {}, # Hash of tools and their default version;
      RAW => [],             # The tools to be set up (the raw data from the tool docs);
      SETUP => {},           # The saved set-up data;
      STAMP => undef         # The last time the cache was modified
	 };                
   
   bless $self,$class;
   return $self;
   }

sub downloadedtools()
   {
   my $self=shift;
   # Returns an array of downloaded tools, basically all
   # those listed in configuration:
   @_ ? $self->{DOWNLOADED}{tools} = shift # 
      : $self->{DOWNLOADED}{tools};
   }

sub defaultversions()
   {
   my $self=shift;
   # Returns a hash of tools and their default versions:
   @_ ? $self->{DEFAULTVERSIONS} = shift # 
      : $self->{DEFAULTVERSIONS};
   }

sub toolurls()
   {
   my $self=shift;
   # Returns a hash of tools and their URLs:
   @_ ? $self->{DOWNLOADED}->{url} = shift # 
      : $self->{DOWNLOADED}->{url};
   }

sub selected()
   {
   my $self=shift;
   # Returns hash of selected tools:
   @_ ? $self->{SELECTED} = $_[0]
      : $self->{SELECTED};
   }

sub addtoselected()
   {
   my $self=shift;
   my ($toolname)=@_;
   # When "scram setup X" is used to add new tool to environment, we need a way to add this tool
   # to the list of selected tools. Otherwise, runtime env won't work.
   # Need to check to see if this tool already exists in the SELECTED hash.
   # Only try to add a new rank if tool doesn't already exist:
   if (! exists $self->{SELECTED}->{$toolname})
      {
      # First, check the highest rank (just number of elements [i.e., keys in hash]). Next
      # tool added will get next number:
      my $nextrank = (keys %{$self->{SELECTED}}) + 1;
      $self->{SELECTED}->{$toolname} = $nextrank;
      }
   }

sub store()
   {
   my $self=shift;
   # Store ToolParser objects (tools not set up yet):
   @_ ? push(@{$self->{RAW}},@_) #
      : @{$self->{RAW}};
   }

sub rawtools()
   {
   my $self=shift;
   # Return a list of tools
   return @{$self->{RAW}};
   }

sub setup()
   {
   my $self=shift;
   # Returns a hash of toolname/ToolData objects (set-up tools):
   return $self->{SETUP};
   }

sub cleanup_raw()
   {
   my $self=shift;
   my ($tremoved)=@_;
   my $newrtools=[];
   
   # Remove the tool from the list of raw tool objects:
   foreach my $rawtool (@{$self->{RAW}})
      {
      # Find the tool name from the ToolParser object $rawtool:
      if ($tremoved eq $rawtool->toolname())
	 {
	 print "Removing ToolParser $tremoved from cache.","\n";
	 }
      else
	 {
	 push(@{$newrtools},$rawtool);
	 }
      }

   # Remove from list of selected tools and version list:
   delete $self->{SELECTED}->{$tremoved};
   delete $self->{DEFAULTVERSIONS}->{$tremoved};
   # Now save the new tool list:
   $self->{RAW} = $newrtools;
   }

sub inheritcontent()
   {
   my $self=shift;
   my ($externaltm)=@_;

   # Inherit all tool data from an external scram-managed project.
   # Basically copy RAW, SETUP and SELECTED hash data:
   $self->{RAW} = [ $externaltm->rawtools() ];
   $self->{SETUP} = $externaltm->setup();

   my $tmpselected = $externaltm->selected();
   
   # We add the downloaded SELECTED entries to our existsing SELECTED data
   # in the same order as they already appear:
   foreach my $entry ( sort { %{$tmpselected}->{$a}
			      <=> %{$tmpselected}->{$b}}
		       keys %{$tmpselected} )
      {
      # Now add them to selected data:
      $self->addtoselected($entry);
      }   
   }

### Read/write from/to cachefile:
sub name()
   {
   my $self = shift;
   # Set the name of the cache file:
   @_ ? $self->{CACHENAME} = shift #
      : $self->{CACHENAME};
   }

sub writecache()
   {
   my $self=shift;
   use Cache::CacheUtilities;
   &Cache::CacheUtilities::write($self,$self->{CACHENAME});
   }

1;
   
