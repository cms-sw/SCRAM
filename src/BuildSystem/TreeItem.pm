#____________________________________________________________________ 
# File: TreeItem.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-06-24 12:24:57+0200
# Revision: $Id: TreeItem.pm,v 1.1.2.6 2004/11/18 13:01:24 sashby Exp $ 
#
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
      # Store template name. We add the standard suffix:
      $self->template($class."_template.tmpl");
      $self->{CLASS} = uc($class);
      }
   else
      {
      return $self->{CLASS};
      }
   }

sub template()
   {
   my $self=shift;
   @_ ? $self->{TEMPLATE} = shift
      : $self->{TEMPLATE};
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

sub name()
   {
   my $self=shift;

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
      else
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
      $meta->clean(qw( EXPORT DEFINED_GROUP CLASSPATH ));
      $self->{BRANCHMETA} = $meta;
      }
   else
      {
      return $self->{BRANCHMETA};
      }
   }

sub branchdata()
   {
   my $self=shift;
   @_ ? $self->{BRANCHDATA} = shift
      : $self->{BRANCHDATA};
   }

sub clearmeta()
   {
   my $self=shift;
   delete $self->{BRANCHDATA}, if (exists $self->{BRANCHDATA});
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

sub template()
   {
   my $self=shift;
   @_ ? $self->{TEMPLATE} = shift
      : $self->{TEMPLATE};
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

sub clean()
   {
   my $self=shift;
   delete $self->{BRANCHMETA};
   }

1;
