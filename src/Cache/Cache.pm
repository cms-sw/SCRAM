#____________________________________________________________________ 
# File: Cache.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
#         (with contribution from Lassi.Tuura@cern.ch)
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------

=head1 NAME

Cache::Cache - A generic directory cache object.

=head1 SYNOPSIS
   
      my $cacheobject=Cache::Cache->new();

=head1 DESCRIPTION

A package to provide caching of directory information. Directory timestamps
are tracked on further reading of an existing cache and lists of modified
directories and BuildFiles can be obtained.

=head1 METHODS

=over

=cut

package Cache::Cache;
require 5.004;

use Exporter;
use Utilities::AddDir;
@ISA=qw(Exporter);
#

=item   C<new()>

Create a new Cache::Cache object. The name of the cache is B<DirCache.db.gz> by default.

=cut

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
      CACHENAME => "DirCache.db.gz",     # Name of global file/dir cache;
      BFCACHE => {},                  # BuildFile cache;
      DIRCACHE => {},                 # Source code cache;
      EXTRASUFFIX => {},              # path with extra suffix;
      STATUS => 0,                    # Status of cache: 1 => something changed. If so, force save;
      VERBOSE => 0                    # Verbose mode (0/1);
      };

   bless $self,$class;
   return $self;
   }

=item   C<getdir($path)>

Return a list of directories starting from $path.

=cut

sub getdir()
   {
   my $self=shift;
   my $path=shift;
   my $ignore=shift || 'CVS|\\..*';
   my $match=shift || ".+";

   opendir (DIR, $path) || die "$path: cannot read: $!\n";
   # Skip .admin and CVS subdirectories too.
   # Also skip files that look like backup files or files being modified with emacs:
   my @items = map { "$path/$_" } grep ((-d "$path/$_") && ($_=~/^($match)$/) && ($_!~/^($ignore)$/),readdir(DIR));
   closedir (DIR);
   return @items;
   }

=item   C<prune($path)>

Recursively remove directories from the cache starting at $path.

=cut

sub prune()
   {
   my $self=shift;
   my $path = shift;
   my $skipparent = shift || 0;
   my $suffix = shift || "";
   $self->extra_suffix($path,$suffix) if ($suffix);
   if (!$skipparent)
      {
      my $parent = $path;
      $parent =~ s|(.*)/[^/]+$|$1|;
      if ($parent ne $path && exists $self->{DIRCACHE}{$parent})
         {
         my ($time, @subs) = @{$self->{DIRCACHE}{$parent}};
         $self->{DIRCACHE}{$parent} = [ $time, grep ($_ ne $path, @subs) ];
	 $self->{ADDEDDIR}{$parent}=1;
         $self->cachestatus(1);
         }
      }
   if (exists $self->{ADDEDDIR}{$path}){delete $self->{ADDEDDIR}{$path};}
   return if ! exists $self->{DIRCACHE}{$path};
   $self->cachestatus(1);
   foreach my $bf ("$ENV{SCRAM_BUILDFILE}.xml","$ENV{SCRAM_BUILDFILE}")
      {
      if (exists $self->{BFCACHE}{"${path}/${bf}"})
         {
	 if (!-f "${path}/${bf}") {$self->{REMOVEDBF}{"${path}/${bf}"}=1;}
	 delete $self->{BFCACHE}{"${path}/${bf}"};
	 if (exists $self->{ADDEDBF}{"${path}/${bf}"}){delete $self->{ADDEDBF}{"${path}/${bf}"};}
	 last;
         }
      }
   if (!-d $path) {$self->{REMOVEDDIR}{$path}=1;}
   my (undef, @subs) = @{$self->{DIRCACHE}{$path}};
   delete $self->{DIRCACHE}{$path};
   foreach my $sub (@subs)
      {
      $self->prune($sub,1);
      }
   }

=item   C<checktree($path, $required, $dofiles)>

A timestamp checking routine. Starting from $path, check all timestamps of
directories and their files. Skip all files unless $dofiles is 1. 

=cut

