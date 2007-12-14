#____________________________________________________________________ 
# File: BuildFile.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2003-12-03 19:03:15+0100
# Revision: $Id: BuildFile.pm,v 1.29.4.5 2007/11/08 15:25:27 muzaffar Exp $ 
#
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::BuildFile;
require 5.004;
use Exporter;
use ActiveDoc::SimpleDoc;

@ISA=qw(Exporter);
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
   $self={};
   bless $self,$class;
   $self->{DEPENDENCIES} = {};
   $self->{content} = {};
   $self->{scramdoc}=ActiveDoc::SimpleDoc->new();
   $self->{scramdoc}->newparse("builder",__PACKAGE__,'Subs');
   return $self;
   }

sub parse()
   {
   my $self=shift;
   my ($filename)=@_;
   my $fhead='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><doc type="BuildSystem::BuildFile" version="1.0">';
   my $ftail='</doc>';
   $self->{scramdoc}->filetoparse($filename);
   $self->{scramdoc}->parse("builder",$fhead,$ftail);
   # We're done with the SimpleDoc object so delete it:
   delete $self->{scramdoc};
   }

sub classpath()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      return $self->{content}->{CLASSPATH};
      }
   
   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{CLASSPATH}}, $attributes{'path'})
      : push(@{$self->{content}->{CLASSPATH}}, $attributes{'path'});
   }

sub productstore()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      # Return an array of ProductStore hashes:
      return $self->{content}->{PRODUCTSTORE};
      }
   
   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{PRODUCTSTORE}}, \%attributes)
      : push(@{$self->{content}->{PRODUCTSTORE}}, \%attributes) ;
   }

sub include()
   {
   my $self=shift;
   # Return an array of required includes:
   return $self->{content}->{INCLUDE};
   }

sub include_path()
   {
   my ($object,$name,%attributes)=@_;
   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{INCLUDE}}, $attributes{'path'})
      : push(@{$self->{content}->{INCLUDE}}, $attributes{'path'});
   }

sub use()
   {
   my $object=shift;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      # Add or return uses (package deps):
      @_ ? push(@{$self->{content}->{USE}},@_)
	 : @{$self->{content}->{USE}};
      }
   else
      {
      my ($name,%attributes)=@_;
      $self->{DEPENDENCIES}->{$attributes{'name'}} = 1;
      $self->{nested} == 1 ? push(@{$self->{tagcontent}->{USE}}, $attributes{'name'})
	 : push(@{$self->{content}->{USE}}, $attributes{'name'});
      }
   }

sub architecture()
   {
   my ($object,$name,%attributes)=@_;
   $self->pushlevel(\%attributes); # Set nested to 1;
   }

sub architecture_()
   {
   $self->{content}->{ARCH}->{$self->{id}->{'name'}}=$self->{tagcontent};
   $self->poplevel();
   }

sub export()
   {
   $self->pushlevel(); # Set nested to 1;
   }

sub export_()
   {
   $self->{content}->{EXPORT} = $self->{tagcontent};
   $self->poplevel();
   }

sub lib()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      # Return an array of required libs:
      return $self->{content}->{LIB};      
      }
   
   my $libname;
   
   if (exists($attributes{'position'}))
      {
      if ($attributes{'position'} eq 'first')
	 {
	 $libname = "F:".$attributes{'name'};
	 }
      else
	 {
	 # There was a position entry but it didn't make sense:
	 $libname = $attributes{'name'};
	 }
      }
   else
      {
      $libname = $attributes{'name'};
      }
   # We have a libname, add it to the list:
   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{LIB}}, $libname)
      : push(@{$self->{content}->{LIB}}, $libname);
   }

sub libtype()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      # Return an array of required libs:
      return $self->{content}->{LIBTYPE};      
      }

   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{LIBTYPE}}, $attributes{'type'})
      : push(@{$self->{content}->{LIBTYPE}}, $attributes{'type'});
   }

sub skip()
   {
   my ($object,$name,%attributes)=@_;
   $self->{nested} == 1 ? $self->{tagcontent}->{SKIPPEDDIRS} = [ 1 ]
      : $self->{content}->{SKIPPEDDIRS} = [ 1 ];
   }

sub skip_message()
   {
   my ($object,$name,@message) = @_;
   # Save any message text between <skip> tags:
   if ($#message > -1)
      {
      $self->{nested} == 1 ? push(@{$self->{tagcontent}->{SKIPPEDDIRS}}, [ @message ])
	 : push(@{$self->{content}->{SKIPPEDDIRS}}, [ @message ]);
      }
   }

sub skip_()
   {
   my ($object,$name)=@_;
   }

sub makefile()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      # Return Makefile content:
      return $self->{content}->{MAKEFILE};
      }
   
   # Set our own Char handler so we can collect the content
   # of the Makefile tag:
   $object->setHandlers(Char => \&makefile_content);
   $self->{makefilecontent} = [];
   }

