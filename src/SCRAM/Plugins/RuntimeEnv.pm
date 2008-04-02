package SCRAM::Plugins::RuntimeEnv;
require 5.004;
use strict;

sub new()
{
   my $class=shift;
   my $self={};
   bless $self, $class;
   my $scram=shift;
   $self->{scram}=$scram;
   $self->init_();
   return $self;
}

sub runtimebuildenv()
{
  my $self=shift;
  $self->save("RTBOURNE");
  $self->setenv ("RTBOURNE");
  return 0;
}

sub setenv()
{
  my $self=shift;
  my $s=shift;
  my $ref=shift || *STDOUT;
  my $sd = $self->{shell};
  my $env=$self->runtime_();
  my %udata=();
  my @data=(); my $index=0;
  foreach my $h (@{$env->{variables}})
  {
    while (my ($var,$val) = each %$h)
    {
      $udata{$var}=1;
      if ($s eq "RTBOURNE"){$data[$index++]{$var}=$sd->{$s}->{SETSTRING}(@$val);}
      else{$data[$index++]{$var}=$sd->{$s}->{QUOTE}(@$val);}
    }
  }
  foreach my $var (keys %{$env->{path}})
  {
    my $val=$env->{path}{$var};
    $udata{$var}=1;
    if ($s eq "RTBOURNE"){$data[$index++]{$var}=$sd->{$s}->{SETSTRING}(join($sd->{$s}->{SEP},@$val).$sd->{$s}->{PRINTVAR}($var));}
    else{$data[$index++]{$var}=$sd->{$s}->{QUOTE}(join($sd->{$s}->{SEP},@$val).$sd->{$s}->{PRINTVAR}($var));}
  }
  
  my $oenv=$self->{OENV};
  while(my ($var,$val) = each %ENV)
  {
    if (!exists $udata{$var})
    {
      if ($s eq "RTBOURNE"){unshift @data,{$var => $val};}
      else{unshift @data,{$var => $sd->{$s}->{QUOTE}($val)};}
      $udata{$var}=1;
    }
  }
  my $unset="";
  foreach my $v (keys %$oenv)
  {
    if (!exists $udata{$v})
    {
      if ($s eq "RTBOURNE"){delete $ENV{$v};}
      else{$unset.=" $v";}
    }
  }
  if($unset){print $ref $sd->{$s}->{UNEXPORT}." $unset;\n";}
  
  foreach my $h (@data)
  {
    while (my ($var,$val) = each %$h)
    {
      if ($s eq "RTBOURNE"){$ENV{$var} = $val;next;}
      if (exists $oenv->{$var})
      {
        my $v=$oenv->{$var};
	if ($val eq "\"$v\";"){next;}
      }
      print $ref $sd->{$s}->{EXPORT}." ".$var.$sd->{$s}->{EQUALS}.$val."\n";
    }
  }
  return 0;
}

sub save()
{
  my $self=shift;
  my $shell=shift;
  my $ref=shift || *STDOUT;
  if (exists($ENV{SCRAMRT_SET}))
  {
    $self->restore_environment_($shell);
    delete $ENV{SCRAMRT_SET};
    $self->save($shell,$ref);
  }
  else
  {
    my $env = $self->runtime_();
    my @data=();my $index=0;
    my $c=$self->{shell}{$shell}{SEP};
    foreach my $h (@{$env->{variables}})
    {
      while (my ($name, $value) = each %$h)
      {
	if(exists $ENV{$name}){$data[$index++]{"${name}_SCRAMRT"}=$value->[0];}
	else{$data[$index++]{"${name}_SCRAMRTDEL"}=$value->[0];}
      }
    }
    while (my ($name, $value) = each %{$env->{path}})
    {
      my $str=join($c,@$value);
      if(exists $ENV{$name}){$data[$index++]{"${name}_SCRAMRT"}=$str;}
      else{$data[$index++]{"${name}_SCRAMRTDEL"}=$str;}
    }
    while (my ($name, $value) = each %ENV)
    {
      next if ($name=~/^(_|PWD|PROMPT_COMMAND|SCRAM_.*|SCRAM|LOCALTOP|RELEASETOP|LOCALRT|BASE_PATH)$/);
      if (exists $env->{path}{$name}){$value=&cleanpath_("SCRAMRT_$name",$value,$c);}
      $data[$index++]{"SCRAMRT_$name"}=$value;
    }
    $data[$index++]{SCRAMRT_SET}="$ENV{SCRAM_PROJECTNAME}:$ENV{SCRAM_PROJECTVERSION}:$ENV{SCRAM_VERSION}";
    my $sd = $self->{shell}{$shell};
    foreach my $v (@data)
    {
      while(my ($name, $value) = each %$v)
      {
        $value =~ s/\"/\\\"/g; $value =~ s/\`/\\\`/g;
        $ENV{$name}=$value;
      }
    }
  }
}

