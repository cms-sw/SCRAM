=head1 NAME

Utilities::AddDir - Utility functions for creating or copying directories.

=head1 SYNOPSIS

	&Utilities::AddDir::adddir($dir);
	&Utilities::AddDir::copydir($src,$dest);
	&Utilities::AddDir::copydirwithskip($src,$dest,@files_to_skip);

=head1 METHODS

=over

=cut

package Utilities::AddDir;
require 5.001;
require Exporter;
use Cwd;
@ISA	= qw(Exporter);
@EXPORT = qw(adddir copydir copydirwithskip copydirexp getfileslist fixpath);

=item   C<adddir($dir)>

Create a new directory.

=cut


sub fixpath {
  my $dir=shift;
  my @parts=();
  my $p="/";
  if($dir!~/^\//){$p="";}
  foreach my $part (split /\//, $dir)
  {
    if($part eq ".."){pop @parts;}
    elsif(($part ne "") && ($part ne ".")){push @parts, $part;}
  }
  return "$p".join("/",@parts);
}

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
   mkdir ( $dirname , 0755) ||
                die "cannot make directory ".$dirname." $!\n";
   print $i." ".$dirname."\n" if $debug;
  }
 chdir $dirname;
 }
 chdir $startdir;
}


=item   C<copydir($src, $dest)>

Copy a directory $src and contents to $dest.

=cut

sub copydir
   {
   my $src=shift;
   my $dest=shift;
   
   use DirHandle;
   use File::Copy;
   
   adddir($dest);
   my $dh=DirHandle->new($src);
   
   if (defined $dh)
      {
      my @allfiles=$dh->read();
   
      my $file;
      foreach $file ( @allfiles )
	 {
	 next if $file=~/^\.\.?$/;
	 if ( -d $src."/".$file )
	    {
	    copydir($src."/".$file,$dest."/".$file);
	    }
	 else
	    {
	    copy($src."/".$file,$dest."/".$file);
	    if ( -x $src."/".$file || -X $src."/".$file ) {chmod(0755,$dest."/".$file);}
	    }
	 }
      undef $dh;
      }
   else
      {
      die "Attempt to open a non-existent directory ($src). Exiting\n";
      }
   }

=item   C<copydirwithskip($src, $dest, @files_to_skip)>

Recursively copy a directory $src to $dest. All files
in @files_to_skip will be skipped.

=cut

sub copydirwithskip
   {
   my $src=shift;
   my $dest=shift;
   my $filetoskip=shift || [];
   
   use DirHandle;
   use File::Copy;
   
   adddir($dest);
   
   my $dh=DirHandle->new($src);
   
   if (defined $dh)
      {
      my @allfiles=$dh->read();
   
      my $file;
      foreach $file ( @allfiles )
	 {
	 next if $file=~/^\.\.?$/;
	 # Skip backup files and x~ files:
	 next if $file =~ /.*\.bak$/;
	 next if $file =~ /.*~$/;

	 my $skip=0;
	 foreach my $fskip (@$filetoskip)
	    {
            my $fullfile = "${src}/${file}";
	    if ($fullfile eq $fskip)
	       {
	       $skip = 1;
	       last;
	       }
	    }
	 if ($skip)
	    {
	    next;
	    }
	 
	 if ( -d $src."/".$file )
	    {
	    copydirwithskip($src."/".$file,$dest."/".$file,$filetoskip);
	    }
	 else
	    {
	    copy($src."/".$file,$dest."/".$file);
	    if ( -x $src."/".$file || -X $src."/".$file ) {chmod(0755,$dest."/".$file);}
	    }
	 }
      undef $dh;
      }
   else
      {
      die "Attempt to open a non-existent directory ($src). Exiting\n";
      }
   }
   
sub copydirexp
   {
   my $src=shift;
   my $dest=shift;
   my $exp=shift || ".+";
   my $op=shift || 0;
   
   if ($exp=~/^!(.+)/){$exp=$1; $op=1;}

   use DirHandle;
   use File::Copy;
   adddir($dest);
   my $dh=DirHandle->new($src);
   
   if (defined $dh)
      {
      my @allfiles=$dh->read();
   
      my $file;
      foreach $file ( @allfiles )
	 {
	 next if $file=~/^\.\.?$/;
	 if ( -d $src."/".$file )
	    {
	    copydirexp($src."/".$file,$dest."/".$file,$exp,$op);
	    }
	 else
	    {
	    my $skip=1;
	    if ($file=~/$exp/)
	       {
	       if ($op == 0){$skip=0;}
	       }
	    elsif ($op == 1){$skip=0;}
	    if (!$skip)
	       {
	       copy($src."/".$file,$dest."/".$file);
	       if ( -x $src."/".$file || -X $src."/".$file ) {chmod(0755,$dest."/".$file);}
	       }
	    }
	 }
      undef $dh;
      }
   else
      {
      die "Attempt to open a non-existent directory ($src). Exiting\n";
      }
   }

sub getfileslist ()
   {
   my $dir=shift;
   my $data=shift || [];
   my $base=shift || $dir;
   my $ref;
   opendir($ref,$dir) || die "ERROR: Can not open directory for reading: $dir";
   foreach my $f (readdir($ref))
      {
      next if $f=~/^\.\.?/;
      $f = "${dir}/${f}";
      if (-d $f){&getfileslist($f,$data,$base);}
      else
         {
	 $f=~s/^$base\///;
         push @$data,$f;
         }
      }
   closedir($ref);
   return $data;
   }
   
1;

__END__

=back

=head1 AUTHOR

Originally written by Christopher Williams.

=head1 MAINTAINER

Shaun ASHBY 

=cut

