package SCRAM::ScramProjectDB;
use Utilities::Verbose;
use Utilities::AddDir;
use File::Basename;
require 5.004;
@ISA=qw(Utilities::Verbose);

sub new()
{
  my $class=shift;
  my $self={};
  bless $self, $class;
  $self->{scramrc}='etc/scramrc';
  $ENV{SCRAM_LOOKUPDB}=&Utilities::AddDir::fixpath($ENV{SCRAM_LOOKUPDB});
  $self->_initDB();
  return $self;
}

sub getarea ()
{
  my $self=shift;
  my $name=shift;
  my $version=shift;
  my $area=undef;
  my $data=$self->_findProjects($name,$version,1);
  if (exists $data->{$name}{$version})
  {
    require Configuration::ConfigArea;
    $area=Configuration::ConfigArea->new();
    my $location = $data->{$name}{$version};
    if ($area->bootstrapfromlocation($location) == 1)
    {
      undef $area;
      print STDERR "ERROR: Attempt to ressurect $name $version from $location unsuccessful\n";
      print STDERR "ERROR: $location does not look like a valid release area.\n";
    }
  }
  return $area;
}

sub listlinks()
{
  my $self=shift;
  my $links={};
  $links->{local}=[]; $links->{linked}=[]; 
  my %local=();
  foreach my $d (@{$self->{LocalLinks}}){$local{$d}=1; push @{$links->{local}},$d;}
  my $cnt=scalar(@{$self->{DBS}{order}});
  for(my $i=1;$i<$cnt;$i++)
  {
    my $d=$self->{DBS}{order}[$i];
    if (!exists $local{$d}){push @{$links->{linked}},$d;}
  }
  return $links;
}

sub listall()
{
  my $self=shift;
  return $self->_findProjects(shift,shift,shift);
}

sub link()
{
  my ($self,$db)=@_;
  $db=~s/^\s*file://o; $db=~s/\s//go;
  if ($db eq ""){return 1;}
  $db=&Utilities::AddDir::fixpath($db);
  if ($db eq $ENV{SCRAM_LOOKUPDB}){return 1;}
  if (-d $db)
  {
    foreach my $d (@{$self->{LocalLinks}}){if ($db eq $d){return 0;}}
    push @{$self->{LocalLinks}},$db;
    $self->_save ();
    return 0;
  }
  return 1;
}

sub unlink()
{
  my ($self,$db)=@_;
  $db=~s/^\s*file://o; $db=~s/\s//go;
  if ($db eq ""){return 1;}
  $db=&Utilities::AddDir::fixpath($db);
  my $cnt=scalar(@{$self->{LocalLinks}});
  for(my $i=0;$i<$cnt;$i++)
  {
    if ($db eq $self->{LocalLinks}[$i])
    {
      for(my $j=$i+1;$j<$cnt;$j++){$self->{LocalLinks}[$j-1]=$self->{LocalLinks}[$j];}
      pop @{$self->{LocalLinks}};
      $self->_save ();
      return 0;
    }
  }
  return 1;
}

##################################################

sub _save ()
{
  my $self=shift;
  my $filename = $ENV{SCRAM_LOOKUPDB}."/".$self->{scramrc};
  &Utilities::AddDir::adddir($filename);
  $filename.="/links";
  my $fh;
  if (!open ( $fh, ">$filename" )){die "Can not open file for writing: $filename\n";}
  foreach my $db (@{$self->{LocalLinks}}){if ($db ne ""){print $fh "$db\n";}}
  close($fh);
  my $mode=0644;
  chmod $mode,$filename;
}

sub _initDB ()
{
  my $self=shift;
  my $scramdb=shift;
  my $cache=shift || {};
  my $local=0;
  my $localdb=$ENV{SCRAM_LOOKUPDB};
  if (!defined $scramdb)
  {
    $scramdb=$localdb;
    $self->{DBS}{order}=[];
    $self->{DBS}{uniq}={};
    $self->{LocalLinks}=[];
    $local=1;
  }
  if (exists $self->{DBS}{uniq}{$scramdb}){return;}
  $self->{DBS}{uniq}{$scramdb}={};
  push @{$self->{DBS}{order}},$scramdb;
  my $db="${scramdb}/".$self->{scramrc};
  my $ref;
  foreach my $f (glob("${db}/projects/*"))
  {
    if((-f $f) && (open($ref,$f))
    {
      while(my $line=<$ref>)
      {
        chomp $line; $line=~s/\s//go;
        if ($line=~/^([^=]+)=(.+)$/o){$self->{DBS}{uniq}{$scramdb}{uc($1)}{$2}=1; last;}
      }
      close($ref);
    }
  }
  if (!exists $self->{DBS}{uniq}{$scramdb}{CMSSW}){$self->{DBS}{uniq}{$scramdb}{CMSSW}{"cms/{cmssw,cmssw-patch}/CMSSW_*"}=1;}
  if (!exists $self->{DBS}{uniq}{$scramdb}{CORAL}){$self->{DBS}{uniq}{$scramdb}{CORAL}{"cms/coral/CORAL_*"}=1;}
  if(open($ref, "${db}/links"))
  {
    while(my $line=<$ref>)
    {
      chomp $line; $line=~s/\s//go;
      if (($line eq "") || (!-d $line)){next;}
      $line=&Utilities::AddDir::fixpath($line);
      $self->_initDB($line,$cache);
      if ($local){push @{$self->{LocalLinks}},$line;}
    }
    close($ref);
  }
}

sub _findProjects()
{
  my $self=shift;
  my $proj=shift || '.+';
  my $ver=shift || '.+';
  my $exact=shift  || undef;
  my $data={};
  foreach my $base (@{$self->{DBS}{order}})
  {
    foreach my $p (keys %{$self->{DBS}{uniq}{$base}})
    {
      if ($p!~/^$proj$/){next;}
      my $db="${base}/$ENV{SCRAM_ARCH}/".join(" ${base}/$ENV{SCRAM_ARCH}/",keys %{$self->{DBS}{uniq}{$base}{$p}});
      foreach my $fd (glob($db))
      {
        if (!-d $fd){next;}
	my $d=basename($fd);
	if ($d=~/^$ver$/)
	{
	  if ($exact)
	  {
	    $data->{$p}{$d}=$fd;
	    return $data;
	  }
	  elsif(!exists $data->{$p}{$d}){$data->{$p}{$d}=$fd;}
	}
      }
    }
  }
  return $data;
}
