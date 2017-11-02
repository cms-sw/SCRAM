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
  $self->{linkfile}='links.db';
  $self->{archs}={};
  $self->{listcache}= {};
  $self->{projects}={};
  $self->{domain}='';
  $self->{prodarch}={};
  eval {
    eval "use Net::Domain qw(hostdomain);";
    if(!$@){$self->{domain}=hostdomain();}
  };
  $self->verbose("Site domain is set to '".$self->{domain}."'");
  $ENV{SCRAM_LOOKUPDB}=&Utilities::AddDir::fixpath($ENV{SCRAM_LOOKUPDB});
  $self->_initDB();
  return $self;
}

sub getarea ()
{
  my $self=shift;
  my $name=shift;
  my $version=shift;
  my $force=shift;
  my $arch = $ENV{SCRAM_ARCH};
  my $data = $self->_findProjects($name,$version,1,$arch);
  my $selarch=undef;
  delete $self->{deprecated};
  if ((exists $data->{$arch}) && (scalar(@{$data->{$arch}}) == 1)) { $selarch=$arch;}
  elsif ($main::FORCE_SCRAM_ARCH eq "")
  {
    $data = $self->updatearchs($name,$version,{$arch});
    my @archs = keys %{$data};
    if (scalar(@archs)==1){$selarch=$archs[0];}
    elsif((scalar(@archs)>1) && (!$force)){$selarch=$self->productionArch($name,$version,$data->{$archs[0]}[0][2]);}
  }
  my $area=undef;
  if ((defined $selarch) and (exists $data->{$selarch}))
  {
    if (!$force)
    {
      my $tc = $self->getProjectModule($name);
      if (defined $tc)
      {
        $self->{deprecated}=int($tc->getDeprecatedDate($version,$selarch,$data->{$selarch}[0][2]));
        my $dep=$self->{deprecated};
        if ($dep>0)
        {
          my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
          $mon+=1;
          $year+=1900;
          if ($mon<10){$mon="0${mon}";}
          if ($mday<10){$mday="0${mday}";}
          if (($dep-int("${year}${mon}${mday}"))<=0){$self->{deprecated}=0;}
          else
          {
            $dep=~/^(\d\d\d\d)(\d\d)(\d\d)$/o;
            print STDERR "WARNING: Release $version will be deprecated on ${3}/${2}/${1}.\n",
                         "         It is better to use a newer version.\n";
          }
        }
        if ($self->{deprecated}==0)
        {
          print STDERR "ERROR: Project \"$name\" version \"$version\" has been deprecated.\n",
                       "       Please use a different non-deprecated release.\n";
          return $area;
        }
      }
    }
    $area=$self->getAreaObject($data->{$selarch}[0], $selarch);
  }
  return $area;
}

sub productionArch()
{
  my ($self,$project,$version,$release)=@_;
  my $rel_id="${project}:${version}";
  if (exists $self->{prodarch}{$rel_id}){return $self->{prodarch}{$rel_id};}
  my @archs=();
  if (defined $release)
  {
    my $ref;
    if (open($ref,"${release}/.SCRAM/production_arch"))
    {
      my $a=<$ref>; chomp $a;
      close($ref);
      if ($a){push @archs,$a;}
    }
  }
  if (scalar(@archs)==0)
  {
    my $tc = $self->getProjectModule($project);
    if (defined $tc){@archs=$tc->releaseArchs($version,1, $release);}
  }
  my $arch=undef;
  if (scalar(@archs)==1){$arch=$archs[0];}
  $self->{prodarch}{$rel_id}=$arch;
  return $arch;
}

sub getProjectModule()
{
  my ($self,$project)=@_;
  if (!exists $self->{project_module})
  {
    $self->{project_module}=undef;
    my $module="SCRAM::Plugins::".uc($project);
    eval {
      eval "use $module";
      if(! $@) {$self->{project_module}=$module->new();}
    };
  }
  return $self->{project_module};
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
  my ($self,$proj,$ver,$valid,$all)=@_;
  my $arch = $ENV{SCRAM_ARCH};
  my $xdata = $self->_findProjects($proj,$ver,undef,$arch,$valid);
  if ($all || ((!exists $xdata->{$arch}) && ($main::FORCE_SCRAM_ARCH eq "")))
  {
    foreach $arch (keys %{$self->{archs}})
    {
      if ($arch eq $ENV{SCRAM_ARCH}){next;}
      $xdata = $self->_findProjects($proj,$ver,undef,$arch,$valid,$xdata);
    }
  }
  return $xdata;
}

