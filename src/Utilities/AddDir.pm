#!/usr/local/bin/perl5
#

package AddDir;
require Exporter;
use Cwd;
@ISA	= qw(Exporter);
@EXPORT = qw(adddir);

sub adddir ($directory) {
 my $indir=shift;
 my $startdir=cwd;
 my @dir=split /\//,  $indir;

 if ( $indir=~/^\// ) {
   chdir "/";
   shift @dir;
 }
 umask 02;
 foreach $dirname ( @dir ) {
  next if ( $dirname eq "" );
  if ( ! -e $dirname ) {
   mkdir ( $dirname , 0775) ||
                die "cannot make directory ".$dirname." $!\n";
   print $i." ".$dirname."\n" if $debug;
  }
 chdir $dirname;
 }
 chdir $startdir;
}
