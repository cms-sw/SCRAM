#____________________________________________________________________ 
# File: Product.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-07-27 11:49:59+0200
# Revision: $Id: Product.pm,v 1.2.4.1 2007/01/24 14:40:17 sashby Exp $ 
#
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::Product;
require 5.004;
use Exporter;
@EXPORT_OK=qw( );

sub new()
  ###############################################################
  # new                                                         #
  ###############################################################
  # modified : Wed Apr 14 12:59:34 2004 / SFA                   #
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
  return $self;
  }

sub name()
   {
   my $self=shift;
   @_ ? $self->{NAME} = shift
      : $self->{NAME};
   }

sub safename()
   {
   my $self=shift;
   $self->{SAFENAME} = $self->{NAME};
   $self->{SAFENAME} =~ s/\./_/g;
   return $self->{SAFENAME};
   }

sub _data()
   {
   # Private data (raw data from BuildFile <prod> tags (bin/lib/mod etc)):
   my $self=shift;
   @_ ? $self->{content} = shift
      : $self->{content};
   }

sub data()
   {
   # Public data (processed data from BuildFile):
   my $self=shift;
   @_ ? $self->{DATA} = shift
      : $self->{DATA};
   }

sub type()
   {
   my $self=shift;
   @_ ? $self->{TYPE} = shift
      : $self->{TYPE};
   }

sub _files()
   {
   my $self=shift;
   my ($rfiles,$pathstotry)=@_;
   my $files=[];

   if ($rfiles)
      {
      # Here, we process the input file "string" and convert it from
      # a comma-sep list/glob to array contents:
      if ($rfiles =~ s/,/ /g)
	 {
	 push(@$files, split(" ",$rfiles));
	 }
      elsif ($rfiles =~ /\*\..*/) # Globs. We use the paths from BuildFiles
	 {                        # to figure out where the files are
	 use File::Basename;
	 # List of paths to try globs from in lib tags:
	 my $pathlist=[ map { dirname($_) } @$pathstotry ];
	 
	 # The most likely location to search for files will be the longest
	 # path (up to BuildFile). We apply a reverse sort to get longest
	 # path first, then test this against the first element X of $rfiles (match to "X/"):
	 foreach my $path (reverse sort @$pathlist)
	    {
	    if ($rfiles =~ m|(.*?)/\*\..*|)
	       {
	       # We have a file list like "dir/*.cc"; extract "dir":
	       my $subdir=$1;
	       if ( -d $path."/".$subdir)
		  {
		  my $filelocation=$path."/".$rfiles;
		  map
		     {
		     # Take the basename of each file but then re-add
		     # the matched subdir above:
		     push(@$files, $subdir."/".basename($_));
		     } glob($filelocation);
		  }
	       last;
	       }
	    else
	       {
	       # We just glob from the first path:
	       my $filelocation=$path."/".$rfiles;
	       map
		  {
		  push(@$files, basename($_));
		  } glob($filelocation);
	       
	       last;
	       }
	    }
	 }
      else
	 {
	 # Split on whitespace and push onto array:
	 push(@$files, split(" ",$rfiles));
	 }
      
      $self->{FILES} = $files;
      }
   else
      {
      return $self->{FILES};
      }
   }

sub files()
   {
   my $self=shift;
   return join(" ",@{$self->_files()});
   }

sub lib
   {
   my $self=shift;
   # Return an array of required libs:
   return $self->{content}->{LIB};
   }

sub include
   {
   my $self=shift;
   # Return an array of required includes:
   return $self->{content}->{INCLUDE};
   }

sub libtype
   {
   my $self=shift;
   # Return an array of required lib types:
   return $self->{content}->{LIBTYPE};
   }

sub flags
   {
   my $self=shift;
   # Return hash data for flags:
   return $self->{content}->{FLAGS};
   }

sub allflags
   {
   my $self=shift;
   # Return hash data for flags:
   return $self->{content}->{FLAGS};
   }

sub makefile
   {
   my $self=shift;
   # Return an array of makefile stubs:
   return $self->{content}->{MAKEFILE};
   }

sub archspecific
   {
   my $self=shift;
   
   # Check to see if there is arch-dependent data. If so, return it:
   if ((my $nkeys=keys %{$self->{content}->{ARCH}}) > 0)
      {
      while (my ($k,$v) = each %{$self->{content}->{ARCH}})
	 {
	 if ( $ENV{SCRAM_ARCH} =~ /$k.*/ )
	    {
	    return $self->{content}->{ARCH}->{$k};
	    }
	 }
      }
   return "";
   }

sub use
   {
   my $self=shift;
   # Add or return uses (package deps):
   @_ ? push(@{$self->{content}->{USE}},@_)
      : @{$self->{content}->{USE}};
   }

sub group
   {
   my $self=shift;
   # Add or return groups:
   @_ ? push(@{$self->{content}->{GROUP}},@_)
      : @{$self->{content}->{GROUP}};
   }

sub basic_tags()
   {
   my $self=shift;
   my $datatags=[];
   my $buildtags=[ qw(BIN LIBRARY APPLICATION MODULE PLUGIN BUILDPRODUCTS) ];
   my $skiptags=[ qw(DEFINED_GROUP ARCH EXPORT GROUP USE CLASSPATH) ];
   my $otherskiptags=[ qw( SKIPPEDDIRS ) ];
   my @all_skip_tags;
   
   push(@all_skip_tags,@$skiptags,@$buildtags,@$otherskiptags);

   foreach my $t (keys %{$self->{content}})
      {
      push(@$datatags,$t),if (! grep($t eq $_, @all_skip_tags));
      }
   return @{$datatags};
   }

sub AUTOLOAD()
   {
   my ($xmlparser,$name,%attributes)=@_;
   return if $AUTOLOAD =~ /::DESTROY$/;
   my $name=$AUTOLOAD;
   $name =~ s/.*://;
   print __PACKAGE__."::AUTOLOAD: $name() called. This function should be defined.\n";
   }

1;
