#____________________________________________________________________ 
# File: Cache.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
#         (with contribution from Lassi.Tuura@cern.ch)
# Update: 2003-11-27 16:45:18+0100
# Revision: $Id: Cache.pm,v 1.3 2005/03/11 18:55:28 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package Cache::Cache;
require 5.004;

use Exporter;
@ISA=qw(Exporter);
#
sub new()
   ###############################################################
   # new                                                         #
   ###############################################################
   # modified : Thu Nov 27 16:45:27 2003 / SFA                   #
   # params   :                                                  #
   #          :                                                  #
   # function :                                                  #
   #          :                                                  #
   ###############################################################
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self=
      {
      CACHENAME => "DirCache.db",     # Name of global file/dir cache;
      BFCACHE => {},                  # BuildFile cache;
      DIRCACHE => {},                 # Source code cache;
      STATUS => 0,                    # Status of cache: 1 => something changed. If so, force save;
      VERBOSE => 0                    # Verbose mode (0/1);
      };

   bless $self,$class;
   return $self;
   }

sub getdir()
   {
   my $self=shift;
   my ($path) = @_;
   opendir (DIR, $path) || die "$path: cannot read: $!\n";
   # Skip .admin and CVS subdirectories too.
   # Also skip files that look like backup files or files being modified with emacs:
   my @items = map { "$path/$_" } grep (
					$_ ne "." && $_ ne ".." && $_ ne "CVS" && 
					$_ ne ".admin" && $_ !~ m|\.#*|,
					readdir(DIR)
					);   
   closedir (DIR);
   return @items;
   }

sub prune()
   {
   my $self=shift;
   my ($path) = @_;
   $self->cachestatus(1);
   return if ! exists $self->{DIRCACHE}->{$path};
   my (undef, undef, @subs) = @{$self->{DIRCACHE}->{$path}};
   delete $self->{DIRCACHE}->{$path};
   foreach my $sub (@subs)
      {
      $self->prune($sub);
      }
   }

