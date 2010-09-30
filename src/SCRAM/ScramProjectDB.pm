package SCRAM::ScramProjectDB;
use Utilities::Verbose;
use Utilities::AddDir;
require 5.004;
@ISA=qw(Utilities::Verbose);

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;
	$self->{dbfile}=shift || $ENV{'SCRAM_LOOKUPDB'};
	$self->{projectobjects}={};
	$self->{dirty}=0;
	return $self;
}

sub file {
	my $self=shift;
	return $self->{dbfile};
}

sub getarea
   {
   my $self=shift;
   my $name=shift;
   my $version=shift;
   my $area=undef;
   my $location = undef;
   $self->_readdbfile ($self->{dbfile});
   foreach my $type ("local","linked")
      {
      my $index=$self->_findlocation($name,$version,$type);
      if ($index != -1 ) 
         {
	 $location=$self->{projects}{$type}[$index][3];
	 last;
	 }
      }
      
   if ( defined $location )
      {	
      if ( defined $self->{projectobjects}{$location} )
	 {
	 $area=$self->{projectobjects}{$location};
	 }
      else
	 {
	 require Configuration::ConfigArea;
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
   my $area=shift;
   my $url=shift || "";
   my $name=$area->name();
   my $version=$area->version();

   my $type="file";
   if ($url eq ""){$url=$area->location();}
   $self->_readdbfile ($self->{dbfile},1);
   my $rv = 1;
   # -- check for duplicates
   for ( my $index=0; $index<=$#{$self->{projects}{local}}; $index++ )
      {
      if  ( $self->{projects}{local}[$index][0] eq $name )
	 {
	 if ( $self->{projects}{local}[$index][1] eq $version )
	    {
	    if ($flag == 0)
	       {
	       print "$name $version already exists. Overwrite? (y/n) : ";
	       if ( ! (<STDIN>=~/y/i ) )
		  {
		  print "Aborting install ...\n";
		  return 1;
		  }
	       }
	    $self->{projects}{local}[$index]=[ ($name,$version,$type,$url) ];
	    $rv=0;
	    last;
	    }
	 }
      }
   
   if ( $rv )
      {
      # -- add to our list and save
      push @{$self->{projects}{local}}, [ ($name,$version,$type,$url) ];
      }
   
   $self->_save();
   return 0;
   }

sub listlinks {
	my $self=shift;
	$self->_readdbfile ($self->{dbfile});
	return $self->{links};
}

sub list {
	my $self=shift;
	$self->_readdbfile ($self->{dbfile},1);
	return @{$self->{projects}{local}};
}

sub listall {
	my $self=shift;
	$self->_readdbfile ($self->{dbfile});
	return  $self->{projects};
}

sub tidy {
	my $self=shift;
	foreach my $proj ($self->list())
	   {
	   my $url=$$pr[3];
           if (!-e $url)
	      {
	      $self->_removearea($$pr[0],$$pr[1],1);
              }
	   }
}

sub _removearea
   {
   my $self=shift;
   my $name=shift;
   my $version=shift;
   my $flag=shift || 0;
   my $dirs=[];
   my $found=0;
   for ( my $index=0; $index<=$#{$self->{projects}{local}}; $index++ )
      {
      if  ( $self->{projects}{local}[$index][0] eq $name )
	 {
	 if ( $self->{projects}{local}[$index][1] eq $version )
	    {
	    if ($flag == 0)
	       {
	       print "Project $name Version $version exists. Remove it? (y/n): ";
	       if ( ! (<STDIN>=~/y/i ) )
		  {
		  return ($found,$dirs);
		  }
	       }
	       $found++;
	       push @$dirs,$self->{projects}{local}[$index][3];
	       splice(@{$self->{projects}{local}},$index,1);
	       $index--;
	    }
	 }
      }
   return ($found,$dirs);
   }
   
sub removearea
   {
   my $self=shift;
   my $flag=shift;
   my $name=shift;
   my $version=shift;
   $self->_readdbfile ($self->{dbfile},1);
   print "Going to remove $name $version from the current scram database.....","\n";
   my ($found,$dirs) = $self->_removearea ($name,$version,$flag);
   if ($found>0)
      {
      print "Removing project:\t$name\t$version","\n";
      $self->_save();
      }
   else
      {
      print "ERROR: Unable to find project $name with version $version in the database.","\n";
      }
   return $dirs;
   }

sub link {
	my $self=shift;
	my $dbfile=shift;
	$dbfile=~s/^\s*file://;
	my $dbfile=&Utilities::AddDir::fixpath($dbfile);
	if (-f $dbfile)
	  {
	  $self->_readdbfile ($self->{dbfile},1);
	  foreach my $db (@{$self->{links}{local}})
	     {
	     if ($db eq $dbfile)
	        {
		return 1;
		}
	     }
	  push @{$self->{links}{local}},$dbfile;
	  $self->_save ();
	  return 0;
	  }
}

sub unlink {
	my $self=shift;
	my $dbfile=shift;
	$dbfile=~s/^\s*file://;
	my $dbfile=&Utilities::AddDir::fixpath($dbfile);
	$self->_readdbfile ($self->{dbfile},1);
	my $dirty=0;
	for(my $i=0;$i<scalar(@{$self->{links}{local}});$i++)
	   {
	   my $db = $self->{links}{local}[$i];
	   if ($db eq $dbfile)
	      {
	      splice (@{$self->{links}{local}},$i,1);
	      $dirty=1;
	      }
	   }
	if ($dirty) {$self->_save ();}
	return !$dirty;
}

# -- Support Routines

sub _init {
          my $self=shift;
	  $self->{links}{local}=[];
	  $self->{projects}{local}=[];
}

#
# Search through the project list until we get a match
sub _findlocation {
	my $self=shift;
	my $name=shift;
	my $version=shift;
	my $type =shift || "local";

	my $found=-1;
	for (my $i=0; $i<=$#{$self->{projects}{$type}}; $i++ ) {
	  if  ( ( $self->{projects}{$type}[$i][0] eq $name) && 
		( $self->{projects}{$type}[$i][1] eq $version) ) {
	    $found=$i;
	    last;
	  }
	}
	return $found;
}

sub _save {
	my $self=shift;
        my $fh;
	my $filename=$self->{dbfile};
        if (!open ( $fh, ">$filename" )){die "Can not open file for writing: $filename\n";}
	# print current links 
	foreach $db ( @{$self->{links}{local}} ) {
	   print $fh "\!DB $db\n";
	}
	# save project info
	my $temp;
	foreach $elem ( @{$self->{projects}{local}} ) {
	  $temp=join ":", @{$elem};
	  print $fh $temp."\n";
	}
	close($fh);
        my $mode=0644;
        chmod $mode,$filename;
}

sub _readdbfile {
	my $self=shift;
	my $file=&Utilities::AddDir::fixpath(shift);
	my $localonly=shift || 0;
	my $type=shift || "local";
	my $read;
	if ($type eq "local")
	   {
	   if ((exists $self->{readtype}) && ($self->{readtype}<=$localonly))
	      {return;}
	   $self->_init ();
	   $self->{readtype}=$localonly;
	   }
        if ($localonly==0)
	   {
	   $read=shift || {};
	   if (exists $read->{uniq}{$file})
	      {
	      if ($ENV{SCRAM_DEBUG})
	         {
	         print STDERR "WARNING: Cyclic SCRAM DB links:\n";
	         foreach my $f (@{$read->{order}}){print STDERR "\t$f ->\n";}
	         print STDERR "\t$file\n";
	         }
	      return;
	      }
	   if (exists $read->{done}{$file}){return;}
	   $read->{done}{$file}=1;
	   }
        my $fh;
	$self->verbose("Initialising db from $file");
        if (!open ( $fh, "<$file" ))
	   {
	   if ($type eq "local")
	      {
	      die "ERROR: Can not open file for reading: $file\n";
	      }
	   }
	my @dblinks=();
	while ( $map=<$fh> ) {
	  chomp $map;
          if ( $map=~/^\!DB\s+(.+)/ ) { # Check for other DB files
                my $db=&Utilities::AddDir::fixpath($1);
                if ( -f $db )
		   {
		   push @dblinks,$db;
		   push @{$self->{links}{$type}},$db;
		   }
                next;
          }
          my @vars = split ":", $map;
	  $self->verbose("registering project $map");
	  push @{$self->{projects}{$type}}, [ @vars ];
	}
	close($fh);
	if ($localonly == 0)
	   {
	   $read->{uniq}{$file}=1;
	   if(!exists $read->{order}) {$read->{order}=[];}
	   push @{$read->{order}},$file;
	   foreach my $db (@dblinks)
	      {
	      $self->_readdbfile($db,$localonly,"linked",$read);
	      }
	   delete $read->{uniq}{$file};
	   pop @{$read->{order}};
	   }
}
