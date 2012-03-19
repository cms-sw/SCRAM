package SCRAM::Plugins::Doc2XML;
use File::Basename;
require 5.004;

sub new()
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self={};
   bless $self,$class;
   $self->init_(shift);
   return $self;
   }

sub init_ ()
   {
   my $self=shift;
   my $convert=shift;
   if((!defined $convert) && (exists $ENV{SCRAM_XMLCONVERT})){$convert=1;}
   $self->{xmlconvert}=$convert || 0;
   if ($ENV{SCRAM_VERSION}=~/^V[2-9]/){$self->{dbext}="db.gz";}
   else{$self->{dbext}="db";}
   $self->clean();
   foreach my $tag ("project","config","download","requirementsdoc","base",
                    "tool","client","environment","runtime","productstore","classpath",
		    "use","flags","architecture","lib","bin","library",
		    "include","select","require","include_path")
      {
      $self->{tags}{$tag}{map}="defaultprocessing";
      }
   foreach   my $tag ("base","tool","client","architecture","bin","library","project","makefile","export","environment")
      {
      $self->{tags}{$tag}{close}=1;
      }
   foreach my $tag ("export","client","environment") 
      {
      $self->{tags}{$tag}{map}="defaultsimple";
      }
   }
   
sub convert()
   {
   my $self=shift;
   my $file=shift;
   $self->clean();
   $self->{filename}=$file;
   if ($self->{xmlconvert})
   {
     $self->{sections}{nonexport}[0]={};
     $self->{sections}{export}[0]={};
     if (!exists $self->{tools})
     {
       use Cache::CacheUtilities;
       $self->{tools}={};
       $self->{bfproduct}={};
       my $dbext=$self->{dbext};
       my $cache=&Cache::CacheUtilities::read("$ENV{LOCALTOP}/.SCRAM/$ENV{SCRAM_ARCH}/ToolCache.${dbext}");
       foreach my $tool (keys %{$cache->{SETUP}}){$self->{tools}{$tool}=1;}
       $cache=();
       $cache=&Cache::CacheUtilities::read("$ENV{LOCALTOP}/.SCRAM/$ENV{SCRAM_ARCH}/ProjectCache.${dbext}");
       foreach my $dir (keys %{$cache->{BUILDTREE}})
       {
         if (($cache->{BUILDTREE}{$dir}{PUBLIC}) && (exists $cache->{BUILDTREE}{$dir}{METABF}))
	 {
	   foreach my $bf (@{$cache->{BUILDTREE}{$dir}{METABF}})
	   {
	     $bf=~s/.xml$//;
	     $self->{bfproduct}{$bf}=$cache->{BUILDTREE}{$dir}{NAME};
	   }
         }
       }
       $cache=();
     }
   }
   my $fref;
   open($fref,$file) || die "Can not open file for reading: $file";
   while(my $line=<$fref>)
      {
      chomp $line;
      push @{$self->{input}},$line;
      }
   close($fref);
   $self->{count}=scalar(@{$self->{input}});
   $self->process_();
   $self->{input}=[];
   if ($self->{xmlconvert}){delete $self->{sections};}
   return $self->{output};
   }

sub clean ()
   {
   my $self=shift;
   $self->{input}=[];
   $self->{output}=[];
   }
   
sub lastTag ()
   {
   my $self=shift;
   my $tags=shift;
   pop @$tags;
   $self->{tagdepth}=$self->{tagdepth}-1;
   if ($self->{tagdepth}>0){return $tags->[$self->{tagdepth}-1];}
   return "";
   }
   