sub restore_environment_()
{
  my $self=shift;
  my $shell=shift;
  my @penv=split /:/,$ENV{SCRAMRT_SET};
  delete $ENV{SCRAMRT_SET};
  my $env = $self->runtime_();
  my $s=$self->{shell}{$shell}{SEP};
  my %BENV=%ENV;
  my $pver=$penv[2] || "V1_";
  while (my ($name, $value) = each %BENV)
  {
    if ($name =~ /^(.*)_SCRAMRT(DEL|)$/)
    {
      my $var=$1;
      my $type=$2;
      if ($pver=~/^V[01]_/)
      {
        delete $BENV{$name};
        delete $BENV{$var};
	if ($type eq "DEL"){delete $BENV{"SCRAMRT_$var"};}
	next;
      }
      my $v1 = $BENV{$name};
      my $v2 = $BENV{$var};
      delete $BENV{$name};
      delete $BENV{$var};
      if (exists $env->{path}{$var})
      {
	$v2=~s/^(.*?$s|)\Q$v1\E($s.*|)$/$1$2/;
	$v2=~s/^$s*//;$v2=~s/$s*$//;$v2=~s/$s$s/$s/g;
      }
      elsif ($v2 eq $v1){$v2="";}
      if (($v2 eq "") && ($type eq "DEL"))
      {delete $BENV{"SCRAMRT_$var"};next;}
      $BENV{"SCRAMRT_$var"}=$v2;
    }
  }
  while (my ($name, $value) = each %BENV)
  {
    if ($name =~ /^SCRAMRT_(.*)/)
    {
      my $var=$1;
      my $v1=$BENV{$name};
      delete $BENV{$name};
      if (exists $env->{path}{$var}){$v1=&cleanpath_($var,$v1,$s);}
      $BENV{$var}=$v1;
    }
  }
  %ENV=%BENV;
  if ($pver=~/^V[01]_/)
  {
    print STDERR "****WARNING: Setting up runtime environment on top of a OLD SCRAM-based environment.\n",
                 "**** Your environment was already setup for \"$penv[0]\" version \"$penv[1]\".\n",
                 "**** The changes you had made in envirnment after setting up \"$penv[0]\" version \"$penv[1]\"\n",
		 "**** environment are lost.\n";
  }
}

sub init_ ()
{
  my $self=shift;
  foreach my $v (keys %ENV){$self->{OENV}{$v}=$ENV{$v};}
  $self->{shell} =
     {
     BOURNE =>
	 {
	 EQUALS => '=',
	 SEP => ':',
	 EXPORT => 'export',
	 UNEXPORT => 'unset',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ':$'.'SCRAMRT_'.$_[0] : return '' },
	 QUOTE => sub { return "\"$_[0]\";" }
	 },
     TCSH =>
	 {
	 EQUALS => ' ',
	 SEP => ':',
	 UNEXPORT => 'unsetenv',
	 EXPORT => 'setenv',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ':{$'.'SCRAMRT_'.$_[0].'}' : return '' },
	 QUOTE => sub { return "\"$_[0]\";" }
	 },
     CYGWIN =>
	 {
	 EQUALS => '=',
	 SEP => ';',
	 UNEXPORT => 'unset',
	 EXPORT => 'set',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ';%'.'SCRAMRT_'.$_[0] : return '' },
	 QUOTE => sub { return "\"$_[0]\";" }
	 },
     RTBOURNE =>
	 {
	 EQUALS => '=',
	 SEP => ':',
	 EXPORT => 'export',
	 PRINTVAR => sub { (exists $ENV{$_[0]}) ? return ':'.$ENV{$_[0]} : return '' },
	 QUOTE => sub { return "\"$_[0]\";" },
	 SETSTRING => sub { return "$_[0]" }
	 }
      };
}
   