sub updatearchs()
{
  my ($self,$name,$version,$skiparch)=@_;
  $self->{listcache} = {};
  foreach my $arch (keys %{$self->{archs}})
  {
    if (exists $skiparch->{$arch}){next;}
    my $data = $self->_findProjects($name,$version,1,$arch);
    if ((exists $data->{$arch}) && (scalar(@{$data->{$arch}})==1)){$self->{listcache}{$arch}=$data->{$arch};}
  }
  return $self->{listcache};
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

sub getAreaObject ()
{
  my ($self,$data,$arch)=@_;
  my $area=Configuration::ConfigArea->new($arch);
  my $loc = $data->[2];
  if ($area->bootstrapfromlocation($loc) == 1)
  {
    $area = undef;
    print STDERR "ERROR: Attempt to ressurect ",$data->[0]," ",$data->[1]," from $loc unsuccessful\n";
    print STDERR "ERROR: $loc does not look like a valid release area for SCRAM_ARCH $arch.\n";
  }
  elsif (defined $data->[3]){$area->{basedir}=$data->[3];}
  return $area;
}

sub hasProject ()
{
  my ($self, $proj)=@_;
  return exists $self->{projects}{uc($proj)};
}
##################################################

sub _save ()
{
  my $self=shift;
  my $filename = $ENV{SCRAM_LOOKUPDB_WRITE}."/".$self->{scramrc};
  &Utilities::AddDir::adddir($filename);
  $filename = $self->_getLinkDBFile($filename);
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
  foreach my $f (glob("${db}/*.map"))
  {
    if((-f $f) && (open($ref,$f)))
    {
      while(my $line=<$ref>)
      {
        chomp $line; $line=~s/\s//go;
        if ($line=~/^([^=]+)=(.+)$/o)
	{
	  $self->{projects}{uc($1)}=1;
	  $self->{DBS}{uniq}{$scramdb}{uc($1)}{$2}=1;
	}
      }
      close($ref);
    }
  }
  if (!$local)
  {
    foreach my $proj (keys %{$self->{DBS}{uniq}{$localdb}})
    {
      if (!exists $self->{DBS}{uniq}{$scramdb}{$proj})
      {
        foreach my $path (keys %{$self->{DBS}{uniq}{$localdb}{$proj}}){$self->{DBS}{uniq}{$scramdb}{$proj}{$path}=1;}
      }
    }
  }
  my $varch=$ENV{SCRAM_ARCH}; $varch=~s/_[^_]+$//;
  foreach my $f (glob("${scramdb}/${varch}_*/cms/cms-common"))
  {
    if ($f=~/^${scramdb}\/([^\/]+)\/cms\/cms-common$/){$self->{archs}{$1}=1;}
  }
  if(open($ref, $self->_getLinkDBFile($db)))
  {
    my %uniq=();
    while(my $line=<$ref>)
    {
      chomp $line; $line=~s/\s//go;
      if (($line eq "") || (!-d $line)){next;}
      $line=&Utilities::AddDir::fixpath($line);
      if (exists $uniq{$line}){next;}
      $uniq{$line}=1;
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
  my $arch=shift || $ENV{SCRAM_ARCH};
  my $valid=shift || 0;
  my $xdata=shift || {};
  my %data=();
  my %uniq=();
  if (!exists $self->{archs}{$arch}){return $xdata;}
  $xdata->{$arch} = [];
  foreach my $base (@{$self->{DBS}{order}})
  {
    foreach my $p (keys %{$self->{DBS}{uniq}{$base}})
    {
      if ($p!~/^$proj$/){next;}
      my $db="${base}/".join(" ${base}/",keys %{$self->{DBS}{uniq}{$base}{$p}});
      $db=~s/\$(\{|\(|)SCRAM_ARCH(\}|\)|)/$arch/g;
      foreach my $fd (glob($db))
      {
        if (!-d $fd){next;}
	if (($valid) && (!-f "${fd}/.SCRAM/${arch}/timestamps/self")){next;}
	my $d=basename($fd);
	if ($exact)
	{
	  if ($d eq $ver){push @{$xdata->{$arch}}, [$p,$d,$fd,$base]; return $xdata;}
	}
	elsif ($d=~/$ver/)
	{
	  if(!exists $uniq{"$p:$d"})
	  {
	    $uniq{"$p:$d"}=1;
	    my $m = (stat($fd))[9];
	    $data{$m}{$p}{$d}=[$fd,$base];
	  }
	}
      }
    }
  }
  foreach my $m (sort {$a <=> $b} keys %data)
  {
    foreach my $p (keys %{$data{$m}})
    {
      foreach my $v (keys %{$data{$m}{$p}})
      {
        push @{$xdata->{$arch}}, [$p,$v,$data{$m}{$p}{$v}[0], $data{$m}{$p}{$v}[1]];
      }
    }
  }
  if (scalar(@{$xdata->{$arch}})==0){delete $xdata->{$arch};}
  return $xdata;
}

sub _getLinkDBFile()
{
  my ($self,$dir)=@_;
  my $linkdb=$self->{domain}."-".$self->{linkfile};
  if (!-e "${dir}/${linkdb}"){$linkdb=$self->{linkfile};}
  $self->verbose("Reading SCRAM DB at ${dir}/${linkdb}");
  return "${dir}/${linkdb}";
}

1;
