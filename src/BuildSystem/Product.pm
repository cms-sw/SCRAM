#____________________________________________________________________ 
# File: Product.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
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
      $rfiles =~ s/,/ /g;
      foreach my $file (split(/\s+/,$rfiles)) {if ($file ne ""){push(@$files,$file);}}
      $self->{FILES} = $files;
      }
   else
      {
      return $self->{FILES};
      }
   }

sub _command()
   {
   my ($self, $cmd)=@_;
   $self->{COMMAND}=$cmd;
   }

sub command()
   {
   my $self=shift;
   return $self->{COMMAND};
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
