#____________________________________________________________________ 
# File: BuildFile.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-12-03 19:03:15+0100
# Revision: $Id: BuildFile.pm,v 1.26 2004/12/10 13:41:37 sashby Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::BuildFile;
require 5.004;
use Exporter;
use BuildSystem::TagUtils;
use BuildSystem::BuildDataUtils;
use ActiveDoc::SimpleDoc;

@ISA=qw(Exporter BuildSystem::BuildDataUtils);
@EXPORT_OK=qw( );

#
sub new()
   ###############################################################
   # new                                                         #
   ###############################################################
   # modified : Wed Dec  3 19:03:22 2003 / SFA                   #
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

   $self->{DEPENDENCIES} = {};
   $self->{content} = {};
   return $self;
   }

sub _initparser()
   {
   my $self=shift;

   $self->{simpledoc}=ActiveDoc::SimpleDoc->new();
   $self->{simpledoc}->newparse("builder");
   $self->{simpledoc}->addignoretags("builder");

   # For blank lines do nothing:
   $self->{simpledoc}->addtag("builder","none",
			      "", $self,
			      "", $self,
			      "", $self);
   
   # Define the tags to be used in this class:
   $self->{simpledoc}->addtag("builder","classpath",
			      \&BuildSystem::TagUtils::classpathtagOpen, $self,
			      "", $self,
			      "", $self);

   $self->{simpledoc}->addtag("builder","productstore",
			      \&BuildSystem::TagUtils::productstoretagOpen, $self,
			      "", $self,
			      "", $self);

   $self->{simpledoc}->addtag("builder","architecture",
			      \&BuildSystem::TagUtils::archtagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::archtagClose, $self);

   $self->{simpledoc}->addtag("builder","include_path",
			      \&BuildSystem::TagUtils::includetagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("builder","define_group",
			      \&BuildSystem::TagUtils::groupdeftagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::groupdeftagClose, $self);
   
   $self->{simpledoc}->addtag("builder","group",
			      \&BuildSystem::TagUtils::grouptagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("builder","lib",
			      \&BuildSystem::TagUtils::libtagOpen, $self,
			      "", $self,
			      "", $self);

   $self->{simpledoc}->addtag("builder","export",
			      \&BuildSystem::TagUtils::exporttagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::exporttagClose, $self);

   $self->{simpledoc}->addtag("builder","use",
			      \&BuildSystem::TagUtils::usetagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("builder","libtype",
			      \&BuildSystem::TagUtils::libtypetagOpen, $self,
			      "", $self,
			      "", $self);

   $self->{simpledoc}->addtag("builder","skip",
			      \&BuildSystem::TagUtils::skippedtagOpen, $self,
			      "", $self,
			      "", $self);

   $self->{simpledoc}->addtag("builder","makefile",
			      \&BuildSystem::TagUtils::makefiletagOpen, $self,
			      \&BuildSystem::TagUtils::makefiletagContent, $self,
			      \&BuildSystem::TagUtils::makefiletagClose, $self);

   $self->{simpledoc}->addtag("builder","flags",
			      \&BuildSystem::TagUtils::flagstagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("builder","bin",
			      \&BuildSystem::TagUtils::binarytagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::binarytagClose, $self);
   
   $self->{simpledoc}->addtag("builder","module",
			      \&BuildSystem::TagUtils::moduletagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::moduletagClose, $self);
   
   $self->{simpledoc}->addtag("builder","application",
			      \&BuildSystem::TagUtils::applicationtagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::applicationtagClose, $self);

   $self->{simpledoc}->addtag("builder","library",
			      \&BuildSystem::TagUtils::librarytagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::librarytagClose, $self);

#    $self->{simpledoc}->addtag("builder"," ",
# 			      \&BuildSystem::TagUtils::  ,$self,
# 			      \&BuildSystem::TagUtils::  ,$self,
# 			      \&BuildSystem::TagUtils::  ,$self);
 
   return $self->{simpledoc};
   }

sub parse()
   {
   my $self=shift;
   my ($filename)=@_;

   $self->{simpledoc}=$self->_initparser();
   $self->{simpledoc}->filetoparse($filename);
   $self->{simpledoc}->parse("builder");
   
   # We're done with the SimpleDoc object so delete it:
   delete $self->{simpledoc};
   }

sub _initbranchparser()
   {
   my $self=shift;

   $self->{simpledoc}=ActiveDoc::SimpleDoc->new();
   $self->{simpledoc}->newparse("branchbuilder");
   $self->{simpledoc}->addignoretags("branchbuilder");

   # For blank lines do nothing:
   $self->{simpledoc}->addtag("branchbuilder","none",
			      "", $self,
			      "", $self,
			      "", $self);
   
   # Define the tags to be used in this class:
   $self->{simpledoc}->addtag("branchbuilder","productstore",
			      \&BuildSystem::TagUtils::productstoretagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("branchbuilder","architecture",
			      \&BuildSystem::TagUtils::archtagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::archtagClose, $self);

   $self->{simpledoc}->addtag("branchbuilder","include_path",
			      \&BuildSystem::TagUtils::includetagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("branchbuilder","export",
			      \&BuildSystem::TagUtils::exporttagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::exporttagClose, $self);

   $self->{simpledoc}->addtag("branchbuilder","define_group",
			      \&BuildSystem::TagUtils::groupdeftagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::groupdeftagClose, $self);
   
   $self->{simpledoc}->addtag("branchbuilder","group",
			      \&BuildSystem::TagUtils::grouptagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("branchbuilder","lib",
			      \&BuildSystem::TagUtils::libtagOpen, $self,
			      "", $self,
			      "", $self);

   $self->{simpledoc}->addtag("branchbuilder","use",
			      \&BuildSystem::TagUtils::usetagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("branchbuilder","libtype",
			      \&BuildSystem::TagUtils::libtypetagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("branchbuilder","makefile",
			      \&BuildSystem::TagUtils::makefiletagOpen, $self,
			      \&BuildSystem::TagUtils::makefiletagContent, $self,
			      \&BuildSystem::TagUtils::makefiletagClose, $self);

   $self->{simpledoc}->addtag("branchbuilder","flags",
			      \&BuildSystem::TagUtils::flagstagOpen, $self,
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("branchbuilder","bin",
			      \&BuildSystem::TagUtils::binarytagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::binarytagClose, $self);
   
   $self->{simpledoc}->addtag("branchbuilder","module",
			      \&BuildSystem::TagUtils::moduletagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::moduletagClose, $self);
   
   $self->{simpledoc}->addtag("branchbuilder","application",
			      \&BuildSystem::TagUtils::applicationtagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::applicationtagClose, $self);

   $self->{simpledoc}->addtag("branchbuilder","library",
			      \&BuildSystem::TagUtils::librarytagOpen, $self,
			      "", $self,
			      \&BuildSystem::TagUtils::librarytagClose, $self);
   
   return $self->{simpledoc};
   }

sub parsebranchfiles()
   {
   my $self=shift;
   my ($filenames)=@_; # array ref
   # List of buildfiles:
   $self->{localpaths}=$filenames;
   $self->{simpledoc}=$self->_initbranchparser();
   # We iterate over an array of files to be read in turn: all
   # build data will be stored in the same BuildFile object:
   $self->{simpledoc}->parsefilelist("branchbuilder",$filenames);
   # We're done with the SimpleDoc object so delete it:
   delete $self->{simpledoc};
   }

sub productcollector()
   {
   my $self=shift;
   my ($name,$typeshort,$typefull)=@_;
   # Create a new Product object for storage of data:
   use BuildSystem::Product;
   my $product = BuildSystem::Product->new();
   # Store the name:
   $product->name($name);
   $product->type($typeshort);
   # Store the files:
   $product->_files($self->{id}->{'file'},$self->{localpaths});
   # Store the data content:
   $product->_data($self->{tagcontent});
   # And store in a hash (all build products in same place):
   $self->{content}->{BUILDPRODUCTS}->{$typefull}->{$name} = $product;
   }

sub pushlevel
   {
   my $self = shift;
   my ($info)=@_;
   
   $self->{id} = $info if (defined $info);
   $self->{nested} = 1;
   $self->{tagcontent}={};
   }

sub poplevel
   {
   my $self = shift;
   delete $self->{id};
   delete $self->{nested};
   delete $self->{tagcontent};
   }

sub dependencies()
   {
   my $self=shift;
   # Make a copy of the variable so that
   # we don't have a DEPENDENCIES entry in RAWDATA:
   my %DEPS=%{$self->{DEPENDENCIES}};
   delete $self->{DEPENDENCIES};
   return \%DEPS;
   }

#
# All data access methods are inherited from BuildDataUtils.
#
1;
