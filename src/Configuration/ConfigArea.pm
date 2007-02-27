=head1 NAME

Configuration::ConfigArea - Creates and manages a configuration area (i.e. a project area).

=head1 SYNOPSIS

	my $obj = Configuration::ConfigArea->new();

=head1 DESCRIPTION

Create and manage SCRAM project configuration areas.

=head1 METHODS

=over

=cut

=item C<new()>

Create a new Configuration::ConfigArea object.

=item C<name()>

Get/set project name.

=item C<setup($dir[,$areaname])>

Set up a fresh area in $dir.

=item C<satellite($dir[,$areaname])>

Set up a satellite area in $dir.

=item C<version()>

Get/set project version.

=item C<location([$dir])>

Set/return the location of the work area.

=item C<bootstrapfromlocation([$location])>

Bootstrap the object based on location.
No location specified - current directory used
Return 0 if succesful, 1 otherwise.

=item C<requirementsdoc()>

Get or set the requirements document.

=item C<searchlocation([$startdir])>

Returns the location directory. search starts
from current directory if not specified.

=item C<scramversion()>

Return the scram version associated with the area.

=item C<configurationdir()>

Return the location of the project configuration directory.

=item C<copy($location)>

Copy a configuration from $location.

=item C<copysetup($location)>

Copy the architecture-specific tool setup.
Returns 0 if successful, 1 otherwise.

=item C<copyenv($ref)>

Copy the area environment into the hashref $ref.

=item C<toolbox()>

Return the area toolbox object.

=item C<save()>

Save changes permanently.

=item C<linkto($location)>

Link the current area to that at location.

=item C<unlinkarea()>

Destroy link ($autosave).

=item C<linkarea([Configuration::ConfigArea])>

Link the current area to the specified area object.

=item C<archname()>

Get/set a string to indicate architecture.

=item C<archdir()>

Return the location of the administration
architecture-dependent directory.

=item C<objectstore()>

Return the B<objectStore> object of the area temporary.

=item C<align()>

Adjust hard paths to suit local location.


=back

=head1 AUTHOR

Originally written by Christopher Williams.
   
=head1 MAINTAINER

Shaun ASHBY

=cut

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
    $self->{tbupdate}=0;
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

# Tool and project cache info:
sub cacheinfo
   {
   my $self=shift;
   print "\n","<ConfigArea> cacheinfo: ToolCache = ",$self->{toolcachefile},
   ", ProjectCache = ",$self->{projectcachefile},"\n";
   }

sub toolcachename
   {
   my $self=shift;
   return ($self->location()."/".$self->{admindir}."/".$ENV{SCRAM_ARCH}."/ToolCache.db");
   }

sub projectcachename
   {
   my $self=shift;
   return ($self->location()."/".$self->{admindir}."/".$ENV{SCRAM_ARCH}."/ProjectCache.db");
   }

