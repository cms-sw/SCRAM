#
# ConfigArea.pm
#
# Originally Written by Christopher Williams
#
# Description
# -----------
# creates and manages a configuration area
#
# Options
# -------
# ConfigArea_location
# ConfigArea_name
#
# Interface
# ---------
# new(ActiveConfig)		: A new ConfigArea object
# setup()		        : setup the configuration area
# location([dir])		: set/return the location of the area
# version([version])		: set/return the version of the area
# name([name])			: set/return the name of the area
# store(location)		: store data in file location
# restore(location)		: restore data from file location
# meta()			: return a description string of the area
# addconfigitem(url)		: add a new item to the area
# configitem(@keys)		: return a list of fig items that match
#				  the keys - all if left blank
# parentstore()			: set/return the parent ObjectStore
# basearea(ConfigArea)		: Set/Get the base area
# freebase()			: Remove any link to a base area
# bootstrapfromlocation([location]): bootstrap the object based on location.
#				  no location specified - cwd used
# searchlocation([startdir])	: returns the location directory. search starts
#				  from cwd if not specified
# defaultdirname()		: return the default directory name string
# copy(location)		: make a copy of the current area at the 
#				  specified location - defaults to cwd/default
#				  if not specified . ConfigArea_name, 
#				  ConfigArea_location also override .
#				  Return an object representing the area
# satellite()			: make a satellite area based on $self
# arch([archobj])		: Set/get the architecture object
# structure(name)		: return the object corresponding to the
#				  structure name
# structurelist()		: return list of structure objectS
# downloadtotop(dir,url)	: download the url to a dir in the config area
#				  

package Configuration::ConfigArea;
use ActiveDoc::ActiveDoc;
require 5.004;
use Utilities::AddDir;
use ObjectUtilities::ObjectStore;
use Configuration::ConfigStore;
use Configuration::ActiveDoc_arch;
use Cwd;
@ISA=qw(Configuration::ActiveDoc_arch ObjectUtilities::StorableObject);

sub init {
	my $self=shift;

	$self->newparse("init");
	$self->newparse("download");
	$self->newparse("setup");
	$self->addtag("init","project",\&Project_Start,$self,
	    \&Project_text,$self,"", $self );
	$self->addurltags("download");
	$self->addtag("download","download",\&Download_Start,$self, 
						"", $self, "",$self);
	$self->addtag("download","use",\&Use_download_Start,$self, 
						"", $self, "",$self);
	$self->addurltags("setup");
	$self->addtag("setup","use",\&Use_Start,$self, "", $self, "",$self);
	$self->addtag("setup","structure",\&Structure_Start,$self,
			 "", $self, "",$self);

	# data init
	$self->{admindir}=".SCRAM";
}

sub basearea {
	my $self=shift;

	my $area;
	if ( @_ ) {
	  $area=shift;
	  $self->config()->store($area,"BaseArea");
	}
	else {
	  ($area)=$self->config()->restore("BaseArea");
	}
	return $area;
}

sub freebase {
	my $self=shift;
	$self->config()->delete("BaseArea");
}

sub defaultdirname {
	my $self=shift;
        my $name=$self->name();
        my $vers=$self->version();
        $vers=~s/^$name\_//;
        $name=$name."_".$vers;
        return $name;
}


sub setup {
	my $self=shift;

	# --- find out the location - default is cwd
	my $location=$self->option("ConfigArea_location");
	if ( ! defined $location ) {
	        $location=cwd();
	}
	elsif ( $location!~/^\// ) {
		$location=cwd()."/".$location;
	}

	# --- find area directory name , default name projectname_version
	my $name=$self->option("ConfigArea_name");
	if ( ! defined $name ) {
	  $name=$self->defaultdirname();
	}
	$self->location($location."/".$name);

	# make a new store handler
	$self->_setupstore();

	# --- download everything first
	$self->parse("download");
	
	# --- and parse the setup file
	$self->parse("setup");
	
	# --- store bootstrap info 
	$self->store($self->location()."/".$self->{admindir}."/ConfigArea.dat");

	# --- store self in original database
	$self->parentconfig()->store($self,"ConfigArea",$self->name(),
							$self->version());
}

