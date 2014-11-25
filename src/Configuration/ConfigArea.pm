package Configuration::ConfigArea;
require 5.004;
use Utilities::AddDir;
use Utilities::Verbose;
use Cwd;
@ISA=qw(Utilities::Verbose);

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;
	$self->{admindir}=".SCRAM";
	$self->{configurationdir} = "config";
	$self->{forcearch} = shift || "";
	$self->{arch} = $self->{forcearch} || $ENV{SCRAM_ARCH};
	return $self;
}

sub toolcachename
   {
   my $self=shift;
   return ($self->archdir()."/ToolCache.db.gz");
   }

sub projectcachename
   {
   my $self=shift;
   return ($self->archdir()."/ProjectCache.db.gz");
   }

sub symlinks {
	my $self=shift;
	if (@_) {$self->{symlinks}=shift;}
	return $self->{symlinks};
}

sub calchksum {
        my $self=shift;
	my $dir=$self->location()."/".$self->configurationdir();
	my $sum="";
	if (-f "${dir}/config_tag")
	   {
	   my $ref;
	   open ($ref, "${dir}/config_tag");
	   $sum=<$ref>;
	   close($ref);
           chomp $sum;
	   }
	else
	   {
	   push @INC,$dir;
	   require SCRAM::Plugins::ProjectChkSum;
	   $sum=&SCRAM::Plugins::ProjectChkSum::chksum($dir);
	   pop @INC;
	   }
	return $sum;
}

sub configchksum {
	my $self=shift;
	if (@_) {$self->{configchksum}=shift;}
	return $self->{configchksum};
}


sub name {
	my $self=shift;
	@_?$self->{name}=shift
	  :$self->{name};
}

sub version {
	my $self=shift;
	@_?$self->{version}=shift
	  :$self->{version};
}

sub setup {
	my $self=shift;
	my $location=shift;
	my $areaname=shift  || undef;
	my $symlinks=shift  || 0;
	my $locarea = shift || undef;
	if ( (! defined $areaname) || ( $areaname eq "" ) ) {
          $areaname=$self->version();
	}
	$self->location($location."/".$areaname);
	$self->symlinks($symlinks);
	if ($self->configchksum() ne "")
	   {
	   if ((!-defined $locarea) && (-f "${location}/${areaname}/".$self->admindir()."/Environment"))
	      {
	      $locarea=Configuration::ConfigArea->new();
	      $locarea->bootstrapfromlocation("${location}/${areaname}");
	      }
	   if ((defined $locarea) && ($locarea->configchksum() != $self->configchksum()))
	      {
	      print "ERROR: Can not setup your current working area for SCRAM_ARCH: $ENV{SCRAM_ARCH}\n",
	            "Your current development area ${location}/${areaname}\n",
	            "is using a different ${areaname}/config then the one used for\n",
		    $self->releasetop(),".\n";
	      exit 1;
	      }
	   }
	Utilities::AddDir::adddir($self->archdir());
}

sub configurationdir {
	my $self=shift;
	if ( @_ ) {
	  $self->{configurationdir}=shift;
	}
	return (defined $self->{configurationdir})?$self->{configurationdir}:undef;
}

sub sourcedir {
	my $self=shift;
	if ( @_ ) {
	  $self->{sourcedir}=shift;
	}
	return (defined $self->{sourcedir})?$self->{sourcedir}:undef;
}

sub releasetop {
	my $self=shift;
	if ( @_ ) {
	  $self->{releasetop}=shift;
	}
	return (defined $self->{releasetop})?$self->{releasetop}:undef;
}

sub admindir()
   {
   my $self=shift;
   
   @_ ? $self->{admindir} = shift
      : $self->{admindir};
   }

sub bootstrapfromlocation {
	my $self=shift;
	my $location = $self->searchlocation(shift);
	my $rv=0;
	if ( ! defined $location) {
	 $rv=1;
	}
	else {
	 $self->location($location);
	 $self->_LoadEnvFile();
	}
	return $rv;
}

