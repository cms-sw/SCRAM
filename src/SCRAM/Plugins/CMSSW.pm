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
  my $prod=";prodarch=";
  if ($default){$prod=";prodarch=1;";}
  if (!exists $self->{getcmd})
  {
    my $cmd='wget  --no-check-certificate -nv -o /dev/null -O- ';
    my $out=`which wget 2>&1`;
    if ($? != 0){$cmd='curl -L -k --stderr /dev/null ';}
    $self->{getcmd}=$cmd." 'https://cmssdt.cern.ch/SDT/releases.map'";
  }
  my @archs=();
  my $xarch=undef;
  foreach my $l (`$self->{getcmd} 2>&1 | grep ';label=$version;\\|;state=IB;' | grep '$prod'`)
  {
    chomp $l;
    if ($l=~/architecture=([^;]+);/)
    {
      my $arch=$1;
      if ($l=~/;state=IB;/)
      {
        if (defined $xarch){next;}
	if ($l=~/;label=([^;]+);/)
        {
          $l=qr/^$1/;
          if ($version=~$l){$xarch=$arch;}
        }
      }
      else{push @archs,$arch;}
    }
  }
  if ((scalar(@archs)==0) && (defined $xarch)){push @archs,$xarch;}
  return @archs;
}

1;
