#
# ConfigArea.pm
#
# Written by Christopher Williams
#
# Description
# -----------
# creates and manages a configuration area
#
# Notes
# -------
# Persistency - remember to call the save method to make changes persistent
#
# Interface
# ---------
# new()				: A new ConfigArea object
# name()			: get/set project name
# setup(dir[,areaname])         : setup a fresh area in dir
# satellite(dir[,areaname])     : setup a satellite area in dir
# version()			: get/set project version
# location([dir])		: set/return the location of the work area
# bootstrapfromlocation([location]) : bootstrap the object based on location.
#				      no location specified - cwd used
#				      return 0 if succesful 1 otherwise
# requirementsdoc()		: get set the requirements doc
# searchlocation([startdir])	: returns the location directory. search starts
#				  from cwd if not specified
# scramversion()		: return the scram version associated with
#				  area
# configurationdir()		: return the location of the project 
#				  configuration directory
# copy(location)		: copy a configuration
# copysetup(location)		: copy the architecture specific tool setup
#				  returns 0 if successful, 1 otherwise
# copyenv($ref)			: copy the areas environment into the hashref
# toolbox()			: return the areas toolbox object
# save()			: save changes permanently
# linkto(location)		: link the current area to that at location
# unlinkarea()			: destroy link (autosave)
# linkarea([ConfigArea])	: link the current area to the apec Area Object
# archname()		: get/set a string to indicate architecture
# archdir()		: return the location of the administration arch dep 
#			  directory
# objectstore()		: return the objectStore object of the area
# - temporary
# align()			: adjust hard paths to suit local loaction

package Configuration::ConfigArea;
require 5.004;
use URL::URLcache;
use Utilities::AddDir;
use Utilities::Verbose;
use ObjectUtilities::ObjectStore;
use Cwd;
@ISA=qw(Utilities::Verbose);

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;

	# data init
        $self->{admindir}=".SCRAM";
        $self->{cachedir}="cache";
        $self->{dbdir}="ObjectDB";
	undef $self->{linkarea};

	return $self;
}

sub cache {
	my $self=shift;

	if ( @_ ) {
	   $self->{cache}=shift;
	}
	if ( ! defined $self->{cache} ) {
	  my $loc=$self->location()."/".$self->{admindir}."/".$self->{cachedir};
	  if ( -e $loc  ) {
	    $self->{cache}=URL::URLcache->new($loc);
	  }
	  else {
	    $self->{cache}=undef;
	  }
	}
	return $self->{cache};
}

sub _newcache {
	my $self=shift;
	my $loc=$self->location()."/".$self->{admindir}."/".$self->{cachedir};
	$self->{cache}=URL::URLcache->new($loc);
	return $self->{cache};
}

sub _newobjectstore {
	my $self=shift;
	my $loc=$self->location()."/".$self->{admindir}."/".$self->{dbdir};
	$self->{dbstore}=ObjectUtilities::ObjectStore->new($loc);
	return $self->{dbstore};
}

sub objectstore {
	my $self=shift;

	if ( @_ ) {
	    $self->{dbstore}=shift;
	}
	if ( ! defined $self->{dbstore} ) {
	  my $loc=$self->location()."/".$self->{admindir}."/".$self->{dbdir};
	  if ( -e $loc ) {
	    $self->{dbstore}=ObjectUtilities::ObjectStore->new($loc);
	  }
	  else {
	    $self->{dbstore}=undef;
	  }
	}
	return $self->{dbstore}
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
	my $areaname;

	# -- check we have a project name and version
	my $name=$self->name();
        my $vers=$self->version();
	if ( ( ! defined $name ) && ( ! defined $version )) {
	  $self->error("Set ConfigArea name and version before setup");
	}

	# -- check arguments and set location
	if ( ! defined $location ) {
	  $self->error("ConfigArea: Cannot setup new area without a location");
	}
	if ( @_ ) {
	  $areaname=shift;
	}
	if ( (! defined $areaname) || ( $areaname eq "" ) ) {
	  # -- make up a name from the project name and version
          $vers=~s/^$name\_//;
          $areaname=$name."_".$vers;
	}
	my $arealoc=$location."/".$areaname;
	my $workloc=$arealoc."/".$self->{admindir};
	$self->verbose("Building at $arealoc");
	$self->location($arealoc);

	# -- create top level structure and work area
	AddDir::adddir($workloc);

	# -- add a cache
	$self->_newcache();

	# -- add an Objectstore
	$self->_newobjectstore();

	# -- Save Environment File
	$self->_SaveEnvFile();

}

