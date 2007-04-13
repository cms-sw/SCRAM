=head1 NAME

SCRAM::ScramProjectDB - Keep track of available projects.

=head1 SYNOPSIS

	my $obj = SCRAM::ScramProjectDB->new($databasefile);

=head1 DESCRIPTION

Stores project area information.

=head1 METHODS

=over

=cut

=item C<new($databasefile)>

A new SCRAM::ScramProjectDB object. Receives a database file
path $databasefile as argument and handles reading the XML
database file. Note that an empty file is initialised the
first time a SCRAM::ScramProjectDB object is created.

=item C<file()>

Return the database file.

=item C<getarea($name,$version)>

Return the object matching the name $name and version $version.

=item C<addarea($area)>

Add a project area $area (a Configuration::ConfigArea object)
and return 0 for success or 1 for abort.

=item C<list()>

List local areas (returns $name, $version pairs).

=item C<listall()>

List local and linked areas.

=item C<listlinks()>

Show a list of links (linked databases).

=item C<removearea($name, $version)>

Remove the named project.

=item C<link($dblocation)>

Link with specified location $dblocation. 

=item C<unlink($dblocation)>

Remove link with a specified location $dblocation (i.e. path).

=back

=head1 AUTHOR

Originally written by Christopher Williams.

=head1 MAINTAINER

Shaun ASHBY 

=cut

package SCRAM::ScramProjectDB;
use Utilities::Verbose;
use Utilities::XMLParser qw(&xmlrdr);
use SCRAM::ProjectDB;

require 5.004;
@ISA=qw(Utilities::Verbose);

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{dbfile}=shift;
    # Initialise a new XML db file if
    # it doesn't exist already or if
    # a zero-length file exists:
    $self->_initdb(), if (! -f $self->{dbfile} || -z $self->{dbfile});
    $self->_readdbfile($self->{dbfile});
    return $self;
}

sub file {
    my $self=shift;
    return $self->{dbfile};
}

sub dbproxy() {
    my $self=shift;
    return $self->{dbproxy};
}

sub listlinks {
    my $self=shift;    
    my  @dbfile=();
    foreach $db ( @{$self->{linkeddbs}} ) {
	push @dbfile, $db->file();
    }
    return @dbfile;
}

sub list {
    my $self=shift;
    return $self->projects();
}

sub listall {
    my $self=shift;
    my @list=$self->list();
    foreach $db ( @{$self->{linkeddbs}} ) {
	$self->verbose("Adding list from $db");
	push @list, $db->listall();
    }
    return @list;
}

sub link {
    my $self=shift;
    my $dbfile=shift;
    $self->dbproxy()->link_db($dbfile);
    $self->_save();
}

sub unlink {
    my $self=shift;
    my $file=shift;
    $self->dbproxy()->unlink_db($file);
    $self->_save();
}

sub _readdbfile {
    my $self=shift;
    my $file=shift;
    # First of all, read the XML db. This will return all
    # content for the current architecture:
    $self->verbose("Initialising db from $file");
    # Load up the database from the XML file:
    $self->{dbproxy}=&Utilities::XMLParser::xmlrdr($file,'SCRAM');
    # Look for linked databases:
    foreach my $l_db (@{$self->{dbproxy}->get_linked_dbs()}) {
	if (-f $l_db) {
	    $self->verbose("Getting Linked DB $l_db");
	    my $newdb=SCRAM::ScramProjectDB->new($l_db);
	    push(@{$self->{linkeddbs}},$newdb);
	}
    }
}

sub projects() {
    my $self=shift;
    my ($arch)=@_;
    $self->{projects} = $self->dbproxy()->projects($arch);
    return @{$self->{projects}};
}

sub write() {
    my $self=shift;
    my $fstring=$self->dbproxy()->write();
    return $fstring;
}

sub validate() {
    my $self=shift;   
    $self->dbproxy()->validate(),"\n";
    print "\n";
}

sub getarea {
    require Configuration::ConfigArea;
    my $self=shift;
    my $name=shift;
    my $version=shift;
    my $area=undef;
    # Look in local db first. This returns a version object:
    my $alocal=$self->_findlocal($name,$version);
    if ($alocal) {
	my $location = $alocal->path;
	if ( defined $self->{projectobjects}{$location} ) {
 	    $area=$self->{projectobjects}{$location};
 	} else {
	    $area=Configuration::ConfigArea->new();
	    $self->verbose("Attempt to ressurect $name $version from $location");
	    if ( $area->bootstrapfromlocation($location) == 1 ) {
		undef $area;
		$self->verbose("attempt unsuccessful");
	    } else {
		$self->verbose("area found");
		$self->{projectobjects}{$location}=$area;
	    }   
	}
    } else {
	# Look through the linked databases:
	foreach $db ( @{$self->{linkeddbs}} ) {
	    $self->verbose("Searching in $db->file() for $name $version");
	    $area=$db->getarea($name,$version);
	    last if (defined $area);	    
	}
    }
    
    if ( ! defined $area ) {
	$self->verbose("Area $name $version not found");
    }
    
    return $area;
}

sub addarea {
    my $self=shift;
    my ($flag,$name,$version,$area)=@_;
    $self->dbproxy()->install_project($flag,$name,$version,$area);
    $self->_save();
   return 0;
}

sub removearea
   {
   ###############################################################
   # removearea(name,version)                                    #
   ###############################################################
   # modified : Mon May 28 11:24:29 2001 / SFA                   #
   # params   :                                                  #
   #          :                                                  #
   #          :                                                  #
   #          :                                                  #
   # function : Remove project area from scramdb file.           #
   #          :                                                  #
   #          :                                                  #
   ###############################################################
   my $self=shift;
   my ($flag,$name,$version)=@_;
   print "\n","Going to remove $name $version from the current scram database.....","\n"; 
   print "\n";
   $self->dbproxy()->delete_project($flag,$name,$version);
   $self->_save();
   return 0;
   }


# -- Support Routines

#
# Search through the project list until we get a match
sub _findlocal {
    my $self=shift;
    my ($name,$version)=@_;
    # Look in the local stash of projects found in the db:
    my $pobj = $self->dbproxy()->get_projects_with_name($name);
    my $obj;
    if ($pobj) {
	$obj = $pobj->version($version);
    }
    ($obj) ? return $obj : return undef;
}

sub _initdb() {
    my $self=shift;
    my $fstring="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
    $fstring.="<ProjectDB>\n";
    $fstring.=" <architecture name=\"".$ENV{SCRAM_ARCH}."\">\n";
    $fstring.=" </architecture>\n";
    $fstring.="</ProjectDB>\n";
    use FileHandle;
    my $fh=FileHandle->new();
    my $filename=$self->{dbfile};
    open($fh, ">$filename") || die "Can't write to ".$self->{dbfile}.":".$!."\n";
    print $fh $fstring."\n";
    undef $fh;
}

sub _save() {
    my $self=shift;
    use FileHandle;
    my $fh=FileHandle->new();
    my $filename=$self->{dbfile};
    open($fh, ">$filename") || die "Can't write to ".$self->{dbfile}.":".$!."\n";
    print $fh $self->write()."\n";
    undef $fh;
}

1;