sub process_()
   {
   my $self=shift;
   my $num=0;
   my $count=$self->{count};
   my $file=$self->{filename};
   my $line="";
   my @tags=();
   my $ltag="";
   my $pline="";
   my $err=0;
   $self->{tagdepth}=0;
   $self->{bfsection}="nonexport";
   while ($line || (($num<$count) && (($line=$self->{input}[$num++]) || 1)))
      {
      if ($line=~/^\s*#/){$line="";next;}
      if ($line=~/^\s*$/){$line="";next;}
      if ($line eq $pline)
         {
	 $err++;
	 if($err>10)
	   {last;}
	 }
      else{$err=0;}
      $pline=$line;
      if ($line=~/^\s*<\s*(\/\s*doc\s*|doc\s+[^>]+)>(.*)$/i){$line=$2;next;}
      if ($line=~/^(\s*<\s*\/\s*([^\s>]+)\s*>)(.*)$/)
      {
        my $tag=lc($2);
	my $nline=lc($1);$nline=~s/\s//g;
	$line=$3;
	if (exists $self->{tags}{$tag}{close})
	   {
	   if ($self->{tagdepth}>0)
	      {
	      if ($self->{xmlconvert} && ($ltag=~/^(bin|library)$/)){$self->_pop();}
	      if ($ltag ne $tag)
	         {
		 print STDERR "**** WARNING: Found closing tag \"$tag\" at line NO. $num of file \"$file\" while looking for \"$ltag\".\n";
		 push @{$self->{output}},$self->_adjust("</$ltag>",-1);
		 my $flag=0;
		 foreach my $t (@tags)
		    {
		    if ($t eq $tag){$flag=1;last;}
		    }
		 if ($flag){$line="${nline}${line}";next;}
		 }
	      else
	         {
		 push @{$self->{output}},$self->_adjust($nline,1);
		 }
		 if ($tag eq "export"){$self->{bfsection}="nonexport";}
		 $ltag = $self->lastTag(\@tags);
	      }
	   else
	      {
	      print STDERR "**** WARNING: Found closing tag \"$tag\" at line NO. $num without any opening tag for this in file \"$file\".\n";
	      }
	   }
	next;
      }
      if ($line=~/^(\s*<\s*([^\s>]+)\s*>)(.*)$/)
         {
	 my $tag=lc($2);
	 $line=lc($1); $line=~s/\s//g;
	 push @{$self->{output}},$self->_adjust($line);
	 push @tags,$tag;
	 $self->{tagdepth}=scalar(@tags);
	 $ltag=$tag;
	 if ($tag eq "export"){$self->{bfsection}="export";}
	 $line=$self->do_tag_processing_($tag,$3,\$num);
	 next;
	 }
      if ($line=~/^(\s*<\s*([^\s]+))(\s+.+)/)
         {
	 my $tag=lc($2);
	 if($tag eq "!--")
	   {
	   $line="";
	   next;
	   }
	 if ($self->{tagdepth}>0)
	    {
	    if ((($tag  eq "bin") || ($tag  eq "library")) &&
	        (($ltag eq "bin") || ($ltag eq "library")))
	       {
	       print STDERR "**** WARNING: Missing closing \"$ltag\" tag at line NO. $num of file \"$file\".\n";
	       push @{$self->{output}},$self->_adjust("</$ltag>",-1);
	       if ($self->{xmlconvert}){$self->_pop();}
	       $ltag = $self->lastTag(\@tags);
	       }
	    }
	 $line="<$tag $3";
	 while(($line!~/>/) && ($num<$count))
	    {
	    my $nline=$self->{input}[$num++];
	    if ($nline=~/^\s*</) {print STDERR "**** WARNING: Missing \">\" at line NO. ",$num-1," of file \"$file\".\n==>$line\n";$line.=">";}
	    $line.=$nline;
	    }
	 if ($line!~/>/){print STDERR "**** WARNING: Missing \">\" at line NO. $num of file \"$file\".\n==>$line\n";$line.=">";}
	 if ($self->{xmlconvert} && ($tag=~/^(bin|library)$/)){$self->_push();}
	 $line=$self->do_tag_processing_($tag,$line,\$num);
	 if (exists $self->{tags}{$tag}{close}){push @tags,$tag;$ltag=$tag;$self->{tagdepth}=scalar(@tags);}
	 next;
	 }
      elsif ($ltag=~/^(project|bin|library)$/)
         {
	 if ($line=~/^.*<\s*\/\s*$ltag\s*>(.*)/)
	    {
	    push @{$self->{output}},$self->_adjust("</$ltag>",-1);
	    if ($self->{xmlconvert}){$self->_pop();}
	    $line=$1;
	    $ltag = $self->lastTag(\@tags);
	    }
	 else{$line="";}
	 }
      else
         {
	 if (($line=~/^(\s*)((lib|use|flags|bin|library)\s*(name|file|[^=]+)\s*=.*)/i) ||
	     ($line=~/^(\s*)((export|client|environment)\s*>.*)/i))
	    {
	    print STDERR "**** WARNING: Missing \"<\" at line NO. $num of file \"$file\".\n==>$line\n";
	    $line="$1<$2";
	    next;
	    }
 	 else
	    {   
	    print STDERR "**** WARNING: Unknown line\n==>$line\nat line NO. $num of file \"$file\".\n";
	    $line="";
	    }
	 }
      }
   while(@tags>0)
      {
      my $t=pop @tags;
      $self->{tagdepth}--;
      print STDERR "**** WARNING: Missing closing tag \"$t\" in file \"$file\".\n";
      push @{$self->{output}},$self->_adjust("</$t>");
      }
   }
   
sub do_tag_processing_ ()
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   my $num=shift;
   my $func="process_${tag}_";
   if (exists $self->{tags}{$tag}{map}){$func="process_".$self->{tags}{$tag}{map}."_";}
   if (!exists &$func)
      {
      print STDERR "**** ERROR: Unable to process the \"$tag\" tag at line NO. ${$num} of file \"",$self->{filename},"\".\n";
      $line="";
      }
   else
      {
      $line=&$func($self,$tag,$line,$num);
      }
   return $line;
   }