sub checktree()
   {
   my ($self, $path, $required, $dofiles) = @_;
   # Check if this path needs to be checked.  If it exists, has the same mode
   # and the same time stamp, it's up to date and doesn't need to be checked.
   # Otherwise if it is a directory whose time-stamp has changed, rescan it.
   # If the path has be removed, prune it from the cache.  Note that we skip 
   # non-directories unless $dofiles is set.  Considering only directories is
   # dramatically faster.
   next if ($path =~ /\.admin/); # skip .admin dirs
   next if ($path =~ /.*CVS/);

   # NB: We stat each path only once ever.  The special "_" file handle uses
   # the results from the last stat we've made.  See man perlfunc/stat.
   if (! stat($path))
      {
      die "$path: $!\n" if $required;
      $self->logmsg("SCRAM: $path: missing: removing from cache\n");
      $self->prune($path);
      # Something changed so force write of cache:
      $self->cachestatus(1);
      return;
      }

   # If the entry in the cache is not the same mode or time, force an update.
   # Otherwise use the cache as the list of items we need to change.
   my $cached = $self->{DIRCACHE}->{$path};   
   my @items = ();

   if (! -d _)
      {
      if ($dofiles)
	 {
	 $self->logmsg("SCRAM: $path: updating cache\n");
	 $self->{DIRCACHE}->{$path} = [ (stat(_))[2, 9] ];
	 }
      else
	 {
	 $self->logmsg("SCRAM: $path: not a directory: removing from parent's list\n");
	 my $parent = $path;
	 $parent =~ s|(.*)/[^/]+$|$1|;
	 if ($parent ne $path && exists $self->{DIRCACHE}->{$parent})
	    {
	    my ($mode, $time, @subs) = @{$self->{DIRCACHE}->{$parent}};
	    $self->{DIRCACHE}->{$parent} = [ $mode, $time, grep ($_ ne $path, @subs) ];
	    }
	 $self->cachestatus(1);
	 }
      }
   elsif (! $cached || $cached->[0] != (stat(_))[2])
      {
      # When a directory is added, this block is activated
      $self->added_dirs($path); # Store the newly-added dir
      $self->logmsg("SCRAM: $path: new or changed: pruning and recreating cache\n");
      $self->prune($path);
      $self->{DIRCACHE}->{$path} = [ (stat(_))[2, 9], @items = $self->getdir($path) ];
      $required = 1;
      $self->cachestatus(1);
      }
   elsif ($cached->[1] != (stat(_))[9])
      {
      # When a subdirectory is removed, this block is activated
      #
      # This is a parent directory. We store this as any
      # update can be taken recursively from this dir:
      $self->modified_parentdirs($path);
      
      $self->logmsg("SCRAM: $path: modified: updating cache\n");
      # Current subdirs:
      @items = $self->getdir($path);
      
      # Start checking from element number 2:
      for (my $i = 2; $i <= $#$cached; $i++)
	 {
	 if (! grep($cached->[$i] eq $_, @items))
	    {
	    # Add the removed path to a store for later access
	    # from the project cache. This info is needed to update
	    # the cached data:
	    $self->schedremoval($cached->[$i]);
	    # Remove all child data:
	    $self->clean_cache_recursive($cached->[$i]);
	    }
	 }      
      
      $self->{DIRCACHE}->{$path} = [ (stat(_))[2, 9], @items ];
      $required = 1;
      $self->cachestatus(1);
      }
   else
      {
      $self->logmsg("SCRAM: $path: valid: using cached directory list\n");
      (undef, undef, @items) = @{$self->{DIRCACHE}->{$path}};
      $required = 0;
      }
   
   # Process sub-directories
   foreach my $item (@items)
      {
      $self->checktree($item, $required, $dofiles);
      }
   }

sub clean_cache_recursive()
   {
   my $self=shift;
   my ($startdir) = @_;
   my $children = $self->{DIRCACHE}->{$startdir};
   
   for (my $i = 2; $i <= $#$children; $i++) 
      {
      # Remove all children:
      $self->schedremoval($children->[$i]);
      $self->clean_cache_recursive($children->[$i]); 
      }
   
   delete $self->{DIRCACHE}->{$startdir};
   return $self;
   }

sub dirtree()
   {
   my $self=shift;
   my ($dir,$dofiles) = @_;

   # Get the directory tree:
   $self->checktree($dir, 1, $dofiles);
   return $self;
   }

sub checkfiles()
   {
   my $self=shift;
   # Scan config dir for top-level data, then start from src:
   my @scandirs=($ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR}, $ENV{SCRAM_SOURCEDIR});
   my $dofiles=1;
   # Loop over all directories that need scanning (normally just src and config):
   foreach my $scand (@scandirs)
      {
      $self->logmsg("SCRAM: Scanning $scand [dofiles set to ".$dofiles."]\n");
      # Check the directory tree:
      $self->dirtree($scand, $dofiles);
      $dofiles=0;
      }
   
   # Mark everything in the cache old:
   map { $_->[0] = 0 } values %{$self->{BFCACHE}};
   map { $_->[0] = 0 } values %{$self->{CONFIGCACHE}};

   # Remember which directories have buildfiles in them:
   my %files = map { -f $_ ? ($_ => [ (stat(_))[9] ]) : () }
               map { "$_/BuildFile" }
	       keys %{$self->{DIRCACHE}};

   # Get list of files in config dir:
   my $configcache = {};
   my %configfiles = map { -f $_ && 
			      $_ =~ m|$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}.*?$|
			      ? ($_ => [ (stat(_))[9] ]) : () } keys %{$self->{DIRCACHE}};

   # Also add ToolCache.db to the cache: FIXME: should probably use aglob here so
   #                                     that all SCRAM_ARCHs are taken into account.
   $configfiles{$ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ToolCache.db"} =
      [ (stat($ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ToolCache.db"))[9] ];
   
   # Compare or add to config file cache. We need this to be separate so we can tell if a
   # file affecting our build has been changed:
   while (my ($path, $vals) = each %configfiles)
      {
      if ($self->{CONFIGCACHE}->{$path} && $self->{CONFIGCACHE}->{$path}[1] == $vals->[0])
	 {
	 $configcache->{$path} = $self->{CONFIGCACHE}->{$path};
	 delete $self->{CONFIGCACHE}->{$path};
	 }
      else
	 {
	 $self->{STATUSCONFIG}=1;
	 $self->logmsg("SCRAM: $path: changed\n");
	 $configcache->{$path} = [ 1, @$vals ];
	 delete $self->{CONFIGCACHE}->{$path};
	 }
      }
   
   # Compare with existing cache: remove from cache what no longer
   # exists, then check which build files are newer than the cache.
   my $newcache = {};

   while (my ($path, $vals) = each %files)
      {
      if ($self->{BFCACHE}->{$path} && $self->{BFCACHE}->{$path}[1] == $vals->[0])
	 {
	 $newcache->{$path} = $self->{BFCACHE}->{$path};
	 delete $self->{BFCACHE}->{$path};
	 }
      else
	 {
	 $self->{STATUSSRC}=1;
	 $self->logmsg("SCRAM: $path: changed\n");
	 $newcache->{$path} = [ 1, @$vals ];
	 delete $self->{BFCACHE}->{$path};
	 }
      }

   # If there were BuildFiles that were removed, force update of cache
   # and remove the BUILDFILEDATA entries:
   foreach my $path (keys %{$self->{BFCACHE}})
      {
      $self->logmsg("SCRAM: $path: removed. Build data will be removed from build cache.\n");
      $self->cachestatus(1);      
      # Store this so that later, we can tell the BuildDataStore to remove it:
      $self->schedremoval($path);
      }
   
   # Save the BuildFile cache:
   delete $self->{BFCACHE};
   $self->{BFCACHE} = $newcache;

   # Save the config cache:
   delete $self->{CONFIGCACHE};
   $self->{CONFIGCACHE} = $configcache;
   return $self;
   }

sub dircache()
   {
   my $self=shift;
   # Return the file cache:
   return $self->{DIRCACHE};
   }

sub added_dirs()
   {
   my $self=shift;
   my ($path) = @_;

   # If we have a path to add, add it.
   if ($path)
      {
      if (exists($self->{ADDEDDIRS}))
	 {
	 push(@{$self->{ADDEDDIRS}}, $path);
	 }
      else
	 {
	 $self->{ADDEDDIRS} = [ $path ];
	 }
      }
   else
      {
      # Otherwise, return the array of added dirs:
      my @addeddirs = @{$self->{ADDEDDIRS}};
      delete $self->{ADDEDDIRS};
      return \@addeddirs;
      }
   }

sub modified_parentdirs()
   {
   my $self=shift;
   my ($path) = @_;
   
   # If we have a path to add, add it.
   # Don't bother if it's the main source dir as we don't
   # want to rescan everything from src (that would be silly):
   if ($path && $path ne $ENV{SCRAM_SOURCEDIR})
      {
      if (exists($self->{MODPARENTDIRS}))
	 {
	 push(@{$self->{MODPARENTDIRS}}, $path);
	 }
      else
	 {
	 $self->{MODPARENTDIRS} = [ $path ];
	 }
      }
   else
      {
      # Otherwise, return the array of added dirs:
      my @moddeddirs = @{$self->{MODPARENTDIRS}};
      delete $self->{MODPARENTDIRS};
      return \@moddeddirs;
      }
   }

sub schedremoval()
   {
   my $self=shift;
   my ($d)=@_;

   if ($d)
      {
      if (exists($self->{REMOVEDATA}))
	 {
	 push(@{$self->{REMOVEDATA}},$d);
	 }
      else
	 {
	 $self->{REMOVEDATA} = [ $d ];
	 }
      }
   else
      {
      my $remove = [ @{$self->{REMOVEDATA}} ];
      $self->{REMOVEDATA} = [];
      return $remove;
      }
   }

sub filestatus()
   {
   my $self=shift;
   # Here we want to return a true or false value depending on whether
   # or not a buildfile was changed:
   return $self->{STATUSSRC};
   }

sub configstatus()
   {
   my $self=shift;
   # Here we want to return a true or false value depending on whether or not a file
   # in config dir was changed:
   return $self->{STATUSCONFIG};
   }

sub bf_for_scanning()
   {
   my $self=shift;
   my $MODIFIED = [];
   
   $self->{STATUSSRC} = 0;

   # Return a list of buildfiles to be reread. Note that we only do this
   # if the status was changed (i.e. don't have to read through the list of BFs to know
   # whether something changed as the flags STATUSSRC is set as the src tree is checked).
   # Also we check to see if STATUSCONFIG is true. If so all BuildFiles are marked to be read:
   if ($self->{STATUSCONFIG})
      {
      $self->{STATUSCONFIG} = 0;
      # Return all the buildfiles since they'll all to be read:
      return [ keys %{$self->{BFCACHE}} ];
      }
   else
      {
      # Only return the files that changed:
      map { ( $self->{BFCACHE}{$_}->[0] == 1 ) && push(@$MODIFIED, $_) } keys %{$self->{BFCACHE}};
      # Reset the flag:
      $self->{STATUSCONFIG} = 0;
      }
   return $MODIFIED;
   }

sub paths()
   {
   my $self=shift;
   my $paths = {};
   
   $self->{ALLDIRS} = [];
   
   # Pass over each dir, skipping those that are not wanted and
   # storing those that are relevant to an array:
   foreach my $path (keys %{$self->{DIRCACHE}})
      {
      if ( ! -d $path && $path != m|$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}.*?$|)
	 {	
	 $self->logmsg("SCRAM: $path no longer exists. Clearing from cache.\n");
	 $self->cachestatus(1);
	 delete $self->{DIRCACHE}->{$path};
	 }
      else
	 {
	 next if $path =~ m|/CVS$|;     # Ignore CVS directories.
	 next if $path =~ m|/\.admin$|; # Ignore .admin directories.
	 next if $path =~ m|\Q$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}\L|;
	 push(@{$self->{ALLDIRS}},$path);
	 }
      }
   
   # Return the array:
   return $self->{ALLDIRS};
   }

sub verbose()
   {
   my $self=shift;
   # Turn on verbose mode:
   @_ ? $self->{VERBOSE} = shift
      : $self->{VERBOSE}
   }

sub cachestatus()
   {
   my $self=shift;
   # Set/return the status of the cache:
   @_ ? $self->{STATUS} = shift
      : $self->{STATUS}
   }

sub logmsg()
   {
   my $self=shift;
   # Print a message to STDOUT if VERBOSE is true:
   print STDERR @_ if $self->verbose();
   }

sub name()
   {
   my $self=shift;
   # Set/return the name of the cache to use:
   @_ ? $self->{CACHENAME} = shift
      : $self->{CACHENAME}
   }

1;