sub structure {
	my $self=shift;
	my $vr=shift;
	return $self->{structures}{$vr};
}

sub structurelist {
	my $self=shift;
	return ( keys %{$self->{structures}} );
}

sub _setupstore {
	my $self=shift;

	# --- make a new ConfigStore at the location and add it to the db list
	my $ad=Configuration::ConfigStore->new($self->location().
				"/".$self->{admindir}, $self->arch());

	$self->parentconfig($self->config());
#        $self->config(Configuration::ConfigureStore->new());
#        $self->config()->db("local",$ad);
#        $self->config()->db("parent",$self->parentconfig());
#        $self->config()->policy("cache","local");
	$self->config($ad);
        $self->config()->basedoc($self->parentconfig()->basedoc());
}

sub bootstrapfromlocation {
	my $self=shift;
	
	if ( ! defined $self->location(@_) ) {
	  $self->error("Unable to locate the top of local configuration area");
	}
	print "Found top ".$self->location()."\n";
	$self->_setupstore();
	$self->restore($self->location()."/".$self->{admindir}.
						"/ConfigArea.dat");
}

sub parentconfig {
	my $self=shift;
	@_?$self->{parentconfig}=shift
	  :$self->{parentconfig};
}

sub store {
	my $self=shift;
	my $location=shift;

	my $fh=$self->openfile(">".$location);
	$self->savevar($fh,"location", $self->location());
	$self->savevar($fh,"url", $self->url());
	$self->savevar($fh,"name", $self->name());
	$self->savevar($fh,"version", $self->version());
	$fh->close();

	$self->_storestructures();
}

sub satellite {
	my $self=shift;
	my $newarea=$self->copy(@_);
	$newarea->_makesatellites();
	return $newarea;
}

sub copy {
	my $self=shift;
	use File::Basename;
	# create the area

	my $destination;
	if ( @_ ) {
	 $destination=shift;
	}
	else {
	  my($location,$name)=$self->_defaultoptions();
	  $destination=$location."/".$name
	}
	#AddDir::adddir(dirname($destination)."/".$self->{admindir});
	#AddDir::adddir($destination."/".$self->{admindir});
	
	# copy across the admin dir
	$temp=$self->location()."/".$self->{admindir};
	AddDir::copydir($temp,"$destination/".$self->{admindir});
	# create a new object based on the new area
	my $newarea=ref($self)->new($self->parentconfig());
	$newarea->bootstrapfromlocation($destination);
	# save it with the new location info
	$newarea->store($self->location()."/".$self->{admindir}.
							"/ConfigArea.dat");
	return $newarea;
}

sub restore {
	my $self=shift;
	my $location=shift;

	my $fh=$self->openfile("<".$location);
	my $varhash={};
	$self->restorevars($fh,$varhash);
	if ( ! defined $self->location() ) {
          $self->location($$varhash{"location"});
	}
	$self->_setupstore();
        $self->url($$varhash{"url"});
        $self->name($$varhash{"name"});
        $self->version($$varhash{"version"});
        $fh->close();

	$self->_restorestructures();
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
	@_?$thispath=shift
	  :$thispath=cwd();
 
        my $rv=0;

        Sloop:{
	do {
#	  print "Searching $thispath\n";
          if ( -e "$thispath/".$self->{admindir} ) {
#	    print "Found\n";
	    $rv=1;
	    last Sloop;
	  }
        } while ( ($thispath=~s/(.*)\/.*/$1/)=~/./ ) };

        return $rv?$thispath:undef;
}

sub meta {
	my $self=shift;

	my $string=$self->name()." ".$self->version()." located at :\n  ".
		$self->location;
}

sub configitem {
	my $self=shift;
	
	return ($self->config()->find("ConfigItem",@_));
}

sub addconfigitem {
	my $self=shift;
	my $url=shift;

	my $docref=$self->activatedoc($url);
        # Set up the document
        $docref->setup();
        $docref->save();
#	$self->config()->storepolicy("local");
}