sub makefile_content()
   {
   my ($object, @strings) = @_;
   foreach my $str (@strings)
      {
      push(@{$self->{makefilecontent}},$str);
      }
   }

sub makefile_()
   {
   my ($object,$name)=@_;
   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{MAKEFILE}}, join("\n",@{$self->{makefilecontent}}))
      : push(@{$self->{content}->{MAKEFILE}}, join("\n",@{$self->{makefilecontent}}));
   delete $self->{makefilecontent};
   # Unset the Char handler to revert to the default behaviour:
   $object->setHandlers(Char => 0);
   }

sub define_group()
   {
   my ($object,$name,%attributes)=@_;
   $self->pushlevel(\%attributes); # Set nested to 1;
   }

sub define_group_()
   {
   $self->{content}->{DEFINED_GROUP}->{$self->{id}->{'name'}}=$self->{tagcontent};
   $self->poplevel();
   }

sub group()
   {
   my $object=shift;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      # Add or return groups:
      @_ ? push(@{$self->{content}->{GROUP}},@_)
	 : @{$self->{content}->{GROUP}};
      }
   else
      {
      my ($name,%attributes)=@_;
      $self->{nested} == 1 ? push(@{$self->{tagcontent}->{GROUP}}, $attributes{'name'})
	 : push(@{$self->{content}->{GROUP}}, $attributes{'name'});
      }
   }

sub flags()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      # Return an array of ProductStore hashes:
      return $self->{content}->{FLAGS};
      }
   
   # Extract the flag name and its value:
   my ($flagname,$flagvaluestring) = each %attributes;
   $flagname =~ tr/[a-z]/[A-Z]/; # Keep flag name uppercase
   chomp($flagvaluestring);
   my @flagvalues = ( $flagvaluestring );
   # Is current tag within another tag block?
   if ($self->{nested} == 1)
      {
      # Check to see if the current flag name is already stored in the hash. If so,
      # just add the new values to the array of flag values:
      if (exists ($self->{tagcontent}->{FLAGS}->{$flagname}))
	 {
	 push(@{$self->{tagcontent}->{FLAGS}->{$flagname}},@flagvalues);
	 }
      else
	 {
	 $self->{tagcontent}->{FLAGS}->{$flagname} = [ @flagvalues ];
	 }
      }
   else
      {
      if (exists ($self->{content}->{FLAGS}->{$flagname}))
	 {
	 push(@{$self->{content}->{FLAGS}->{$flagname}},@flagvalues);
	 }
      else
	 {
	 $self->{content}->{FLAGS}->{$flagname} = [ @flagvalues ];
	 }
      }
   }

sub allflags()
   {
   my $self=shift;
   # Return hash data for flags:
   return $self->{content}->{FLAGS};
   }

sub archspecific()
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

