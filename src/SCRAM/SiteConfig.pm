package SCRAM::SiteConfig;
require 5.004;
@ISA=qw(Utilities::Verbose);

sub new()
{
  my $class=shift;
  my $self={};
  bless $self, $class;
  $self->{siteconf}='etc/scramrc/site.cfg';
  $self->{site}{'release-checks'}{value}=1;
  $self->{site}{'release-checks'}{valid_values}='0|1|yes|no';
  $self->{site}{'release-checks'}{help}="Enable/disable release checks e.g. production architectures, deprecated releases. This avoids accessing releases information from internet.";
  $self->{site}{'release-checks-timeout'}{value}=10;
  $self->{site}{'release-checks-timeout'}{valid_values}='[3-9]|[1-9][0-9]+';
  $self->{site}{'release-checks-timeout'}{help}="Time in seconds after which a request to get release information should be timed out (min. value 3s).";
  $self->readSiteConfig();
  return $self;
}

sub readSiteConfig()
{
  my ($self)=@_;
  my $conf=$ENV{SCRAM_LOOKUPDB}."/".$self->{siteconf};
  my $ref;
  if((-f $conf) && (open($ref,$conf)))
  {
    while(my $line=<$ref>)
    {
      chomp $line;
      if ($line=~/^\s*([^=\s]+)\s*=\s*([^\s]+)\s*$/o){$self->{site}{$1}{value}=$2;}
    }
    close($ref);
  }
}

sub dump()
{
  my ($self,$key)=@_;
  my @dump=();
  if (($key ne "") && (exists $self->{site}{$key}) && (exists $self->{site}{$key}{valid_values})){push @dump,$key;}
  else
  {
    @dump=sort keys %{$self->{site}};
    print "Following SCRAM site configuration parameters are available:\n";
  }
  foreach my $k (@dump)
  {
    if (exists $self->{site}{$k}{valid_values})
    {
      print "  Name        : $k\n";
      print "  Value       : ",$self->{site}{$k}{value},"\n";
      print "  Valid values: ",$self->{site}{$k}{valid_values},"\n";
      print "  Purpose     : ",$self->{site}{$k}{help},"\n\n";
    }
  }
  return 0;
}

sub get()
{
  my ($self,$key)=@_;
  if ((!exists $self->{site}{$key}) || (!exists $self->{site}{$key}{valid_values}))
  {
    print STDERR "ERROR: Unknown site configuration parameter '$key'. Known parameters are\n";
    foreach my $k (keys %{$self->{site}})
    {
      if (exists $self->{site}{$k}{valid_values}){print STDERR "  * $k\n";}
    }
    return undef;
  }
  return $self->{site}{$key}{value};
}

sub set()
{
  my ($self,$key,$value)=@_;
  my $v=$self->get($key);
  if (!defined $v){return 1;}
  my $vv=$self->{site}{$key}{valid_values};
  if ($value!~/^$vv$/i)
  {
    print STDERR "ERROR: Invalid value '$value' provided. Valid value for $key should match '$vv'.\n";
    return 1;
  }
  print "$key=$value\n";
  if ($v eq $value){return 0;}
  $self->{site}{$key}{value}=$value;
  my $conf=$ENV{SCRAM_LOOKUPDB_WRITE}."/".$self->{siteconf};
  my $ref;
  if (!open($ref,">$conf")){print STDERR "ERROR: Unable to open for writing: $conf\n"; return 1;}
  foreach my $k (sort keys %{$self->{site}}){print $ref "$k=",$self->{site}{$k}{value},"\n";}
  close($ref);
  return 0;
}

1;