sub configurationdir {
	my $self=shift;
	if ( @_ ) {
	  $self->{configurationdir}=shift;
	}
	return (defined $self->{configurationdir})?$self->{configurationdir}:undef;
}

sub toolbox {
	my $self=shift;
	if ( ! defined $self->{toolbox} ) {
	  $self->{toolbox}=BuildSystem::ToolBox->new($self, $ENV{SCRAM_ARCH});
	}
	return $self->{toolbox};
}

sub requirementsdoc {
	my $self=shift;
	if ( @_ ) {
          $self->{reqdoc}=shift;
        }
	if ( defined $self->{reqdoc} ) {
	  return $self->location()."/".$self->{reqdoc};
	}
	else {
	  return undef;
	}
}

sub scramversion {
	my $self=shift;
	if ( ! defined $self->{scramversion} ) {
	  my $filename=$self->location()."/".$self->configurationdir()."/".
							"scram_version";
	  if ( -f $filename ) {
	    use FileHandle;
	    $fh=FileHandle->new();
	    open ($fh, "<".$filename);
            my $version=<$fh>;
            chomp $version;
	    $self->{scramversion}=$version;
	    undef $fh;
	  }
	}
	return $self->{scramversion};
}

sub bootstrapfromlocation {
	my $self=shift;

	my $rv=0;
	
	my $location;
	if ( ! defined ($location=$self->searchlocation(@_)) ) {
	 $rv=1;
	 $self->verbose("Unable to locate the top of local configuration area");
	}
	else {
	 $self->location($location);
	 $self->verbose("Found top ".$self->location());
	 my $infofile=$self->location()."/".$self->{admindir}."/ConfigArea.dat";
	 $self->_LoadEnvFile();
	}
	return $rv;
}

sub location {
	my $self=shift;

	if ( @_ ) {
	  $self->{location}=shift;
	}
	elsif ( ! defined $self->{location} ) {
	  # try and find the release location
	  $self->{location}=$self->searchlocation();
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
	  $self->{archname}=shift;
	}
	return $self->{archname};
}

sub archdir {
	my $self=shift;
	if ( @_ ) {
	  $self->{archdir}=shift;
	}
	if ( ! defined $self->{archdir} ) {
	 if ( defined $self->{archname} ) {
	  $self->{archdir}=$self->location()."/".$self->{admindir}."/".
							$self->{archname};
	 }
	 else {
	  $self->error("ConfigArea : cannot create arch directory - ".
						"architecture name not set")
	 }
	}
	return $self->{archdir};
}

sub satellite {
	my $self=shift;

	# -- create the sat object
	my $sat=Configuration::ConfigArea->new();
	$sat->name($self->name());
	$sat->version($self->version());
	$sat->requirementsdoc($self->{reqdoc});
	$sat->configurationdir($self->configurationdir());
	$sat->setup(@_);

	# -- copy across the cache and ObjectStore
	# -- make sure we dont try building new caches in release areas
	my $rcache=$self->cache();
	if ( defined $rcache ) {
	  copy($rcache->location(),$sat->cache()->location());
	}

	# -- make sure we dont try building new objectstores in release areas
	my $rostore=$self->objectstore();
	if ( defined $rostore ) {
	  copy($rostore->location(),$sat->objectstore()->location());
	}

	# and make sure in reinitialises
	undef ($sat->{cache});

	# -- link it to this area
	$sat->linkarea($self);
	
	# -- save it
	$sat->save();

	return $sat;
}

sub copy {
	my $self=shift;
	my $destination=shift;

	# copy across the admin dir
        my $temp=$self->location()."/".$self->{admindir};
	AddDir::copydir($temp,"$destination/".$self->{admindir});
}