sub downloadtotop {
	my $self=shift;
	my $url=shift;
	my $dir=shift;
	
	# only download once
	if ( ! -e $self->location()."/".$dir ) { 
	  $self->{urlhandler}->download($url,$self->location()."/".$dir);
	}
}

sub _makesatellites {
	my $self=shift;
	foreach $st ( values %{$self->{structures}} ) {
	   $st->setupsatellite()
	}
}

sub _storestructures {
	my $self=shift;
	foreach $struct ( values %{$self->{structures}} ) {
	  $self->config()->store($struct, "Structures", $struct->name());
	}
}

sub _restorestructures {
	my $self=shift;
	my @strs=$self->config()->find("Structures");
	foreach $struct ( @strs ) {
	  $struct->parent($self);
	  $self->{structures}{$struct->name()}=$struct;
	}
}

sub _defaultoptions {
	my $self=shift;
	my $name;
	my $location;

	# --- find out the location - default is cwd
        $location=$self->option("ConfigArea_location");
        if ( ! defined $location ) {
                $location=cwd();
        }
        elsif ( $location!~/^\// ) {
                $location=cwd()."/".$location;
        }

        # --- find area directory name , default name projectname_version
        $name=$self->option("ConfigArea_name");
        if ( ! defined $name ) {
          $name=$self->defaultdirname();
        }
	return ($location,$name);
}
# -------------- Tags ---------------------------------
# -- init parse
sub Project_Start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->checktag($name,$hashref,'name');
	$self->checktag($name,$hashref,'version');

	$self->name($$hashref{'name'});
	$self->version($$hashref{'version'});
}


sub Project_text {
	my $self=shift;
	my $name=shift;
        my $string=shift;

	print $string;
}

# ---- download parse

sub Download_Start {
	my $self=shift;
        my $name=shift;
        my $hashref=shift;

	$self->checktag($name,$hashref,'url');
	$self->checktag($name,$hashref,'location');
	if ( $$hashref{'location'}!~/^\w/ ) {
	  $self->parseerror("location must start with an".
		" alphanumeric character");
	}
	print "Downloading .... ".$$hashref{'url'}."\n";
	$self->downloadtotop($$hashref{'url'},$$hashref{'location'});
}

sub Use_download_Start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;

	$self->checktag($name,$hashref,'url');
	print "Downloading .... ".$$hashref{'url'}."\n";
	$self->getfile($$hashref{'url'});
}

# --- setup parse

sub Structure_Start {
	my $self=shift;
        my $name=shift;
        my $hashref=shift;

	$self->checktag($name,$hashref,'name');
	if ( !( exists $$hashref{'type'}) || ( exists $$hashref{'url'}) ) {
	    $self->parseerror("No url or type given in <$name> tag");
	}
	if ( ! exists $self->{structures}{$$hashref{'name'}} ) {
	  if ( exists $$hashref{'type'}) {
	    # create a new object of the specified type
	    eval "require $$hashref{'type'} ";
	    if  ( $@ ) {
		$self->parseerror("Unable to instantiate type=".
			$$hashref{'type'}." in <$name> .".$@);
	    }
	    $self->{structures}{$$hashref{'name'}}=
		$$hashref{'type'}->new($self->config());
	    $self->{structures}{$$hashref{'name'}}->name($$hashref{'name'});
	    $self->{structures}{$$hashref{'name'}}->parent($self);
	    $self->{structures}{$$hashref{'name'}}->vars($hashref);
	  }
	  else { # its an activedoc
		$self->{structures}{$$hashref{'name'}}=
				$self->activatedoc($$hashref{'url'});
	  }
	  $self->{structures}{$$hashref{'name'}}->setupbase();
	}
	else {
	     $self->parseerror("Multiply defined Structure - ".
							$$hashref{'name'});
	}
}

sub Use_Start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;
	
	$self->checktag($name,$hashref,'url');
	$self->addconfigitem($$hashref{'url'});
}

