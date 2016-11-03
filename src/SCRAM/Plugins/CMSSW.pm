package SCRAM::Plugins::CMSSW;
require 5.004;
use strict;

sub new()
{
   my $class=shift;
   my $self={};
   bless $self, $class;
   if (! $main::interactive)
   {
     print STDERR "WARNING: In non-interactive mode release checks e.g. deprecated releases, production architectures are disabled.\n";
     $self->{data}=[];
   }
   return $self;
}

sub releaseArchs()
{
  my ($self,$version,$default,$reldir)=@_;
  my $prod=";prodarch=";
  if ($default){$prod=";prodarch=1;";}
  my $data = $self->getData($version,$reldir);
  my @archs=();
  my $xarch=undef;
  foreach my $l (@$data)
  {
    if ($l!~/$prod/){next;}
    if ($l!~/architecture=([^;]+);/o){next;}
    my $arch=$1;
    if ($l=~/;state=IB;/o)
    {
      if (defined $xarch){next;}
      if ($l=~/;label=([^;]+);/o)
      {
        $l=qr/^$1/;
        if ($version=~$l){$xarch=$arch;}
      }
    }
    else{push @archs,$arch;}
  }
  if ((scalar(@archs)==0) && (defined $xarch)){push @archs,$xarch;}
  return @archs;
}

sub getData()
{
  my ($self,$version,$reldir)=@_;
  if (!exists $self->{data})
  {
    $self->{data}=[];
    if (lc($main::SITE->get("release-checks"))=~/^(1|yes|y)$/)
    {
      my $url="https://cmssdt.cern.ch/SDT/releases.map?release=${version}&architecture=".$ENV{SCRAM_ARCH}."&scram=".$ENV{SCRAM_VERSION}."&releasetop=${reldir}";
      my $cmd='wget  --no-check-certificate -nv -o /dev/null -O- ';
      my $out=`which wget 2>&1`;
      if ($? != 0){$cmd='curl -L -k --stderr /dev/null ';}
      $cmd=$cmd." '${url}'";
      my $maxwait=$main::SITE->get("release-checks-timeout");
      my $wtime=3;
      local $SIG{ALRM} = 
        sub {
	  if ($wtime>0)
	  {
	    print STDERR "Waiting for release information to be obtained via $url (timeout in ${wtime}s)\n";
	    alarm $wtime;
	    $wtime=0;
	  }
	  else{die "alarm\n";}
        };
      eval 
      {
        alarm $wtime;
        $wtime=$maxwait-$wtime;
        foreach my $l (`$cmd 2>&1 | grep ';label=$version;\\|;state=IB;'`){chomp $l; push @{$self->{data}},$l;}
        alarm 0;
      };
      if ($@ && ($@ eq "alarm\n")) {print STDERR "WARNING: Reading release information from ${url} is timed out, ignoring any release checks.\n";}
    }
  }
  return $self->{data};
}

sub getDeprecatedDate ()
{
  my ($self,$version,$arch,$reldir)=@_;
  my $data = $self->getData($version, $reldir);
  foreach my $l (@$data)
  {
    if (($l!~/;label=$version;/) || ($l!~/architecture=$arch;/)){next;}
    if ($l=~/;state=Deprecated;/o){return 0;}
    if ($l=~/;deprecate_date=(\d{8});/o){return $1;}
  }
  return -1;
}

1;
