#____________________________________________________________________ 
# File: CacheUtilities.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-10-30 11:51:58+0100
# Revision: $Id: CacheUtilities.pm,v 1.2 2004/12/10 13:41:39 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package Cache::CacheUtilities;
require 5.004;

use IO::File;
use English;
use Exporter;

@ISA=qw(Exporter);

#
# Common functions for interacting with caches:
#

sub read()
   {
   my ($cachefilename) = @_;
   my $cachefh = IO::File->new($cachefilename, O_RDONLY)
      || die "Unable to read cached data file $cachefilename: ",$ERRNO,"\n";
   my @cacheitems = <$cachefh>;
   close $cachefh;

   # Copy the new cache object to self and return:
   $cache = eval "@cacheitems";
   die "Cache load error: ",$EVAL_ERROR,"\n", if ($EVAL_ERROR);
   return $cache;
   }

sub write()
   {
   my ($cacheobject,$cachefilename) = @_;

   use Data::Dumper;
   use File::Copy;

   print "[ CacheUtilities::write() ] Writing cache ",$cachefilename,"\n";   
   
   # Rename the cache file to make a backup copy:
   move($cachefilename,$cachefilename.".bak") if ( -r $cachefilename);   
   # Dump the cache to file:
   my $cachefh = IO::File->new($cachefilename, O_WRONLY|O_CREAT)
      or die "Couldn't write to $cachefilename: ",$ERRNO,"\n";

   # Name that should replace "VAR1" in the dumped
   # representation of the cache object:
   $Data::Dumper::Varname='cache';
   $Data::Dumper::Purity = 1;
   print $cachefh Dumper($cacheobject);
   close $cachefh;

   # Change the permissions to -rw-r--r--:
   my $filemode = 0644;
   chmod $filemode, $cachefilename;

   return;
   }

1;
