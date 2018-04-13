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
   if(exists $ENV{SCRAM_RTBOURNE_SET}){$self->{recursive}=1;}
   else{$self->{recursive}=0;}
   $self->{optional_paths}={};
   $self->init_();
   return $self;
}

sub runtimebuildenv()
{
  my $self=shift;
  my %save_env = ();
  foreach my $k ("LD_PRELOAD"){
    if (exists $ENV{$k})
    {
      $save_env{$k}=$ENV{$k};
      delete $ENV{$k};
    }
  }
  $self->save("RTBOURNE");
  foreach my $k (keys %{save_env}){$ENV{$k}=$save_env{$k};}
  $self->setenv ("RTBOURNE");
  if (exists $self->{env}{rtstring}{RTBOURNE})
  {
    foreach my $v (keys %{$self->{env}{rtstring}{RTBOURNE}})
    {
      $ENV{$v}=$self->{env}{rtstring}{RTBOURNE}{$v};
    }
  }
  return 0;
}

sub setenv()
{
  my $self=shift;
  if ($self->{recursive}){return;}
  my $s=shift;
  my $ref=shift || *STDOUT;
  my $sd = $self->{shell}{$s};
  my $sep=$sd->{SEP};
  my %udata=();
  my @data=(); my $index=0;
  if (!exists $self->{unsetenv})
  {
    my $env_prefix=$self->{env_backup_prefix};
    my $env=$self->runtime_();

    foreach my $h (@{$env->{variables}})
    {
      while (my ($var,$val) = each %$h)
      {
        $udata{$var}=1;
        $data[$index++]{$var}=$val->[0];
      }
    }
    foreach my $var (keys %{$env->{path}})
    {
      if ($var=~/^(.+?)_SRTOPT_(.+)$/){next;}
      $udata{$var}=1;
      my $btype = $self->{backup_type}{$var};
      $data[$index++]{$var}=$ENV{"${env_prefix}${var}${btype}"}.&fixpathvar_($var,$sep);
    }
    if ($s eq "RTBOURNE")
    {
      push @data,{"SCRAM_RTBOURNE_SET" => $ENV{SCRAMRT_SET}};
      foreach my $var (keys %{$env->{xenv}})
      {
        my $val=$env->{xenv}{$var};
        $udata{$var}=1;
        $data[$index++]{$var}=$val;
      }
    }
  }
  while(my ($var,$val) = each %ENV)
  {
    if (!exists $udata{$var})
    {
      unshift @data,{$var => $val};
      $udata{$var}=1;
    }
  }
  my $oenv=$self->{OENV};
  my $unset="";my $unset_vars="";
  foreach my $v (keys %$oenv)
  {
    if (!exists $udata{$v})
    {
      if ($s ne "RTBOURNE")
      {
        $unset.=" $v";
        if (($v!~/^SCRAMRT_/) && ($v!~/_SCRAMRT(DEL|)$/)){$unset_vars.="       $v\n";}
      }
      delete $ENV{$v};
    }
  }
  if($unset)
  {
    if ($unset_vars && (!exists $self->{unsetenv})){print STDERR "**** Following environment variables are going to be unset.\n$unset_vars";}
    print $ref $sd->{UNEXPORT}." $unset;\n";
  }
  
  foreach my $h (@data)
  {
    while (my ($var,$val) = each %$h)
    {
      if ($s eq "RTBOURNE")
      {
        if (($var=~/^SCRAMRT_.+$/) || ($var=~/_SCRAMRT(DEL|)$/)){if ($var ne "SCRAMRT_SET"){delete $ENV{$var};next;}}
        $ENV{$var} = $val;
	next;
      }
      if (($var ne "PATH") && (exists $oenv->{$var}))
      {
        my $v=$oenv->{$var};
	if ($val eq $v){next;}
      }
      $ENV{$var}=$val;
      print $ref $sd->{EXPORT}." ".$var.$sd->{EQUALS}."\"".$val."\";\n";
    }
  }
  return 0;
}

