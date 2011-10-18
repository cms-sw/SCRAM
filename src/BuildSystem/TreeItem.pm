#____________________________________________________________________ 
# File: TreeItem.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::TreeItem;
require 5.004;
use Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw( );

sub new()
  ###############################################################
  # new                                                         #
  ###############################################################
  # modified : Thu Jun 24 12:25:02 2004 / SFA                   #
  # params   :                                                  #
  #          :                                                  #
  # function :                                                  #
  #          :                                                  #
  ###############################################################
  {
  my $proto=shift;
  my $class=ref($proto) || $proto;
  my $self={};
 
  bless $self,$class;
  $self->{METABF} = [];
  return $self;
  }

sub safepath()
   {
   my $self=shift;
   
   if ($self->{PATH})
      {
      # Make a safe path from our path:
      ($safepath = $self->{PATH}) =~ s|/|_|g;
      $self->{SAFEPATH} = $safepath;
      }

   # Return the safe version of the current path:
   return $self->{SAFEPATH};
   }

sub path()
   {
   my $self=shift;
   @_ ? $self->{PATH} = shift
      : $self->{PATH};
   }

sub class()
   {
   my $self=shift;
   my ($class)=@_;
   # Set/return the part of the ClassPath that matched a template name.
   # Note that we store it as uppercase! The template name is, of course,
   # exactly as it appears in the ClassPath:
   if ($class)
      {
      $self->{CLASS} = uc($class);
      $self->template($class);
      }
   else
      {
      return $self->{CLASS};
      }
   }

sub template()
   {
   my $self=shift;
   my ($template)=@_;
   if ($template)
      {
      $self->{TEMPLATE} = $template;
      }
   else
      {
      return $self->{TEMPLATE};
      }
   }

sub classdir()
   {
   my $self=shift;
   # Set/return the part of the ClassPath that matched:
   @_ ? $self->{CLASSDIR} = shift
      : $self->{CLASSDIR};
   }

sub suffix()
   {
   my $self=shift;
   # Set/return the part of the ClassPath that didn't match:
   @_ ? $self->{SUFFIX} = shift
      : $self->{SUFFIX};
   }

sub skip()
   {
   my $self=shift;
   # Skip/unskip a directory:
   @_ ? $self->{SKIP} = shift
      : $self->{SKIP};
   }

sub productstore()
   {
   my $self=shift;
   @_ ? $self->{PRODUCTSTORES} = shift
      : $self->{PRODUCTSTORES};
   }
   
sub name()
   {
   my $self=shift;
   my $n=shift;
   if(defined $n){$self->{NAME}=$n; return;}

   # Don't bother doing any work if the NAME exists already - just return it:
   if (! exists($self->{NAME}))
      {
      my $classdir = $self->{CLASSDIR}; # Make a copy for protection      
      # Here we want to return a name that can be used in the templates.
      # The name could be the name of the subsystem or the package:
      if ($self->{CLASS} eq 'PACKAGE')
	 {
	 ($self->{NAME}) = ($classdir =~ m|^.*/(.*)?$|);	 
	 }
      elsif ($self->{CLASS} eq 'SUBSYSTEM')
	 {
	 # We want the name of the subsystem:
	 ($self->{NAME}) = ($classdir =~ m|^.*/(.*)?$|);
	 }
      elsif ($self->{CLASS} eq 'DOMAIN')
	 {
	 # We want the name of the domain:
	 ($self->{NAME}) = ($classdir =~ m|^.*/(.*)?$|);
	 }
      elsif ($self->{CLASS} eq 'LIBRARY')
         {
	 #use SCRAM::ProductName;
	 #my $n = &SCRAM::ProductName::get_safename($classdir);
	 my $n="";
	 if ($n ne "")
	    {
	    $self->{NAME} = $n;
	    }
	 }
      if (! exists($self->{NAME}))
	 {
	 # Here we have a path that ends in src/bin/test/doc etc. (for real
	 # build products). We still want to return the package name:
	 ($self->{NAME}) = ($classdir =~ m|^.*/(.*)/.*?$|);
	 }
      }
   else  
      {
      return $self->{NAME};
      }
   }

sub rawdata()
   {
   my $self=shift;
   my ($rawdata)=@_;

   if ($rawdata)
      {
      $self->{RAWDATA} = $rawdata;
      return $self;
      }
   else
      {      
      if (exists ($self->{RAWDATA}))
	 {
	 return $self->{RAWDATA};
	 }
      else
	 {
	 return undef;
	 }
      }
   }

sub parent()
   {
   my $self=shift;
   my ($datapath)=@_;
   my $thisloc;

   if ($datapath)
      {
      # We don't want to store the parent of src (it has no parent):
      if ($datapath eq $ENV{SCRAM_SOURCEDIR})
	 {
	 return;
	 }
      
      # Given a path like a/b/c we want to return the parent a/b:
      ($thisloc) = ($datapath =~ m|^(.*)/.*?$|);

      if ($thisloc ne '')
	 {
	 $self->{PARENT} = $thisloc;
	 }
      else
	 {
	 $self->{PARENT} = $ENV{SCRAM_SOURCEDIR};
	 }
      }
   else
      {
      (exists ($self->{PARENT})) ? return $self->{PARENT} : '' ;
      }
   }

