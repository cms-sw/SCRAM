package SCRAM::Plugins::DocParser;
require 5.004;
use strict;

sub new()
{
   my $class=shift;
   my $self={};
   bless $self, $class;
   my ($dataclass,$parse_style,$flag)=@_;
   $self->{style}=lc($parse_style);
   $self->{pkg}=$dataclass;
   $self->{keep_running_onerror}=$flag || 0;
   return $self;
}

sub parse()
{
  my $self=shift;
  my $file=shift;
  my $data=shift;
  my $res=0;
  if (defined $data){$res=$self->initdata_($file,$data);}
  else{$res=$self->initfile_($file);}
  if($res){$res=$self->process_();}
  return $res;
}

sub getOutput()
{
  my $self=shift;
  return $self->{output}{child}[0];
}

sub process_()
{
  my $self=shift;
  my $input=$self->{input};
  my $ltagcount=scalar(@{$self->{currenttag}});
  my $parent=$self->{output};
  my $ptname="";
  if ($ltagcount>0)
  {
    $parent=$self->{currenttag}[$ltagcount-1];
    $ptname=$parent->{name};
    while(($input=~/^(\s*)(\s*)$/) || ($input=~/^([^<]+?)(<.*|)$/))
    {
      $input=$2;
      my $cdata=$1;
      if($cdata!~/^\s*$/){push @{$parent->{cdata}},$cdata;}
      $self->{input}=$input;
      if($input eq "")
      {
        if($self->read_()){$input=$self->{input};}
	else
	{
	  $self->parseError_("Missing closing tag \"$ptname\".\n");
	  return 0;
	}
      }
    }
  }
  while (1)
  {
    while($input!~/^\s*<.+?>/)
    {
      if (($ltagcount==0) && ($input!~/^\s*(<|)$/)){$self->parseError_("Parsing error.\n",1);return 0;}
      if($self->read_()){$input=$self->{input};}
      else
      {
        if(($input=~/^\s*$/) && ($ltagcount==0)){return 1;}
	elsif($ltagcount){$self->parseError_("Missing closing tag \"$ptname\".\n",1);}
	else{$self->parseError_("Parsing error.\n",1);}
        return 0;
      }
    }
    if($input=~/^\s*<\s*(.+?)\s*>(.*)$/)
    { 
      my $tagline=$1; $input=$2;
      if($tagline=~/^\s*$/){$self->parseError_("Empty tag found.\n",1);return 0;}
      elsif($tagline=~/^\?xml\s*/){$self->{input}=$input;}
      else
      {
        my $tag={};
        if(!$self->parseTag_($tagline,$tag)){return 0;}
        $tag->{cdata}=[];
        $tag->{child}=[];
	$self->{input}=$input;
	my $tname=$tag->{name};
        if (!exists $tag->{close})
        {
	  eval{$self->handleEvents_($tag,$tname,1);};
	  push @{$self->{currenttag}},$tag;
	  if(!$self->process_()){return 0;}
	  $tag=pop @{$self->{currenttag}};
	  $self->handleEvents_($tag,$tname,2);
	  push @{$parent->{child}},$tag;
	  $input=$self->{input};
        }
        elsif(exists $tag->{attrib})
        {
	  delete $tag->{close};
	  $self->handleEvents_($tag,$tname,1);
	  $self->handleEvents_($tag,$tname,2);
	  push @{$parent->{child}},$tag;
        }
	elsif($ltagcount)
	{
	  if($tname eq $ptname){return 1;}
	  else{$self->parseError_("Found closing tag \"$tname\" while looking for \"$ptname\".\n",1);return 0;}
	}
	else{$self->parseError_("Found extra closing tag \"$tname\".\n",1);return 0;}
      }
    }
  }
  return 1;
}

sub handleEvents_()
{
  my $self=shift;
  my $tag=shift;
  my $name=shift;
  my $type=shift;
  my %attrib=();
  if($self->{style} eq "subs")
  {
    if($type == 1)
    {
      eval{$self->{pkg}->$name($name,%{$tag->{attrib}});};
      if ($@){die "$@\n";}
    }
    elsif($type == 2)
    {
      my $name_="${name}_";
      eval{$self->{pkg}->$name_($name,$tag->{cdata});};
      if ($@){die "$@\n";}
    }
  }
}