sub runtime_ ()
{
  my $self=shift;
  if (exists $self->{env}{rtstring}){return $self->{env}{rtstring};}
  $self->{env}={};
  my $scram=$self->{scram};
  my $cdir=$scram->localarea()->archdir();
  my $cache="${cdir}/RuntimeCache.db.gz";
  if(-f $cache && -s $cache)
  {
    my $ctime=(stat($cache))[9];
    my $ttime=(stat("${cdir}/ToolCache.db.gz"))[9];
    if ($ttime < $ctime)
    {
      use Cache::CacheUtilities;
      my $c=&Cache::CacheUtilities::read($cache);
      $self->{env}{rtstring}=&Cache::CacheUtilities::read($cache);
      return $self->{env}{rtstring};
    }
  }
  $self->{env}{rtstring}{variables}=[];
  $self->{env}{rtstring}{path}={};
  my $tmanager = $scram->toolmanager();
  my $otools = $tmanager->toolsdata();
  my $tools  = $tmanager->setup();
  if (exists $tools->{'self'}){push @$otools,$tools->{'self'};}
  my @compilertools=();
  foreach my $tool ( reverse @$otools )
  {
    if ($tool->scram_compiler()){push @compilertools,$tool; next;}
    $self->toolenv_($tool);
  }
  foreach my $tool ( @compilertools ){$self->toolenv_($tool);}
  my $vindex=scalar(@{$self->{env}{rtstring}{variables}});
  foreach my $k (keys %{$self->{env}}){if($k ne "rtstring"){delete $self->{env}{$k};}}
  my $cref;
  if (open($cref,">$cache"))
  {
    close($cref);
    use Cache::CacheUtilities;
    &Cache::CacheUtilities::write($self->{env}{rtstring},$cache);
  }
  return $self->{env}{rtstring};
}
   
sub toolenv_ ()
{
  my $self=shift;
  my $tool=shift;
  my $vindex=scalar(@{$self->{env}{rtstring}{variables}});
  my $tname=$tool->toolname();
  my $toolrt = $tool->runtime();
  if (defined ($toolrt))
  {
    while (my ($toolrt, $trtval) = each %{$toolrt})
    {
      if ($toolrt =~ /^PATH:(.*?)$/)
      {
        (! exists $self->{env}{rtstring}{path}{$1}) ? $self->{env}{rtstring}{path}{$1} = [] : undef;
	map
	{
	  if (! exists ($self->{env}{paths}{$1}{$_}))
	  {
	    $self->{env}{paths}{$1}{$_} = 1 ;
	    push(@{$self->{env}{rtstring}{path}{$1}},$_);
	  }
	} @$trtval; 
      }
      else
      {
	if (! exists ($self->{env}{variables}{$toolrt}))
	{
	  $self->{env}{variables}{$toolrt} = 1;
	  $self->{env}{rtstring}{variables}[$vindex++]{$toolrt}=$trtval;
	}
      }
    }
  }
}

sub cleanpath_()
{
  my $var=shift;
  my $str=shift;
  my $c=shift;
  my %upath=();
  my @opath=();
  foreach my $p (split /$c+/,$str){if(!exists $upath{$p}){push @opath,$p; $upath{$p}=1;}}
  return join($c,@opath);
}

1;