sub location {
	my $self=shift;

	if ( @_ ) {
	  $self->{location}=shift;
	  delete $self->{archs};
	  $self->_setAreaArch();
	}
	elsif ( ! defined $self->{location} ) {
	  # try and find the release location
	  $self->{location}=$self->searchlocation();
	  if (defined $self->{location})
	     {
	     $self->_setAreaArch()
	     }
	}
	return  $self->{location};
}

sub searchlocation {
	my $self=shift;
	
        #start search in current directory if not specified
	my $thispath;
	if ( @_ ) {
	  $thispath=shift
	}
	else {
	  $thispath=cwd();
	}
	
        my $rv=0;

	# chop off any files - we only want dirs
	if ( -f $thispath ) {
	  $thispath=~s/(.*)\/.*/$1/;
	}
        Sloop:{
	do {
	  $self->verbose("Searching $thispath");
          if ( -e "$thispath/".$self->{admindir} ) {
	    $self->verbose("Found\n");
	    $rv=1;
	    last Sloop;
	  }
        } while ( ($thispath=~s/(.*)\/.*/$1/)=~/./ ) };
       
        return $rv?$thispath:undef;
}

sub archname {
	my $self=shift;
	if ( @_ ) {
	  $self->{arch} = shift;
	  if (defined $self->{location}) {
	     $self->archdir($self->{location}."/".$self->{admindir}."/".$self->{arch});
	  }
	}
	return $self->{arch};
}

sub archdir {
	my $self=shift;
	if ( @_ ) {
	  $self->{archdir}=shift;
	}
	return $self->{archdir};
}

sub satellite {
	my $self=shift;
	my $relloc = $self->location();
	my $sat=Configuration::ConfigArea->new($ENV{SCRAM_ARCH});
	$sat->name($self->name());
	$sat->version($self->version());
	$sat->configurationdir($self->configurationdir());
	$sat->sourcedir($self->sourcedir());
	$sat->releasetop($relloc);
	$sat->configchksum($self->configchksum());
	$sat->setup(@_);
	my $devconf = $sat->location()."/".$sat->configurationdir();
	my $relconf = $self->location()."/".$self->configurationdir();
	if (!-d $devconf)
	   {
	   Utilities::AddDir::copydir($relconf,$devconf);
	   }
	else {
	   Utilities::AddDir::adddir("${devconf}/toolbox");
	   Utilities::AddDir::copydir("${relconf}/toolbox/".$self->{arch},"${devconf}/toolbox/");
	   }
	Utilities::AddDir::adddir ($sat->location()."/".$sat->sourcedir());
	Utilities::AddDir::copyfile($self->archdir()."/ToolCache.db.gz", $sat->archdir()."/");
	Utilities::AddDir::copydir($self->archdir()."/timestamps", $sat->archdir()."/");
	my $envfile = $sat->archdir()."/Environment";
	open ( $fh, "> $envfile" ) or  $sat->error("Cannot Open \"$envfile\" file to Save\n $!"); 
	print $fh "RELEASETOP=$relloc\n";
	close($fh);
	my $chkarch = $sat->archdir()."/chkarch";
	open ( $fh, "> $chkarch" ) or  $sat->error("Cannot Open \"$chkarch\" file to Save\n $!");
	close($fh);
	$envfile = $sat->location()."/".$self->{admindir}."/Environment";
	if (! -f $envfile)
	   {
	   $sat->save ();
	   }
	return $sat;
}

sub copyenv {
	my $self=shift;
	my $hashref=shift;
	
	foreach $elem ( keys %{$self->{ENV}} ) {
	   $$hashref{$elem}=$self->{ENV}{$elem};
	}
}

sub arch {
	my $self=shift;
	return $self->{arch};
}

sub save {
	my $self=shift;
	$self->_SaveEnvFile();
}

# ---- support routines

