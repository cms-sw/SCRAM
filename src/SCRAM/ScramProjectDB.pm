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
path $databasefile as argument.

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
require 5.004;
@ISA=qw(Utilities::Verbose);

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;
	$self->{dbfile}=shift;
	$self->_readdbfile($self->{dbfile});
	$self->{projectobjects}={};
	return $self;
}

sub file {
	my $self=shift;
	return $self->{dbfile};
}

sub getarea
   {
   require Configuration::ConfigArea;
   my $self=shift;
   my $name=shift;
   my $version=shift;
   my $area=undef;
   my $index=$self->_findlocal($name,$version);
   
   if ( $index != -1 )
      {	
      my $location=$self->{projects}[$index][3];
      if ( defined $self->{projectobjects}{$location} )
	 {
	 $area=$self->{projectobjects}{$location};
	 }
      else
	 {
	 $area=Configuration::ConfigArea->new();
	 $self->verbose("Attempt to ressurect $name $version from $location");
	 if ( $area->bootstrapfromlocation($location) == 1 )
	    {
	    undef $area;
		 $self->verbose("attempt unsuccessful");
	    }
	 else
	    {
	    $self->verbose("area found");
	    $self->{projectobjects}{$location}=$area;
	    }
	 }
      }
   else
      {
      # -- search in linked databases
      foreach $db ( @{$self->{linkeddbs}} )
	 {
	 $self->verbose("Searching in $db->file() for $name $version");
	 $area=$db->getarea($name,$version);
	 last if (defined $area);
	 }
      }
   if ( ! defined $area )
      {
      $self->verbose("Area $name $version not found");
      }

   return $area;
   }


sub addarea
   {
   my $self=shift;
   my $flag=shift;
   my $name=shift;
   my $version=shift;
   my $area=shift;

   my $rv=1;
   my $type="file";
   my $url=$area->location();

   # -- check for duplicates
   for ( my $index=0; $index<=$#{$self->{projects}}; $index++ )
      {
      if  ( $self->{projects}[$index][0] eq $name )
	 {
	 if ( $self->{projects}[$index][1] eq $version )
	    {
	    if ($flag == 1)
	       {
	       $rv=0;
	       $self->{projects}[$index]=[ ($name,$version,$type,$url) ];
	       }
	    else
	       {
	       print "$name $version already exists. Overwrite? (y/n) : ";
	       if ( ! (<STDIN>=~/y/i ) )
		  {
		  print "Aborting install ...\n";
		  return 1;
		  }
	       else
		  {
		  $rv=0;
		  $self->{projects}[$index]=[ ($name,$version,$type,$url) ];
		  }
	       }
	    }
	 else
	    {
	    print "Related Project : $name ".$self->{projects}[$index][1]."\n";
	    }
	 }
      }
   
   if ( $rv )
      {
      # -- add to our list and save
      push @{$self->{projects}}, [ ($name,$version,$type,$url) ];
      }
   
   $self->_save();
   return 0;
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
	return @{$self->{projects}};
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
   my $flag=shift;
   my $name=shift;
   my $version=shift;
   my $vfound=0;
   my $nfound=0;
   
   print "\n","Going to remove $name $version from the current scram database.....","\n"; 
   print "\n";

   for ( my $index=0; $index<=$#{$self->{projects}}; $index++ )
      {
      # Look for a project with name $name:
      if  ( $self->{projects}[$index][0] eq $name )
	 {
	 $nfound=1; 
	 # Check the version:
	 if ( $self->{projects}[$index][1] eq $version )
	    {
	    # We have a match for project name and version:
	    $vfound=1;
	    if ($flag == 1)
	       {
	       # Remove the project:
	       print "\n";
	       print "Removing project:\t$name\t$version","\n\n";
	       splice(@{$self->{projects}},$index,1);
	       }
	    else
	       {
	       print "Project $name Version $version exists. Remove it? (y/n): ";
	       if ( ! (<STDIN>=~/y/i ) )
		  {
		  print "\n","Aborting project removal...bye.\n\n";
		  return 1;
		  }
	       else
		  {
		  # Remove the project:
		  print "\n";
		  print "Removing project:\t$name\t$version","\n\n";
		  splice(@{$self->{projects}},$index,1);
		  }
	       }
	    }
	 } 
      }
   
   if ( ! $nfound || ! $vfound )
      {
      # There was a problem finding either the
      # named project or the desired version:
      print "ERROR: Unable to find project $name with version $version in the database.","\n\n";
      return 1;
      }
   
   print "\n";   
   # Save our new array:
   $self->_save();
   return 0;
   }

sub link {
	my $self=shift;
	my $dbfile=shift;

	my $newdb=SCRAM::ScramProjectDB->new($dbfile);
	push @{$self->{linkeddbs}},$newdb; 
	$self->_save();
}

sub unlink {
	my $self=shift;
	my $file=shift;
	my $db;
	
	for (my $i=0; $i<=$#{$self->{linkeddbs}}; $i++ ) {
	   $db=${$self->{linkeddbs}}[$i];
	   if  ( $db->file() eq $file ) {
	     $self->verbose("Removing link $file");
	     splice (@{$self->{linkeddbs}},$i,1);
	     $self->_save();
	   }
	}
}

# -- Support Routines

#
# Search through the project list until we get a match
sub _findlocal {
	my $self=shift;
	my $name=shift;
	my $version=shift;

	my $found=-1;
	for (my $i=0; $i<=$#{$self->{projects}}; $i++ ) {
	  if  ( ( $self->{projects}[$i][0] eq $name) && 
		( $self->{projects}[$i][1] eq $version) ) {
	    $found=$i;
	    last;
	  }
	}
	return $found;
}

sub _save {
	my $self=shift;

	use FileHandle;
        my $fh=FileHandle->new();
	my $filename=$self->{dbfile};
        open ( $fh, ">$filename" );
	# print current links 
	foreach $db ( @{$self->{linkeddbs}} ) {
	   print $fh "\!DB ".$db->file()."\n";
	}
	# save project info
	my $temp;
	foreach $elem ( @{$self->{projects}} ) {
	  $temp=join ":", @{$elem};
	  print $fh $temp."\n";
	}
	undef $fh;
}

sub _readdbfile {
	my $self=shift;
	my $file=shift;
	
	use FileHandle;
        my $fh=FileHandle->new();
	$self->verbose("Initialising db from $file");
        open ( $fh, "<$file" );

	my @vars;
	my $newdb;
	while ( $map=<$fh> ) {
	  chomp $map;
          if ( $map=~/^\!DB (.*)/ ) { # Check for other DB files
                my $db=$1;
                if ( -f $db ) {
		  $self->verbose("Getting Linked DB $db");
                  $newdb=SCRAM::ScramProjectDB->new($db);
		  push @{$self->{linkeddbs}},$newdb; 
                }
                next;
          }
          @vars = split ":", $map;
	  $self->verbose("registering project $map");
	  push @{$self->{projects}}, [ @vars ];
	}
	undef $fh;
}