sub align {
	my $self=shift;
	use File::Copy;

	$self->_LoadEnvFile();
	my $Envfile=$self->location()."/".$self->{admindir}."/Environment";
	my $tmpEnvfile=$Envfile.".bak";
	my $rel=$self->{ENV}{RELEASETOP};
	my $local=$self->location();

        rename( $Envfile, $tmpEnvfile );
        use FileHandle;
        my $fh=FileHandle->new();
        my $fout=FileHandle->new();
        open ( $fh, "<".$tmpEnvfile ) or
                $self->error("Cannot find Environment file. Area Corrupted? ("
                                .$self->location().")\n $!");
        open ( $fout, ">".$Envfile ) or
                $self->error("Cannot find Environment file. Area Corrupted? ("
                                .$self->location().")\n $!");
        while ( <$fh> ) {
	  $_=~s/\Q$rel\L/$local/g;
	  print $fout $_;
	}
	undef $fh;
	undef $fout;
}

sub copysetup {
	my $self=shift;
	my $dest=shift;

	my $rv=1;
	# copy across the admin dir
        my $temp=$self->location()."/".$self->{admindir}."/".$self->arch();
	my $temp2=$dest."/".$self->{admindir}."/".$self->arch();
	if ( $temp ne $temp2 ) {
	 if ( -d $temp ) {
          AddDir::copydir($temp,$temp2);
	  $rv=0;
	 }
	}
	return $rv;
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
	return $ENV{SCRAM_ARCH};
}

sub linkto {
	my $self=shift;
	my $location=shift;
	if ( -d $location ) {
	my $area=Configuration::ConfigArea->new();
	$area->bootstrapfromlocation($location);
	$self->linkarea($area);
	}
	else {
	  $self->error("ConfigArea : Unable to link to non existing directory ".
			 $location);
	}
}

sub unlinkarea {
	my $self=shift;
	undef $self->{linkarea};
	$self->{linkarea}=undef;
	$self->save();
}

sub linkarea {
	my $self=shift;
	my $area=shift;
	if ( defined $area ) {
	  $self->{linkarea}=$area;
	}
	return (defined $self->{linkarea} && $self->{linkarea} ne "")?
			$self->{linkarea}:undef;
}

sub save {
	my $self=shift;
	$self->_SaveEnvFile();
}

# ---- support routines

sub _SaveEnvFile {
	my $self=shift;
	use FileHandle;
	my $fh=FileHandle->new();
	open ( $fh, ">".$self->location()."/".$self->{admindir}."/".
		"Environment" ) or 
		$self->error("Cannot Open Environment file to Save ("
				.$self->location().")\n $!"); 
	
	print $fh "SCRAM_PROJECTNAME=".$self->name()."\n";
	print $fh "SCRAM_PROJECTVERSION=".$self->version()."\n";
	print $fh "projconfigdir=".$self->configurationdir()."\n";
	print $fh "SCRAM_ProjReqsDoc=".$self->{reqdoc}."\n";
	if ( defined $self->linkarea() ) {
	  my $area=$self->linkarea()->location();
	  if ( $area ne "" ) {
	  print $fh "RELEASETOP=".$area."\n";
	  }
	}
	undef $fh;
}


sub _LoadEnvFile {
	my $self=shift;

	use FileHandle;
	my $fh=FileHandle->new();
	open ( $fh, "<".$self->location()."/".$self->{admindir}."/".
		"Environment" ) or 
		$self->error("Cannot find Environment file. Area Corrupted? ("
				.$self->location().")\n $!"); 
        while ( <$fh> ) {
           chomp;
           next if /^#/;
           next if /^\s*$/ ;
           ($name, $value)=split /=/;
           eval "\$self->{ENV}{${name}}=\"$value\"";
        }
        undef $fh;
	
	# -- set internal variables appropriately
	if ( defined $self->{ENV}{"SCRAM_PROJECTNAME"} ) {
	  $self->name($self->{ENV}{"SCRAM_PROJECTNAME"});
	}
	if ( defined $self->{ENV}{"SCRAM_PROJECTVERSION"} ) {
	  $self->version($self->{ENV}{"SCRAM_PROJECTVERSION"});
	}
	if ( defined $self->{ENV}{"projconfigdir"} ) {
	  $self->configurationdir($self->{ENV}{projconfigdir});
	}
	if ( defined $self->{ENV}{"SCRAM_ProjReqsDoc"} ) {
          $self->requirementsdoc($self->{ENV}{SCRAM_ProjReqsDoc});
	}
	if ( ( defined $self->{ENV}{"RELEASETOP"} ) && 
			($self->{ENV}{"RELEASETOP"} ne $self->location())) {
	  $self->linkto($self->{ENV}{"RELEASETOP"});
	}
	else {
	  $self->{ENV}{"RELEASETOP"}=$self->location();
	}
}