sub checktree()
   {
   my ($self, $path, $required) = @_;
   # Check if this path needs to be checked.  If it exists, has the same mode
   # and the same time stamp, it's up to date and doesn't need to be checked.
   # Otherwise if it is a directory whose time-stamp has changed, rescan it.
   # If the path has be removed, prune it from the cache.  Note that we skip 
   # non-directories unless $dofiles is set.  Considering only directories is
   # dramatically faster.

   # NB: We stat each path only once ever.  The special "_" file handle uses
   # the results from the last stat we've made.  See man perlfunc/stat.
   if (! stat($path))
      {
      die "$path: $!\n" if $required;
      $self->prune($path);
      return;
      }

   # If the entry in the cache is not the same mode or time, force an update.
   # Otherwise use the cache as the list of items we need to change.
   my $cached = $self->{DIRCACHE}{$path};   
   my @items = ();
   my $matchdir='[a-zA-Z0-9][a-zA-Z0-9-_]*';

   if (! -d _)
      {
      $self->prune($path);
      return;
      }
   elsif (! $cached)
      {
      # When a directory is added, this block is activated
      $self->{ADDEDDIR}{$path}=1;
      $self->{DIRCACHE}{$path} = [ (stat(_))[9], @items = $self->getdir($path,'',$matchdir) ];
      $required = 1;
      $self->cachestatus(1);
      }
   elsif ($cached->[0] != (stat(_))[9])
      {
      my $ntime = (stat(_))[9];
      # When a subdirectory is removed, this block is activated
      #
      # This is a parent directory. We store this as any
      # update can be taken recursively from this dir:
      #$self->modified_parentdirs($path);
      # Current subdirs:
      my %curdirs = map { $_ => 1 } $self->getdir($path,'',$matchdir);
      my %olddirs = ();
      for (my $i = 1; $i <= $#$cached; $i++)
	 {
	 my $d = $cached->[$i];
	 $olddirs{$d}=1;
	 if (!exists $curdirs{$d})
	    {
	    $self->prune($d,1);
	    }
	 }
      
      foreach my $d (keys %curdirs)
         {
	 if (!exists $olddirs{$d})
	    {
	    if ($self->extra_suffix($d))
	       {
	       delete $curdirs{$d};
	       }
	    }
	 }

      $self->{ADDEDDIR}{$path}=1;
      $self->cachestatus(1);
      @items = keys %curdirs;
      $required = 0;
      $self->{DIRCACHE}{$path} = [ $ntime, @items ];
      }
   else
      {
      (undef, @items) = @{$self->{DIRCACHE}{$path}};
      $required = 0;
      }
   if (($self->{cachereset}) && (!exists $self->{ADDEDDIR}{$path}))
      {
      $self->{ADDEDDIR}{$path}=1;
      $self->cachestatus(1);
      }
   
   my $bfcachedir=$ENV{LOCALTOP}."/".$ENV{SCRAM_TMP}."/".$ENV{SCRAM_ARCH}."/cache/bf/${path}";
   my $cbf="${bfcachedir}/$ENV{SCRAM_BUILDFILE}";
   my $bftime=0;
   my $bf="${path}/$ENV{SCRAM_BUILDFILE}";
   foreach my $ext (".xml","")
      {
      my $bfn="$bf$ext";
      if (! stat ($bfn))
         {
         if (exists $self->{BFCACHE}{$bfn})
	    {
            $self->{REMOVEDBF}{$bfn}=1;
	    delete $self->{BFCACHE}{$bfn};
            Utilities::AddDir::adddir($bfcachedir);
            open(BF,">${cbf}");close(BF);
	    $self->cachestatus(1);
	    }
         }
      else
         {
         $bftime = (stat(_))[9];
         if ((! exists $self->{BFCACHE}{$bfn}) ||
             ($bftime != $self->{BFCACHE}{$bfn}))
            {
	    if ((!-f "${cbf}") || (exists $self->{BFCACHE}{$bfn}))
	       {
               Utilities::AddDir::adddir($bfcachedir);
               open(BF,">${cbf}");close(BF);
               }
	    $self->{ADDEDBF}{$bfn}=1;
	    delete $self->{BFCACHE}{$bf};
            $self->{BFCACHE}{$bfn}=$bftime;
	    if ($ext eq ""){$self->{nonxml}+=1;}
            $self->cachestatus(1);
            }
         elsif($self->{cachereset})
            {
	    $self->{ADDEDBF}{$bfn}=1;
	    if ($ext eq ""){$self->{nonxml}+=1;}
	    if (!-f "${cbf}")
	       {
	       Utilities::AddDir::adddir($bfcachedir);
	       open(BF,">${cbf}");close(BF);
	       }
	    $self->cachestatus(1);
	    }
         last;
	 }
      }
   if (exists $self->{ExtraDirCache})
      {
      eval {$self->{ExtraDirCache}->DirCache($self,$path);};
      }
   # Process sub-directories
   foreach my $item (@items)
      {
      $self->checktree($item, $required);
      }
   }

=item   C<clean_cache_recursive($startdir)>

Recursive remove cached data for directories under $startdir.

=cut

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

=item   C<dirtree($dir,$dofiles)>

Starting from $dir, scan the directory tree. Ignore files unless $dofiles is set. This
function just calls checktree().

=cut

sub dirtree()
   {
   my $self=shift;
   my ($dir) = @_;

   # Get the directory tree:
   $self->checktree($dir, 1);
   return $self;
   }

=item   C<checkfiles()>

Function to actually run the timestamp checks. This is only run from
SCRAM::CMD::build().

=cut

sub checkfiles()
   {
   my $self=shift;
   $self->{cachereset}=shift || 0;
   # Scan config dir for top-level data, then start from src:
   my @scandirs=($ENV{SCRAM_CONFIGDIR}, $ENV{SCRAM_SOURCEDIR});
   # Loop over all directories that need scanning (normally just src and config):
   $self->{nonxml}=0;
   eval ("use SCRAM::Plugins::DirCache;");
   if(!$@) {$self->{ExtraDirCache} = SCRAM::Plugins::DirCache->new();}
   foreach my $scand (@scandirs)
      {
      $self->logmsg("SCRAM: Scanning $scand [dofiles set to ".$dofiles."]\n");
      # Check the directory tree:
      $self->dirtree($scand);
      }
   if ($self->cachestatus())
      {
      foreach my $bf ("$ENV{SCRAM_BUILDFILE}.xml","$ENV{SCRAM_BUILDFILE}")
         {
         if (exists $self->{BFCACHE}{"$ENV{SCRAM_CONFIGDIR}/${bf}"})
            {
	    $self->{ADDEDBF}{"$ENV{SCRAM_CONFIGDIR}/${bf}"}=1;
	    last;
	    }
	 }
      }
   delete $self->{ExtraDirCache};
   if ($self->{nonxml} > 0)
      {
      #print STDERR "**** WARNING: ",$self->{nonxml}," non-xml based $ENV{SCRAM_BUILDFILE} were read.\n";
      }
   return $self;
   }

=item   C<dircache()>

Return a reference to the directory cache hash.

=cut

sub dircache()
   {
   my $self=shift;
   # Return the file cache:
   return $self->{DIRCACHE};
   }

=item   C<added_dirs($path)>

Add $path to the list of directories added since last scan, or return
the list of added directories if no argument given.

=cut

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

=item   C<modified_parentdirs($path)>

Add a directory $path to the list of parent directories (directories
having subdirectories), or return a reference to the list.
Storing this parent allows any update to be taken recursively from this 
location.
   
=cut

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

=item   C<schedremoval($d)>

Add directory $d to list of directories that should be removed
recursively from the cache.
If no arguments given, return a reference to a list of
directories to be removed.
   
=cut

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

=item   C<filestatus()>

Return a true or false value depending on whether
a BuildFile was changed or not.

=cut

sub filestatus()
   {
   my $self=shift;
   # Here we want to return a true or false value depending on whether
   # or not a buildfile was changed:
   return $self->{STATUSSRC};
   }

=item   C<configstatus()>

Return a true or false value depending on whether
a file in the config directory was changed or not.

=cut

sub configstatus()
   {
   my $self=shift;
   # Here we want to return a true or false value depending on whether or not a file
   # in config dir was changed:
   return $self->{STATUSCONFIG};
   }

=item   C<bf_for_scanning()>

Return a list of BuildFiles to re-read. Note that this is only done
if the status was changed (i.e. not necessary to read through the list
of BuildFiles to know whether something changed as the flag B<STATUSSRC>
is set as the source tree is checked).
If B<STATUSCONFIG> is true, all BuildFiles are marked to be read. 

=cut

sub bf_for_scanning()
   {
   my $self=shift;
   my $MODIFIED = [];
   map { push(@$MODIFIED, $_) } @{$self->{ADDEDBF}};
   return $MODIFIED;
   }

=item   C<paths()>

Return a reference to an array of directories for the current source tree.

=cut

sub paths()
   {
   my $self=shift;
   my $paths = {};
   
   my $ALLDIRS = [];
   map { push(@$ALLDIRS, $_) } keys %{$self->{DIRCACHE}};
   return $ALLDIRS;
   }

=item   C<verbose()>

Turn verbosity for the cache on or off.

=cut

sub verbose()
   {
   my $self=shift;
   # Turn on verbose mode:
   @_ ? $self->{VERBOSE} = shift
      : $self->{VERBOSE}
   }

=item   C<cachestatus()>

Set or return the cache status to indicate whether or not a file
timestamp has changed since the last pass.

=cut

sub cachestatus()
   {
   my $self=shift;
   # Set/return the status of the cache:
   @_ ? $self->{STATUS} = shift
      : $self->{STATUS}
   }

=item   C<logmsg(@message)>

Print a message to B<STDERR>. This is only used in
checktree(), checkfiles() and paths().

=cut

sub logmsg()
   {
   my $self=shift;
   # Print a message to STDOUT if VERBOSE is true:
   print STDERR @_ if $self->verbose();
   }

=item   C<name()>

Set or return the name of the cache. Normally set
to B<DirCache.db.gz> (and not architecture dependent).

=cut

sub name()
   {
   my $self=shift;
   # Set/return the name of the cache to use:
   @_ ? $self->{CACHENAME} = shift
      : $self->{CACHENAME}
   }

sub get_data()
   {
     my $self=shift;
     my $type=shift;
     @_ ? $self->{$type} = shift
        : $self->{$type};
   }

sub extra_suffix()
   {
     my $self=shift;
     my $path=shift;
     @_ ? $self->{EXTRASUFFIX}{$path}=shift
        : exists $self->{EXTRASUFFIX}{$path};
   }
   
sub get_nonxml()
   {
   my $self=shift;
   return $self->{nonxml};
   }

1;

=back

=head1 AUTHOR

Shaun Ashby (with contribution from Lassi Tuura)

=head1 MAINTAINER

Shaun Ashby
   
=cut

