package AddDir;
require 5.001;
require Exporter;
use Cwd;
@ISA	= qw(Exporter);
@EXPORT = qw(adddir copydir);


sub adddir {
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

sub copydir
   {
   my $src=shift;
   my $dest=shift;
   
   use DirHandle;
   use File::Copy;
   
   # print "Copying $src to $dest\n";
   adddir($dest);
   my $dh=DirHandle->new($src);
   
   if (defined $dh)
      {
      my @allfiles=$dh->read();
   
      my $file;
      foreach $file ( @allfiles )
	 {
	 next if $file=~/^\.\.?/;
	 if ( -d $src."/".$file )
	    {
	    copydir($src."/".$file,$dest."/".$file);
	    }
	 else
	    {
	    copy($src."/".$file,$dest."/".$file);
	    }
	 }
      undef $dh;
      }
   else
      {
      die "Attempt to open a non-existent directory ($src). Exitting\n";
      }
   }