sub save()
{
  my $self=shift;
  if ($self->{recursive}){return;}
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
    my $env_prefix=$self->{env_backup_prefix};
    my $env = $self->runtime_();
    my @data=();my $index=0;
    my $sep=$self->{shell}{$shell}{SEP};
    my $skip=$self->{skipenv};
    foreach my $h (@{$env->{variables}})
    {
      while (my ($name, $value) = each %$h)
      {
	my $btype="_SCRAMRT";
	if (!exists $ENV{$name}){$btype="_SCRAMRTDEL";}
	$data[$index++]{"${env_prefix}${name}${btype}"}=$value->[0];
      }
    }
    $self->{backup_type}={};
    my %opt=();
    while (my ($name, $value) = each %{$env->{path}})
    {
      if ($name=~/^(.+?)_SRTOPT_(.+)$/)
      {
        if (exists $self->{optional_paths}{$1}){$opt{$2}{$1}=1;}
        next;
      }
      my $btype="_SCRAMRT";
      if (!exists $ENV{$name}){$btype="_SCRAMRTDEL";}
      $data[$index++]{"${env_prefix}${name}${btype}"}=&cleanpath_(join($sep,@$value),$sep);
      $self->{backup_type}{$name}=$btype;
    }
    foreach my $v (keys %opt)
    {
      my $btype="";
      my $nbtype="";
      if (exists $self->{backup_type}{$v})
      {
        $btype=$self->{backup_type}{$v};
	$nbtype=$btype;
      }
      else
      {
        $nbtype="_SCRAMRT";
	if (!exists $ENV{$v}){$nbtype="_SCRAMRTDEL";}
	$self->{backup_type}{$v}=$nbtype;
      }
      foreach my $t (keys %{$opt{$v}})
      {
	my $xindex=$index;
        my $pval="";
	if ($btype ne "")
	{
          for(my $i=0;$i<$index;$i++)
	  {
	    if (exists $data[$i]{"${env_prefix}${v}${btype}"})
	    {
	      $xindex=$i;
	      $pval=$data[$i]{"${env_prefix}${v}${btype}"};
	      last;
	    }
	  }
        }
	my $nval=join($sep,@{$env->{path}{$t."_SRTOPT_".$v}});
        if ($pval ne ""){$nval="${nval}${sep}${pval}";}
        $data[$xindex]{"${env_prefix}${v}${nbtype}"}=&cleanpath_($nval,$sep);
        if ($xindex == $index){$index++;}
      }
    }
    $data[$index++]{SCRAMRT_SET}="$ENV{SCRAM_PROJECTNAME}:$ENV{SCRAM_PROJECTVERSION}:$ENV{SCRAM_ARCH}:$ENV{SCRAM_VERSION}:${env_prefix}";
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

sub optional_env ()
{
  my $self=shift;
  $self->{optional_paths}={};
  foreach my $t (@_){$self->{optional_paths}{uc($t)}=1;}
}

sub unsetenv()
{
  my $self=shift;
  my $shell=shift || "TCSH";
  if (exists($ENV{SCRAMRT_SET}))
  {
    $self->{unsetenv}=1;
    $self->restore_environment_($shell);
    $self->setenv($shell);
    delete $self->{unsetenv};
  }
}

sub restore_environment_()
{
  my $self=shift;
  my $shell=shift;
  my @penv=split /:/,$ENV{SCRAMRT_SET};
  delete $ENV{SCRAMRT_SET};
  my $sep=$self->{shell}{$shell}{SEP};
  my %BENV=%ENV;
  my $pver=$penv[3] || "V1_";
  if ($pver=~/^V(\d+)_/){$pver=$1;}
  my $skip=$self->{skipenv};
  if ($pver=~/^[01]$/)
  {
    print STDERR "****WARNING: Setting up runtime environment on top of a OLD SCRAM-based environment.\n",
                 "**** Your environment was already setup for \"$penv[0]\" version \"$penv[1]\".\n",
                 "**** The changes you had made in envirnment after setting up \"$penv[0]\" version \"$penv[1]\"\n",
		 "**** are lost.\n";
    my %restoredenv;
    while (my ($name, $value) = each %BENV)
    {
      if ($name=~/_SCRAMRT(DEL|)$/){next;}
      elsif ($name =~ /^SCRAMRT_(.+)$/){$restoredenv{$1} = $value;}
      elsif ($name=~/$skip/){$restoredenv{$name} = $value;}
    }
    %BENV=%restoredenv;
  }
  else
  {
    my $prefix=$penv[4] || "";
    while (my ($name, $value) = each %BENV)
    {
      if ($name =~ /^SCRAMRT_/){delete $BENV{$name};}
      elsif ($name=~/$skip/){next;}
      elsif ($name =~ /^(.*)_SCRAMRT(DEL|)$/)
      {
        my $var=$1;
        my $type=$2;
        delete $BENV{$name};
	if ($prefix ne ""){$var=~s/^$prefix//;}
	if (exists $BENV{$var})
	{
	  my $v = $BENV{$var};
	  if ($v eq $value){$v="";}
	  else
	  {
	    $v=~s/^(.*?$sep|)\Q$value\E($sep.*|)$/$1$2/;
	    $v=~s/^$sep*//;
	    $v=~s/$sep*$//;
	    $v=~s/$sep$sep/$sep/g;
          }
          if (($v eq "") && ($type eq "DEL")){delete $BENV{$var};}
	  else{$BENV{$var}=$v;}
	}
      }
    }
  }
  %ENV=%BENV;
}

sub init_ ()
{
  my $self=shift;
  foreach my $v (keys %ENV){$self->{OENV}{$v}=$ENV{$v};}
  my $v=$ENV{SCRAM_VERSION};
  if ($v=~/^V(\d+)_(\d+)_.*/)
  {
    if (($1 > 2) || (($1 == 2) && ($2 >= 2))){$v="SRT_";}
    else{$v="";}
  }
  else{$v="";}
  $self->{env_backup_prefix}=$v;
  $self->{skipenv}='^(_|PWD|PROMPT_COMMAND|SCRAM_.+|SCRAMV1_.+|SCRAM|LOCALTOP|RELEASETOP|BASE_PATH)$';
  $self->{shell} =
     {
     BOURNE =>
	 {
	 EQUALS => '=',
	 SEP => ':',
	 EXPORT => 'export',
	 UNEXPORT => 'unset',
	 },
     TCSH =>
	 {
	 EQUALS => ' ',
	 SEP => ':',
	 UNEXPORT => 'unsetenv',
	 EXPORT => 'setenv',
	 },
     CYGWIN =>
	 {
	 EQUALS => '=',
	 SEP => ';',
	 UNEXPORT => 'unset',
	 EXPORT => 'set',
	 },
     RTBOURNE =>
	 {
	 EQUALS => '=',
	 SEP => ':',
	 EXPORT => 'export',
	 }
      };
}

sub update_overrides_()
{
  my $self=shift;
  if ((exists $self->{env}{rtstring}{path}) && (exists $self->{env}{rtstring}{path}{PATH}))
  {
    my $override = $main::installPath . "/share/overrides/bin";
    if (-e $override)
    {
      unshift @{$self->{env}{rtstring}{path}{PATH}}, $override;
    }
  }
  if (! exists $self->{OENV}{"SCRAM_IGNORE_RUNTIME_HOOK"}){$self->runtime_hooks_();}
}

sub runtime_hooks_()
{
  my $self=shift;
  my $debug=0;
  if (exists $self->{OENV}{SCRAM_HOOKS_DEBUG}){$debug=1;}
  my $area = $self->{scram}->localarea();
  my $hook=$area->location()."/".$area->configurationdir()."/SCRAM/hooks/runtime-hook";
  if($debug){print STDERR "SCRAM_HOOK: $hook\n";}
  if (! -x $hook){return;}
  if ($debug){print STDERR "SCRAM_HOOK: Found\n";}
  my $out=`$hook 2>&1`;
  if ($debug){print STDERR "SCRAN_HOOK: $out";}
  foreach my $line (split("\n",$out))
  {
    if ($line!~/^runtime:((path:(append|prepend|remove):[a-zA-Z0-9-_]+)|(variable:[a-zA-Z0-9-_]+))=/io){print STDERR "$line\n"; next;}
    my @vals = split("=",$line,2);
    my @items = split(":",$vals[0]);
    my $vtype = lc($items[1]);
    if ($vtype eq "path")
    {
      if(! exists $self->{env}{rtstring}{path}){$self->{env}{rtstring}{path}={};}
      my $c = $self->{env}{rtstring}{path};
      $vtype=lc($items[2]);
      my $evar = $items[3];
      if (($vtype ne "remove") && (! exists $c->{$evar})){$c->{$evar}=[];}
      foreach my $d (split(":",$vals[1]))
      {
        $d=~s/\s//g;
        if($d eq ""){next;}
        if ($vtype eq "append"){push(@{$c->{$evar}},$d);}
        elsif ($vtype eq "prepend"){unshift @{$c->{$evar}}, $d;}
        elsif ($vtype eq "remove")
        {
          my $npath=[];
          foreach my $x (@{$c->{$evar}})
          {
            if ($x eq $d){next;}
            push(@$npath,$x);
          }
          $c->{$evar}=$npath;
        }
      }
    }
    elsif ($vtype eq "variable")
    {
      if (! exists $self->{env}{rtstring}{variables}){$self->{env}{rtstring}{variables}=[];}
      my $c = $self->{env}{rtstring}{variables};
      my $vindex = 0;
      my $evar = $items[2];
      if (exists $self->{env}{variables}{$evar}){$vindex = $self->{env}{variables}{$evar};}
      else{$vindex = scalar(@{$c});}
      $c->[$vindex]{$evar}=[$vals[1]];
    }
  }
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
      $self->{env}{rtstring}=&Cache::CacheUtilities::read($cache);
      $self->update_overrides_();
      return $self->{env}{rtstring};
    }
  }
  $self->{env}{rtstring}{variables}=[];
  $self->{env}{rtstring}{path}={};
  my $tmanager = $scram->toolmanager();
  my $otools = $tmanager->toolsdata();
  my $tools  = $tmanager->setup();
  $self->{force_tools_env}={};
  $self->{skip_runtime}={};
  $self->{force_tools_env}{self}=1;
  $self->{force_tools_env}{lc($ENV{SCRAM_PROJECTNAME})}=1;
  if (exists $tools->{'self'})
  {
    push @$otools,$tools->{'self'};
    if (exists $tools->{self}{FLAGS}{NO_EXTERNAL_RUNTIME})
    {
      foreach my $x (@{$tools->{self}{FLAGS}{NO_EXTERNAL_RUNTIME}}){$x=&fixlibenv_($x); $self->{skip_runtime}{$x}=1;}
    }
    if(exists $tools->{self}{FLAGS}{SKIP_TOOLS_SYMLINK})
    {
      foreach my $t (@{$tools->{self}{FLAGS}{SKIP_TOOLS_SYMLINK}}){$self->{force_tools_env}{lc($t)}=1;}
    }
    if (exists $tools->{self}{FLAGS}{DEFAULT_COMPILER})
    {
      $self->{env}{rtstring}{RTBOURNE}{DEFAULT_COMPILER}=$tools->{self}{FLAGS}{DEFAULT_COMPILER}[0];
    }
  }
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
  $self->update_overrides_();
  return $self->{env}{rtstring};
}
   