sub _tbupdate
   {
   # Update toolbox relative to new RequirementsDoc:
   my $self=shift;
   @_?$self->{tbupdate}=shift
      :$self->{tbupdate};
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

sub sourcedir {
	my $self=shift;
	if ( @_ ) {
	  $self->{sourcedir}=shift;
	}
	return (defined $self->{sourcedir})?$self->{sourcedir}:undef;
}

sub toolbox {
	my $self=shift;
	if ( ! defined $self->{toolbox} ) {
	  $self->{toolbox}=BuildSystem::ToolBox->new($self, $ENV{SCRAM_ARCH});
	}
	return $self->{toolbox};
}

sub toolboxversion {
	my $self=shift;
	if ( @_ ) {
	  $self->{toolboxversion}=shift;
	}
	return (defined $self->{toolboxversion})?$self->{toolboxversion}:undef;
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

sub sitename
   {
   ###############################################################
   # sitename()                                                  #
   ###############################################################
   # modified : Mon Dec  3 15:45:35 2001 / SFA                   #
   # params   :                                                  #
   #          :                                                  #
   #          :                                                  #
   #          :                                                  #
   # function : Read the site name from config/site/sitename and #
   #          : export it.                                       #
   #          :                                                  #
   #          :                                                  #
   ###############################################################
   my $self = shift;
   my $sitefile = $self->location()."/".$self->configurationdir()."/site/sitename";

   $self->{sitename} = 'CERN'; # Use CERN as the default site name

   use FileHandle;
   my $sitefh = FileHandle->new();

   # Be verbose and print file we're going to read:
   $self->verbose(">> Going to try to get sitename from: ".$sitefile." ");
   
   # See if we can read from the file. If not, just
   # use default site name:
   open($sitefh,"<".$sitefile) || 
      do
	 {
	 $self->verbose(">> Unable to read a site name definition file. Using \'CERN\' as the site name.");
	 return $self->{sitename};
	 };
   
   $sitename = <$sitefh>;
   chomp($sitename);
   $self->{sitename} = $sitename;
   
   # Close the file (be tidy!);
   close($sitefile);
   # Return:
   return $self->{sitename};
   }

sub admindir()
   {
   my $self=shift;
   
   @_ ? $self->{admindir} = shift
      : $self->{admindir};
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
	$sat->sourcedir($self->sourcedir());
	$sat->toolboxversion($self->toolboxversion());
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

sub copyurlcache {
	my $self=shift;
	my $dest=shift;	
	my $rv=1;
	# copy across the admin dir
        my $temp=$self->location()."/".$self->{admindir}."/cache";
	my $temp2=$dest."/".$self->{admindir}."/cache";
	if ( $temp ne $temp2 ) {
	 if ( -d $temp ) {
          AddDir::copydir($temp,$temp2);
	  $rv=0;
	 }
	}
	return $rv;
}

sub copywithskip {
	my $self=shift;
	my $dest=shift;
	my ($filetoskip)=@_;       	
	my $rv=1;
	# copy across the admin dir
        my $temp=$self->location()."/".$self->{admindir}."/".$self->arch();
	my $temp2=$dest."/".$self->{admindir}."/".$self->arch();
	if ( $temp ne $temp2 ) {
	 if ( -d $temp ) {
          AddDir::copydirwithskip($temp,$temp2,$filetoskip);
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

sub reqdoc()
   {
   my $self=shift;
   my ($path)=@_;
   return $path."/".$self->{reqdoc};
   }

sub creationtime()
   {
   my $self=shift;
   my ($location)= @_;
   $location||=$self->location();
   my $requirementsdoc = $self->reqdoc($location);
   my ($mode, $time) = (stat($requirementsdoc))[2, 9];
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);

   ($sec < 10) ? ($sec = "0".$sec) : $sec;
   ($min < 10) ? ($min = "0".$min) : $min;

   $year += 1900;
   my $months =
      {
      0 => "Jan", 1 => "Feb",
      2 => "Mar", 3 => "Apr",
      4 => "May", 5 => "Jun",
      6 => "Jul", 7 => "Aug",
      8 => "Sept", 9 => "Oct",
      10 => "Nov", 11 => "Dec" };
   
   my $days = { 1 => "Mon", 2 => "Tue", 3 => "Wed", 4 => "Thu", 5 => "Fri", 6 => "Sat", 7 => "Sun"};
   
   # Return the timestamp (as string) of the requirementsdoc:
   return $days->{$wday}."-".$mday."-".$months->{$mon}."-".$year." ".$hour.":".$min.":".$sec;
   }

# ---- support routines

sub _SaveEnvFile
   {
   my $self=shift;
   my $filemode = 0644;
   
   use FileHandle;
   my $fh=FileHandle->new();
   open ( $fh, ">".$self->location()."/".$self->{admindir}."/".
	  "Environment" ) or 
	  $self->error("Cannot Open Environment file to Save ("
		       .$self->location().")\n $!"); 
	
   print $fh "SCRAM_PROJECTNAME=".$self->name()."\n";
   print $fh "SCRAM_PROJECTVERSION=".$self->version()."\n";
   print $fh "SCRAM_CONFIGDIR=".$self->configurationdir()."\n";
   print $fh "SCRAM_SOURCEDIR=".$self->sourcedir()."\n";
   print $fh "SCRAM_ProjReqsDoc=".$self->{reqdoc}."\n";
   print $fh "SCRAM_TOOLBOXVERSION=".$self->{toolboxversion}."\n";

   if ( defined $self->linkarea() )
      {
      my $area=$self->linkarea()->location();
      if ( $area ne "" )
	 {
	 print $fh "RELEASETOP=".$area."\n";
	 }
      }
   
   undef $fh;
   
   # Repeat the exercise to save as XML:
   my $fh=FileHandle->new();
   open ( $fh, ">".$self->location()."/".$self->{admindir}."/".
	  "Environment.xml" ) or 
	  $self->error("Cannot Open Environment.xml file to Save ("
		       .$self->location().")\n $!"); 
   print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
   print $fh "<doc type=\"Configuration::ProjectEnvironment\" version=\"1.0\">\n";
   print $fh " <environment SCRAM_PROJECTNAME=\"".$self->name()."\"/>\n";
   print $fh " <environment SCRAM_PROJECTVERSION=\"".$self->version()."\"/>\n";
   print $fh " <environment SCRAM_CONFIGDIR=\"".$self->configurationdir()."\"/>\n";
   print $fh " <environment SCRAM_SOURCEDIR=\"".$self->sourcedir()."\"/>\n";
   print $fh " <environment SCRAM_ProjReqsDoc=\"".$self->{reqdoc}."\"/>\n";
   print $fh " <environment SCRAM_TOOLBOXVERSION=\"".$self->{toolboxversion}."\"/>\n";

   if ( defined $self->linkarea() )
      {
      my $area=$self->linkarea()->location();
      if ( $area ne "" )
	 {
	 print $fh " <environment RELEASETOP=\"".$area."\"/>\n";
	 }
      }
   
   print $fh "</doc>\n";
   undef $fh;
   
   # Set the default permissions (-rw-r--r--):
   chmod $filemode, $self->location()."/".$self->{admindir}."/Environment";
   chmod $filemode, $self->location()."/".$self->{admindir}."/Environment.xml";
   }

sub _LoadEnvFile
   {
   my $self=shift;

   use FileHandle;
   my $fh=FileHandle->new();
   open ( $fh, "<".$self->location()."/".$self->{admindir}."/".
	  "Environment" ) or 
	  $self->error("Cannot find Environment file. Area Corrupted? ("
		       .$self->location().")\n $!"); 
   while ( <$fh> )
      {
      chomp;
      next if /^#/;
      next if /^\s*$/ ;
      ($name, $value)=split /=/;
      eval "\$self->{ENV}{${name}}=\"$value\"";
      }
   undef $fh;
	
   # -- set internal variables appropriately
   if ( defined $self->{ENV}{"SCRAM_PROJECTNAME"} )
      {
      $self->name($self->{ENV}{"SCRAM_PROJECTNAME"});
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
   if ( defined $self->{ENV}{"SCRAM_ProjReqsDoc"} )
      {
      $self->requirementsdoc($self->{ENV}{"SCRAM_ProjReqsDoc"});
      }
   if ( defined $self->{ENV}{"SCRAM_TOOLBOXVERSION"} )
      {
      if ($self->{ENV}{"SCRAM_TOOLBOXVERSION"} eq '')
	 {
	 $self->toolboxversion("STANDALONE");
	 }
      else
	 {
	 $self->toolboxversion($self->{ENV}{"SCRAM_TOOLBOXVERSION"});
	 }
      }
   
   if ( ( defined $self->{ENV}{"RELEASETOP"} ) && 
	($self->{ENV}{"RELEASETOP"} ne $self->location()))
      {
      $self->linkto($self->{ENV}{"RELEASETOP"});
      }
   }