sub _setAreaArch {
  my ($self) = @_;
  my $arch = $self->{forcearch};
  if ($arch eq "")
  {
    if (!exists $self->{archs})
    {
      $self->{archs}=[];
      foreach my $arch (glob($self->{location}.'/'.$self->{configurationdir}.'/toolbox/*')) {
        if (-d "${arch}/tools") {
	  $arch=~s/^.*\/([^\/]+)$/$1/o;
	  push @{$self->{archs}},$arch;
        }
      }
    }
    if ((!-d "${toolbox}/".$self->{arch}) && (scalar(@{$self->{archs}})==1)) { $arch = $self->{archs}[0]; }
  }
  $self->archname($arch || $self->{arch});
  return;
}

sub _SaveEnvFile
   {
   my $self=shift;
   
   my $fh;
   my $envfile = $self->location()."/".$self->{admindir}."/Environment";
   open ( $fh, "> $envfile" ) or  $self->error("Cannot Open \"$envfile\" file to Save\n $!");
	
   print $fh "SCRAM_PROJECTNAME=".$self->name()."\n";
   print $fh "SCRAM_PROJECTVERSION=".$self->version()."\n";
   print $fh "SCRAM_CONFIGDIR=".$self->configurationdir()."\n";
   print $fh "SCRAM_SOURCEDIR=".$self->sourcedir()."\n";
   print $fh "SCRAM_SYMLINKS=",$self->symlinks(),"\n";
   print $fh "SCRAM_CONFIGCHKSUM=",$self->configchksum(),"\n";
   close($fh);

   # Set the default permissions (-rw-r--r--):
   my $filemode = 0644;
   chmod $filemode, $self->location()."/".$self->{admindir}."/Environment";
   }

sub _LoadEnvFile
   {
   my $self=shift;

   my $fh;
   my $envfile = $self->location()."/".$self->{admindir}."/Environment";
   open ( $fh, "< $envfile" ) or $self->error("Cannot open \"$envfile\" file for reading.\n $!");
   while ( <$fh> )
      {
      chomp;
      next if /^#/;
      next if /^\s*$/ ;
      ($name, $value)=split /=/;
      eval "\$self->{ENV}{${name}}=\"$value\"";
      }
   close($fh);
   $envfile = $self->archdir()."/Environment";
   if (-f $envfile)
      {
      open ( $fh, "< $envfile" ) or $self->error("Cannot open \"$envfile\" file for reading.\n $!");
      while ( <$fh> )
         {
         chomp;
         next if /^#/;
         next if /^\s*$/ ;
         ($name, $value)=split /=/;
         eval "\$self->{ENV}{${name}}=\"$value\"";
         }
      close($fh);
      }
	
   # -- set internal variables appropriately
   if ( defined $self->{ENV}{"SCRAM_PROJECTNAME"} )
      {
      $self->name($self->{ENV}{"SCRAM_PROJECTNAME"});
      }
   if ( defined $self->{ENV}{"SCRAM_SYMLINKS"} )
      {
      $self->symlinks($self->{ENV}{"SCRAM_SYMLINKS"});
      }
   if ( defined $self->{ENV}{"SCRAM_CONFIGCHKSUM"} )
      {
      $self->configchksum($self->{ENV}{"SCRAM_CONFIGCHKSUM"});
      }
   if ( defined $self->{ENV}{"SCRAM_PROJECTVERSION"} )
      {
      $self->version($self->{ENV}{"SCRAM_PROJECTVERSION"});
      }	
   if ( defined $self->{ENV}{"SCRAM_CONFIGDIR"} )
      {
      $self->configurationdir($self->{ENV}{"SCRAM_CONFIGDIR"});
      }
   if ( defined $self->{ENV}{"SCRAM_SOURCEDIR"} )
      {
      $self->sourcedir($self->{ENV}{"SCRAM_SOURCEDIR"});
      }
   if ( defined $self->{ENV}{"RELEASETOP"} )
      {
      $self->releasetop($self->{ENV}{"RELEASETOP"});
      }
   }
1;
