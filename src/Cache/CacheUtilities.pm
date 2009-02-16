package Cache::CacheUtilities;
require 5.004;
use Data::Dumper;
BEGIN {
  eval "use Compress::Zlib qw(gzopen);";
  if ($@){$Cache::CacheUtilities::zipUntility="GZip";}
  else{$Cache::CacheUtilities::zipUntility="CompressZLib";}
  $Data::Dumper::Varname='cache';
}

sub read()
   {
   my ($file) = @_;
   my $data=();
   my $func="read${zipUntility}";
   &$func($file,\$data);
   my $cache = eval "$data";
   die "Cache $file load error: ",$@,"\n", if ($@);
   return $cache;
   }

sub write()
   {
   my ($cache,$file)=@_;
   use File::Copy;
   if (-r $file){move($file,"${file}.bak");}
   my $ok=1; my $err="";
   my $fcache=();
   eval {$fcache=Dumper($cache);};
   if ($@){$err=$@;$ok=0;}
   else
   {
      my $func="write${zipUntility}";
      $ok = &$func($fcache,$file);
   }
   if ($ok)
      {
      unlink ("${file}.bak");
      my $mode=0644;
      chmod $mode,$file;
      }
   else
      {
      if (-r "${file}.bak"){move("${file}.bak",$file);}
      die "ERROR: Writing Cache file $file: $err\n";
      }
   return;
   }
   
###### Using gzip in case    Compress::Zlib failed #################
sub readGZip()
{
   my $file = shift;
   my $data = shift;
   my $gz;
   if (open($gz,"gzip -cd $file |"))
      {
      binmode $gz;
      my $buf;
      while (read($gz,$buf,1024*1024) > 0){${$data}.=$buf;}
      close($gz);
      }
   else{die "Can not open file for reading using \"gzip\": $file\n";}
   return;
}

sub writeGZip()
{
   my ($cache,$file) = @_;
   my $gz;
   if (open($gz,"| gzip >$file"))
      {
      binmode $gz;
      print $gz $cache;
      close($gz);
      }
   else{die "Can not open file for reading using \"gzip\": $file\n";}
   return 1;
}

###### Using Compress::Zlib #################
sub readCompressZLib()
   {
   my $file = shift;
   my $data = shift;
   if (my $gz = gzopen($file, "rb"))
      {
      my $buf;
      while ($gz->gzread($buf,1024*1024) > 0){${$data}.=$buf;}
      $gz->gzclose();
      }
   else{die "Can not open file \"$file\" for reading: $!\n";}
   return;
   }
   
sub writeCompressZLib()
   {
   my ($cache,$file) = @_;
   my $gz = gzopen($file, "wb");
   if ($gz)
      {
      $gz->gzwrite($cache);
      $gz->gzclose();
      return 1;
      }
   return 0;
   }

1;
