package SCRAM::Plugins::CMSSW;
require 5.004;
use strict;

sub new()
{
   my $class=shift;
   my $self={};
   bless $self, $class;
   return $self;
}

sub releaseArchs()
{
  my ($self,$version,$default)=@_;
  if($default){$default='default=1&';}
  $self->_getTcData("py_getReleaseArchitectures?${default}release=$version");
}

sub _getTcData()
{
  my ($self,$url)=@_;
  $url=~s/^\/+//;
  if (!exists $self->{getcmd})
  {
    my $cmd='wget  --no-check-certificate -nv -o /dev/null -O- ';
    my $out=`which wget 2>&1`;
    if ($? != 0){$cmd='curl -L -k --stderr /dev/null ';}
    $self->{getcmd}=$cmd;
    $self->{baseurl}="https://cmstags.cern.ch/tc";
  }
  my @archs=();
  my $cmd=$self->{getcmd}." '".$self->{baseurl}."/$url'";
  foreach my $l (`$cmd`)
  {
    chomp $l;
    $l=~s/[\[\]"']//go;
    foreach my $v (split (",",$l))
    {
      $v=~s/\s//g;
      if ($v=~/^(true|false)$/io){next;}
      push @archs,$v;
    }
  }
  return @archs;
}

1;
