package SCRAM::Plugins::ProjectChkSum;
@EXPORT = qw(chksum);

sub chksum()
{
  my $dir=shift;
  use Digest::MD5;
  my $md5 = Digest::MD5->new();
  my $sum = &_chksum($dir,$md5,'^(BuildFile\.xml|SCRAM_ExtraBuildRule\.pm|scram_version|Self\.xml|SCRAM)$');
  foreach my $s (@$sum)
  {$md5->add($s);}
  return $md5->hexdigest();
}

sub _chksum()
{
  my $dir=shift;
  my $md5=shift;
  my $filter=shift;
  my $nfilter=shift;
  my $data=shift || [];
  if (!defined $filter){$filter='.+';}
  if (!defined $nfilter){$nfilter='^(toolbox|boot\.xml|bootsrc\.xml)$';}
  my $dref;
  if (opendir($dref,$dir))
  {
    my @fs=sort readdir($dref);
    closedir($dref);
    foreach my $f (@fs)
    {
      if ($f=~/^(\..*|CVS)$/){next;}
      if ($nfilter && $f=~/$nfilter/){next;}
      if ($f=~/$filter/)
      {
        $f="${dir}/${f}";
        if (-d $f){&_chksum($f,$md5,".+","",$data);}
        elsif (-f $f)
	{
	  my $ref;
	  if (open($ref,$f))
	  {
	    $md5->addfile($ref);
	    push @$data,$md5->hexdigest();
	    close($ref);
	  }
	  else{die "ERROR: Can not open file for reading: $f";}
	}
      }
    }
  }
  else{die "ERROR: Can not open directory for reading: $dir";}
  return $data;
}

1;