sub getnextattrib_()
   {
   my $attr=shift;
   my $num=shift;
   my $self=shift;
   my $line=${$attr};
   my $ret="";
   if ($line=~/^\s*([^\s=]+)\s*=\s*(.*)/)
      {
      $ret="$1=";
      $line=$2;
      if ($line=~/^(["'])(.*)/)
         {
	 my $q=$1;
	 $line=$2;
	 if ($line=~/^(.*?$q)(.*)/)
	    {
	    $ret.="$q$1";
	    $line=$2;
	    }
	 else
	    {
	    print STDERR "**** WARNING: Missing ($q) at line NO. ${$num} of file \"",$self->{filename},"\".\n";
	    $ret.="$q$line$q";
	    $line="";
	    }
	 }
      elsif ($line=~/^([^\s]*)(\s*.*)/)
         {
	 $ret.="\"$1\"";
	 $line=$2;
	 }
      else{$ret.="\"$line\"";$line="";}
      }
   else
   {
     $line=~s/^\s*//;$line=~s/\s*$//;
     $ret="$line=\"\"";
     $line="";
   }
   ${$attr}=$line;
   return $ret;      
   }   
   
sub process_defaultprocessing_
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   my $num=shift;
   my $nline="";
   my $sec=$self->{bfsection};
   $line=~/^(\s*<\s*$tag\s+)([^>]+)>(.*)$/;
   $nline=$1;
   $line=$3;
   my $attrib=$2;
   if (($self->{xmlconvert}) && ($sec eq "export"))
   {
     if ($tag eq "use"){return $line;}
     elsif ($tag eq "lib")
     {
       my $lib=&_getname($attrib);
       if ((exists $self->{bfproduct}{$self->{filename}}) && ($self->{bfproduct}{$self->{filename}} eq "$lib"))
       {$attrib=~s/(name\s*=\s*.*)$lib/${1}1/;}
       elsif ($lib eq "1"){$attrib=~s/(name\s*=\s*.*)$lib/${1}1/;}
       else{return $line;}
     }
   }
   my $close=1;
   if(exists $self->{tags}{$tag}{close}){$close=0;}
   $attrib=~s/\s*$//;
   while($attrib!~/^\s*$/)
      {
      my $item=&getnextattrib_(\$attrib,$num,$self);
      my ($key,$value)=split /=/,$item,2;
      if ($value!~/^\"[^\"]*\"$/)
         {
	 if ($value=~/^\'([^\']*)\'$/)
	    {
	    $value=$1;
	    if ($value=~/^\s*\"([^\"]+)\"\s*$/){$value = "'$1'";}
	    }
	 $value = "\"$value\"";
	 }
      $nline.=" $key=$value";
      }
   if($close){$nline.="/>";}
   else{$nline.=">";}
   push @{$self->{output}},$self->_adjust($nline);
   return $line;
   }

sub process_defaultsimple_()
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   return $line;
   }
   
sub process_makefile_ ()
   {
   my $self=shift;
   my $tag=shift;
   my $line=shift;
   my $num=shift;
   my $count=$self->{count};
   while ($line || ((${$num}<$count) && (($line=$self->{input}[${$num}++]) || 1)))
      {
      if ($line=~/^<\s*\/\s*$tag\s*>\s*(.*)/)
         {
	 last;
	 }
      elsif ($line=~/^(.+?)(<\s*\/\s*$tag\s*>.*)/)
         {
	 my $l=$1;
	 $line=$2;
	 if($l!~/^\s*$/){push @{$self->{output}},"$l\n";}
	 last;
	 }
      else {push @{$self->{output}},"$line\n";$line="";}
      }
   return $line;
   }

sub _add ()
  {
  my $self=shift;
  my $val=shift || return 0;
  if ($self->_has($val)){return 0;}
  my $sec=$self->{bfsection};
  my $ind=scalar(@{$self->{sections}{$sec}})-1;
  if($ind>=0){$self->{sections}{$sec}[$ind]{$val}=1;return 1;}
  return 0;
  }
  
sub _has ()
  {
  my $self=shift;
  my $val=shift || return 0;
  my $sec=$self->{bfsection};
  my $ind=scalar(@{$self->{sections}{$sec}});
  for(my $i=0;$i<$ind;$i++)
     {
     if(exists $self->{sections}{$sec}[$i]{$val}){return 1;}
     }
  return 0;
  }
  
sub _push ()
  {
  my $self=shift;
  my $sec=shift;
  push @{$self->{sections}{nonexport}},{};
  }  

sub _pop ()
  {
  my $self=shift;
  my $sec=shift;
  pop @{$self->{sections}{nonexport}};
  }
  
sub _adjust ()
  {
  my $self=shift;
  my $line=shift;
  if ($self->{xmlconvert})
    {
    my $diff=shift || 0;
    my $c=$self->{tagdepth} || 0;$c-=$diff;
    for(my $i=0;$i<$c;$i++){$line="  $line";}
    }
  return $line;
  }

sub _getname ()
  {
  my $str=shift;
  $str=~s/.*\s*name\s*=\s*([^\s>]+).*$/$1/;
  $str=~s/\/$//;
  $str=~s/"//g;$str=~s/'//g;
  return $str;
  }
  
1;
