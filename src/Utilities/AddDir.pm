package Utilities::AddDir;
require 5.001;
require Exporter;

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
 use Cwd;
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

sub copydir
   {
   my $src=shift;
   my $dest=shift;
   system("cp -Rpf $src $dest");
   }

sub copyfile
   {
   my $src=shift;
   my $dest=shift;
   system("cp -pf $src $dest");
   }

sub getfileslist ()
   {
   my $dir=shift;
   my $data=shift || [];
   my $base=shift || $dir;
   my $breq=quotemeta($base);
   my $ref;
   opendir($ref,$dir) || die "ERROR: Can not open directory for reading: $dir";
   foreach my $f (readdir($ref))
      {
      next if $f=~/^\.\.?/;
      $f = "${dir}/${f}";
      if (-d $f){&getfileslist($f,$data,$base);}
      else
         {
	 $f=~s/^$breq\///;
         push @$data,$f;
         }
      }
   closedir($ref);
   return $data;
   }
   
1;