sub bin()
   {
   my ($object,$name,%attributes) = @_;
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub bin_()
   {
   # Need unique name for the binary (always use name of product). Either use "name"
   # given, or use "file" value minus the ending:
   if (exists ($self->{id}->{'name'}))
      {
      $name = $self->{id}->{'name'};
      }
   else
      {
      ($name) = ($self->{id}->{'file'} =~ /(.*)?\..*$/);
      }

   # Store the data:
   $self->productcollector($name,'bin','BIN');
   $self->poplevel();
   }

sub module()
   {
   my ($object,$name,%attributes) = @_;
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub module_()
   {
   # Need unique name for the module (always use name of product). Either use "name"
   # given, or use "file" value minus the ending:
   if (exists ($self->{id}->{'name'}))
      {
      $name = $self->{id}->{'name'};
      }
   else
      {
      ($name) = ($self->{id}->{'file'} =~ /(.*)?\..*$/);
      }

   # Store the data:
   $self->productcollector($name,'mod','MODULE');
   $self->poplevel();
   }

sub application()
   {
   my ($object,$name,%attributes) = @_;
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub application_()
   {
   # Need unique name for the application (always use name of product). Either use "name"
   # given, or use "file" value minus the ending:
   if (exists ($self->{id}->{'name'}))
      {
      $name = $self->{id}->{'name'};
      }
   else
      {
      ($name) = ($self->{id}->{'file'} =~ /(.*)?\..*$/);
      }

   # Store the data:
   $self->productcollector($name,'app','APPLICATION');
   $self->poplevel();
   }

sub library()
   {
   my ($object,$name,%attributes) = @_;
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub library_()
   {
   # Need unique name for the library (always use name of product). Either use "name"
   # given, or use "file" value minus the ending:
   if (exists ($self->{id}->{'name'}))
      {
      $name = $self->{id}->{'name'};
      }
   else
      {
      ($name) = ($self->{id}->{'file'} =~ /(.*)?\..*$/);
      }

   # Store the data:
   $self->productcollector($name,'lib','LIBRARY');
   $self->poplevel();
   }

sub plugin()
   {
   my ($object,$name,%attributes) = @_;
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub plugin_()
   {
   # Need unique name for the plugin (always use name of product). Either use "name"
   # given, or use "file" value minus the ending:
   if (exists ($self->{id}->{'name'}))
      {
      $name = $self->{id}->{'name'};
      }
   else
      {
      ($name) = ($self->{id}->{'file'} =~ /(.*)?\..*$/);
      }

   # Store the data:
   $self->productcollector($name,'plugin','PLUGIN');
   $self->poplevel();
   }

sub unittest()
   {
   my ($object,$name,%attributes) = @_;
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub unittest_()
   {
   # Need unique name for the unittest (always use name of product). Either use "name"
   # given, or use "file" value minus the ending:
   if (exists ($self->{id}->{'name'}))
      {
      $name = $self->{id}->{'name'};
      }
   else
      {
      ($name) = ($self->{id}->{'file'} =~ /(.*)?\..*$/);
      }

   # Store the data:
   $self->productcollector($name,'unittest','unittest');
   $self->poplevel();
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
   # Store the files. Take the BuildFile path as the initial path for
   # expanding source file globs:
   $product->_files($self->{id}->{'file'},[ $self->{scramdoc}->filetoparse() ]);
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

sub skippeddirs()
   {
   my $self=shift;
   my ($here)=@_;
   my $skipped;

   if ($self->{content}->{SKIPPEDDIRS}->[0] == 1)
      {
      $skipped = [ @{$self->{content}->{SKIPPEDDIRS}} ];
      delete $self->{content}->{SKIPPEDDIRS};
      }
   
   delete $self->{content}->{SKIPPEDDIRS};
   return $skipped;
   }

sub hasexport()
   {
   my $self=shift;
   # Check to see if there is a valid export block:
   my $nkeys = $self->exporteddatatypes();
   $nkeys > 0 ? return 1 : return 0;
   }

sub has()
   {
   my $self=shift;
   my ($datatype)=@_;   
   (exists ($self->{content}->{$datatype})) ? return 1 : return 0;
   }

sub exported()
   {
   my $self=shift;
   # Return a hash. Keys are type of data provided:
   return ($self->{content}->{EXPORT});
   }

sub exporteddatatypes()
   {
   my $self=shift;
   # Return exported data types:
   return keys %{$self->{content}->{EXPORT}};
   }

sub defined_group()
   {
   my $self=shift;

   if (exists($self->{content}->{DEFINED_GROUP}))
      {   
      # Return a list of keys (group names) for defined groups:
      return [ keys %{$self->{content}->{DEFINED_GROUP}} ];
      }
   else
      {
      return 0;
      }
   }

sub dataforgroup()
   {
   my $self=shift;
   my ($groupname)=@_;
   # Return hash containing data for defined group
   # $groupname or return undef: 
   return $self->{content}->{DEFINED_GROUP}->{$groupname};
   }

sub buildproducts()
   {
   my $self=shift;
   # Returns hash of build products and their data:
   return $self->{content}->{BUILDPRODUCTS};
   }

sub values()
   {
   my $self=shift;
   my ($type)=@_;
   # Get a list of values from known types
   return $self->{content}->{BUILDPRODUCTS}->{$type};
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

sub clean()
   {
   my $self=shift;
   my (@tags) = @_;

   # Delete some useless entries:
   delete $self->{makefilecontent};
   delete $self->{simpledoc};
   delete $self->{id};
   delete $self->{tagcontent};
   delete $self->{nested};

   delete $self->{DEPENDENCIES};
   
   map
      {
      delete $self->{content}->{$_} if (exists($self->{content}->{$_}));
      } @tags;
   
   return $self;
   }

sub AUTOLOAD()
   {
   my ($xmlparser,$name,%attributes)=@_;
   return if $AUTOLOAD =~ /::DESTROY$/;
   my $name=$AUTOLOAD;
   $name =~ s/.*://;
   }

1;