sub parseTag_()
{
  my $self=shift;
  my $line=shift;
  my $tag=shift;
  if($line=~/^([^\s\/]+)\s*(.*)$/)
  {
    my $n=lc($1); $line=$2;
    if(!$self->validTag_($n)){return 0;}
    $tag->{name}=$n;
    $tag->{attrib}={};
    while($line=~/^([^\s=]+)\s*=\s*(.*)$/)
    {
      my $k=lc($1); $line=$2;
      if(!$self->validAttrib_($k)){return 0;}
      if($line=~/^["](.*?)["]\s*(.*)$/)
      {
        $line=$2;
	$tag->{attrib}{$k}=$self->decode_($1);
      }
      else{$self->parseError_("Wrong value for attribute \"$k\" of tag \"$n\". Correct syntex is <$n $k=\"values\">. May be missing start/end '\"'\n"); return 0;}
    }
    if($line=~/^\s*$/){return 1;}
    elsif($line=~/^\/$/){$tag->{close}=1;return 1;}
    else{$self->parseError_("Parsing error while getting attributes for tag \"$n\" using \"$line\".\n");return 0;}
  }
  elsif($line=~/^\/\s*(.+)$/)
  {
    my $n=lc($1);
    if(!$self->validTag_($n)){return 0;}
    $tag->{name}=$n;
    $tag->{close}=1;
  }
  else{$self->parseError_("Parsing error.\n");return 0;}
}

sub decode_()
{
  my $self=shift;
  my $data=shift;
  return $data;
}

sub validTag_()
{
  my $self=shift;
  my $n=shift;
  my $res=1;
  if($n!~/^[a-z][a-z0-9_]{2,}$/)
  {
    $self->parseError_("Wrong tag \"$n\". It should start with an alphabet character, should be at least 3 character long and should have only alphanumeric plus \"_\" charachters\n");
    $res=0;
  }
  return $res;
}

sub validAttrib_()
{
  my $self=shift;
  my $k=shift;
  my $res=1;
  if($k!~/^[a-zA-Z][a-zA-Z0-9_]{2,}$/)
  {
    $self->parseError_("Wrong attribute \"$k\". It should start with an alphabet character, should be at least 3 character long and should have only alphanumeric plus \"_\" charachters\n");
    $res=0;
  }
  return $res;
}

sub parseError_()
{
  my $self=shift;
  my $msg=shift;
  my $lineflag=shift || 0;
  print STDERR "ERROR: SCRAM::Plugins::DocParser:",$self->{file},":",$self->{linenum},":";
  print STDERR "$msg";
  if ($lineflag)
  {print STDERR "######### START #########\n",$self->{input},"\n######### END #########\n";}
  if(!$self->{keep_running_onerror})
  {exit 1;}
}

sub initfile_()
{
  my $self=shift;
  my $file=shift;
  $self->init_($file);
  my $ref;
  if(!open($ref,$file))
  {
    print STDERR "ERROR: SCRAM::Plugins::DocParser: No such file to read:$file\n";
    return 0;
  }
  while(my $line=<$ref>){chomp $line; push @{$self->{data}},$line;}
  close($ref);
  return 1;
}

sub initdata_()
{
  my $self=shift;
  my $file=shift;
  my $data=shift;
  $self->init_($file);
  foreach my $line (split /\n+/,$data){ push @{$self->{data}},$line;}
  return 1;
}

sub init_()
{
  my $self=shift;
  my $file=shift;
  $self->{data}=[];
  $self->{output}{child}=[];
  $self->{linenum}=0;
  $self->{file}=$file;
  $self->{input}="";
  $self->{currenttag}=[];
}

sub read_()
{
  my $self=shift;
  while(1)
  {
    my $line=$self->removeCommnet_($self->readLine_());
    if (!defined $line){return 0;}
    if ($line=~/^\s*$/o){next;}
    $self->{input}.=$line;
    return 1;
  }
}

sub readLine_()
{
  my ($self)=@_;
  my $line=shift @{$self->{data}};
  if(defined $line){$self->{linenum}++;}
  return $line;
}

sub removeCommnet_()
{
  my ($self,$line)=@_;
  my $preline="";
  if(!defined $line){return $line;}
  if ($line=~/^\s*#/o){$line="";}
  elsif ($line=~/(.*)<\s*!--\s*(.*)$/o)
  {
    $preline=$1; $line=$2;
    while(1)
    {
      if ($line=~/^.*\s*--\s*>\s*(.*)$/o){$line=$self->removeCommnet_($1); last;}
      else
      {
        $line=$self->readLine_();
        if (!defined $line){$self->parseError_("Missing '-->' i.e. closing tag for comment.\n"); last;}
      }
    }
  }
  if (defined $line){$line="${preline}${line}";}
  return $line;
}

1;