sub toolenv_ ()
{
  my $self=shift;
  my $tool=shift;
  my $vindex=scalar(@{$self->{env}{rtstring}{variables}});
  my $tname=$tool->toolname();
  my $toolrt = $tool->runtime();
  my $gmake="";
  my $projTool=0;
  if ($tname eq lc($ENV{SCRAM_PROJECTNAME})){$projTool=1;}
  if (defined ($toolrt))
  {
    while (my ($trtvar, $trtval) = each %{$toolrt})
    {
      if ($trtvar =~ /^PATH:(.*?)$/)
      {
	my $x=$1;
	if ($projTool && ($ENV{SCRAM_ARCH}=~/^osx/) && ($x eq "DYLD_LIBRARY_PATH")){$x="LD_LIBRARY_PATH";}
	$x = &fixlibenv_($x);
	(! exists $self->{env}{rtstring}{path}{$x}) ? $self->{env}{rtstring}{path}{$x} = [] : undef;
	map
	{
	  if (($tname eq "gmake") && ($x eq "PATH") && ($gmake eq "") && (-x $_."/gmake"))
	  {
	    $gmake=$_."/";
	    $self->{env}{rtstring}{xenv}{SCRAM_GMAKE_PATH}=$gmake;
	  }
	  if ((!exists $self->{skip_runtime}{$x}) || (exists $self->{force_tools_env}{$tname}))
	  {
	    if (! exists ($self->{env}{paths}{$x}{$_}))
	    {
	      $self->{env}{paths}{$x}{$_} = 1 ;
	      push(@{$self->{env}{rtstring}{path}{$x}},$_);
	    }
	  }
	} @$trtval; 
      }
      else
      {
	if (! exists ($self->{env}{variables}{$trtvar}))
	{
	  $self->{env}{variables}{$trtvar} = $vindex;
	  $self->{env}{rtstring}{variables}[$vindex++]{$trtvar}=$trtval;
	}
      }
    }
  }
}

sub cleanpath_()
{
  my $str=shift;
  my $sep=shift;
  my %upath=();
  my @opath=();
  foreach my $p (split /$sep+/,$str)
  {
    while($p=~s/\/\//\//g){}
    while($p=~s/\/\.\//\//g){}
    while($p=~s/\/\.$//){}
    if ($p eq ""){$p="/";}
    if(!exists $upath{$p})
    {
      $upath{$p}=1;
      push @opath,$p;
    }
  }
  return join($sep,@opath);
}

sub fixpathvar_ ()
{
  my $var=shift;
  my $sep=shift;
  ((exists $ENV{$var}) && ($ENV{$var} ne "")) ? return "$sep$ENV{$var}" : return "";
}

sub fixlibenv_ ()
{
  my $var=shift;
  if ($ENV{SCRAM_ARCH}=~/^osx/){$var=~s/^LD_LIBRARY_PATH$/DYLD_FALLBACK_LIBRARY_PATH/;}
  return $var;
}

1;
