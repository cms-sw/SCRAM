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
  my @archs=();
  my $prod=";prodarch=";
  if ($default){$prod=";prodarch=1;";}
  if (!exists $self->{getcmd})
  {
    my $cmd='wget  --no-check-certificate -nv -o /dev/null -O- ';
    my $out=`which wget 2>&1`;
    if ($? != 0){$cmd='curl -L -k --stderr /dev/null ';}
    $self->{getcmd}=$cmd;
  }
  my $cmd=$self->{getcmd}." 'https://cmssdt.cern.ch/SDT/releases.map'";
  foreach my $l (`$cmd 2>&1 | grep ';label=$version;' | grep '$prod'`)
  {
    chomp $l;
    if ($l=~/architecture=([^;]+);/){push @archs,$1;}
  }
  return @archs;
}

1;
