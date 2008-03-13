package Cache::CacheUtilities;
require 5.004;
use Storable qw(nfreeze thaw retrieve nstore);
BEGIN {
  eval "use Compress::Zlib qw(gzopen);";
}

sub read()
   {
   my $file = shift;
   my $cache=undef;
   my $gz = gzopen($file, "rb");
   if ($gz)
      {
      my $buf;my $data;
      while ($gz->gzread($buf,1024*1024) > 0){$data.=$buf;}
      $gz->gzclose();
      $cache=eval {thaw($data);};
      if ($EVAL_ERROR){die "Cache loading error: ",$EVAL_ERROR,"\n";}
      }
   else{die "Can not open file for reading: $file";}
   return $cache;
   }
   
sub write()
   {
   my ($cache,$file) = @_;
   use File::Copy;
   if (-r $file){move($file,"${file}.bak");}
   my $ok=1;
   my $gz = gzopen($file, "wb");
   if ($gz)
      {
      eval {$gz->gzwrite(nfreeze($cache));};
      if ($EVAL_ERROR){$ok=0;}
      $gz->gzclose();
      }
   else{$ok=0;}
   if ($ok)
      {
      unlink ("${file}.bak");
      my $mode=0644;
      chmod $mode,$file;
      }
   else
      {
      if (-r "${file}.bak"){move("${file}.bak",$file);}
      die "ERROR: Writing Cache file: $file";
      }
   return;
   }

1;