sub children()
   {
   my $self=shift;
   my ($filecache) = @_;
   my $safesubs=[];
   
   if ($filecache)
      {
      if (exists $filecache->{$self->{PATH}})
	 {
	 # Get array ref:
	 my @subdirs=@{$filecache->{$self->{PATH}}};
	 my $children=[];

	 foreach my $SD (@subdirs)
	    {
	    # We don't want timestamps or CVS directories:
	    if ($SD !~ /.*CVS/ && $SD !~ /^[0-9]+$/)
	       {
	       my $datapath;
	       # We want to store the data paths for the children:
	       ($datapath = $SD) =~ s|^\Q$ENV{SCRAM_SOURCEDIR}\L/||;
	       push(@$children,$datapath);
	       push(@$safesubs,$SD);
	       }
	    }
	 
	 # Store the children only if there were some:
	 if ($#$children > -1)
	    {
	    $self->{CHILDREN} = $children;
	    # Make safe versions of each subdir:
	    $self->safesubdirs(@$safesubs);
	    }
	 }
      }
   else
      {
      (exists ($self->{CHILDREN})) ? return @{$self->{CHILDREN}} : undef ;
      }
   }

sub metabf()
   {
   my $self=shift;
   my (@metabf) = @_;

   if (@metabf)
      {      
      foreach my $mbf (@metabf)
	 {
	 if (! grep($mbf eq $_, @{$self->{METABF}})) # Remove duplicates!!
	    {
	    push(@{$self->{METABF}}, $mbf);
	    }
	 }
      }
   else
      {
      return $self->{METABF};
      }
   }

sub branchmetadata()
   {
   my $self=shift;
   my ($meta)=@_;

   # Method to store/retrieve data for complete branch:
   if ($meta)
      {
      # Delete unneeded entries:
      #$meta->clean(qw( EXPORT DEFINED_GROUP CLASSPATH SKIPPEDDIRS ));
      $self->{RAWDATA} = $meta;
      }
   else
      {
      return $self->{RAWDATA};
      }
   }

sub branchdata()
   {
   my $self=shift;
   @_ ? $self->{RAWDATA} = shift
      : $self->{RAWDATA};
   }

sub clearmeta()
   {
   my $self=shift;
   delete $self->{RAWDATA};
   }

sub updatechildlist()
   {
   my $self=shift;
   my ($child)=@_;

   # Loop over list of children, removing the one specified:
   my $uchildren = [];
   my $uchilddirs = [];
   
   foreach my $c (@{$self->{CHILDREN}})
      {
      if ($c ne $child)
	 {
	 push(@$uchildren, $c);
	 # Convert this datapath into a path to be converted to a safepath:
	 push(@{$uchilddirs}, 'src/'.$c);
	 }
      else
	 {
	 print "TreeItem: Removing $child from parents child list.","\n",if ($ENV{SCRAM_DEBUG});
	 }
      }
   
   # Now store the new list of children:
   $self->{CHILDREN} = [ @$uchildren ];
   # Update the safe subdir names:
   $self->updatesafesubdirs(@$uchilddirs);   
   }

sub updatesafesubdirs()
   {
   my $self=shift;
   my (@subdirs)=@_;
   # Reset the SAFESUBDIRS to the list of subdirs given:
   delete $self->{SAFESUBDIRS};
   $self->safesubdirs(@subdirs);
   }

sub updateparentstatus()
   {
   my $self=shift;
   my ($child) = @_;

   # Add child to CHILDREN (check to make sure it isn't there already):
   if (exists($self->{CHILDREN}))
      {
      if (! grep($child eq $_, @{$self->{CHILDREN}})) # Remove duplicates!!
	 {
	 push(@{$self->{CHILDREN}},$child);
	 }
      }
   else
      {
      $self->{CHILDREN} = [ $child ];
      }

   # Add the SAFESUBDIRS:
   my $safedir = [ 'src/'.$child ];
   $self->safesubdirs(@$safedir);
   }

sub safesubdirs()
   {
   my $self=shift;
   my (@subdirs)=@_;
   
   if (@subdirs)
      {      
      # If we already have SAFESUBDIRS, add to them, don't overwrite:
      if (exists($self->{SAFESUBDIRS}))
	 {
	 # Store the safe paths of all the children:
	 foreach my $sd (@subdirs)
	    {
	    $sd =~ s|/|_|g;
	    if (! grep($sd eq $_, @{$self->{SAFESUBDIRS}})) # Remove duplicates!!
	       {
	       push(@{$self->{SAFESUBDIRS}}, $sd);
	       }
	    }
	 }
      else
	 {
	 my $safesubs=[];
	 map {$_ =~ s|/|_|g; push(@$safesubs, $_)} @subdirs;
	 $self->{SAFESUBDIRS} = $safesubs;
	 }
      }
   else
      {
      # Return formatted as a string:
      return join(" ",@{$self->{SAFESUBDIRS}});
      }
   }

sub scramprojectbases()
   {
   my $self=shift;
   # This is needed at project level only:
   @_ ? $self->{SCRAM_PROJECT_BASES} = shift
      : $self->{SCRAM_PROJECT_BASES};
   }

sub publictype()
   {
   my $self=shift;
   my $type=shift;
   if (defined $type) {$self->{PUBLIC} = $type; return;}
   if(exists $self->{PUBLIC}){return $self->{PUBLIC};}
   return 0;
   }

sub clean()
   {
   my $self=shift;
   delete $self->{RAWDATA};
   }

1;
