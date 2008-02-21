#____________________________________________________________________ 
# File: CacheUtilities.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-30 11:51:58+0100
# Revision: $Id: CacheUtilities.pm,v 1.9 2007/12/14 09:03:53 muzaffar Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------

=head1 NAME

Cache::CacheUtilities - Utilities for reading and writing of cache files.

=head1 SYNOPSIS

Reading:

         print "Reading cached data","\n",if ($ENV{SCRAM_DEBUG});
	 $cacheobject=&Cache::CacheUtilities::read($cachename);

Writing:
   
	 &Cache::CacheUtilities::write($cacheobject,$cachename);

=head1 DESCRIPTION

Functions for reading and writing of cache files. This uses Storable::store() to
write out Perl data structures to files. For reading, the complete data structure
is read from the cache file using Storable::retrieve() which returns a variable
containing the original object.

=head1 METHODS

=over

=cut

package Cache::CacheUtilities;
require 5.004;

use IO::File;
use English;
use Exporter;

use Storable;

@ISA=qw(Exporter);

#
# Common functions for interacting with caches:
#

=item   C<read($cachefilename)>

Read the cache file $cachefilename and return a Perl object.

=cut

sub read()
   {
   my ($cachefilename) = @_;
   # Retrieve the cached object from the file:
   $cache = eval "retrieve(\"$cachefilename\")";
   die "Cache load error: ",$EVAL_ERROR,"\n", if ($EVAL_ERROR);
   return $cache;
   }

=item   C<write($cacheobject,$cachefilename)>

Dump the Perl object $cacheobject to a file $cachefilename.

=cut

sub write()
   {
   my ($cacheobject,$cachefilename) = @_;
   use File::Copy;
   print "[ CacheUtilities::write() ] Writing cache ",$cachefilename,"\n", if ($ENV{SCRAM_DEBUG});
   # Move the cache file to make a backup:
   move($cachefilename,$cachefilename.".bak") if ( -r $cachefilename);   
   # Use the store method of the Storable package to write out the object to a file:
   eval {
       nstore($cacheobject,$cachefilename);
   };
   
   die "Cache write error: ",$EVAL_ERROR,"\n", if ($EVAL_ERROR);
   
   # Change the permissions to -rw-r--r--:
   my $filemode = 0644;
   chmod $filemode, $cachefilename;

   return;
   }

1;


=back

=head1 AUTHOR/MAINTAINER

Shaun Ashby

=cut
