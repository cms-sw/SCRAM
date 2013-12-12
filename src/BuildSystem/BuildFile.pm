#____________________________________________________________________ 
# File: BuildFile.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
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
   $self->{scramdoc}->newparse("builder",__PACKAGE__,'Subs',shift);
   return $self;
   }

sub parse()
   {
   my $self=shift;
   my ($filename)=@_;
   my $fhead='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><doc type="BuildSystem::BuildFile" version="1.0">';
   my $ftail='</doc>';
   $self->{scramdoc}->filetoparse($filename);
   $self->{archs}=[];
   $self->{archflag}=1;
   $self->{filetoparse}=$filename;
   $self->{scramdoc}->parse("builder",$fhead,$ftail);
   # We're done with the SimpleDoc object so delete it:
   delete $self->{filetoparse};
   delete $self->{scramdoc};
   delete $self->{archs};
   delete $self->{archflag};
   }

sub classpath()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      return $self->{content}->{CLASSPATH};
      }
   if (!$self->{archflag}){return;}
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
   if (!$self->{archflag}){return;}
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
   if (!$self->{archflag}){return;}
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
      if (!$self->{archflag}){return;}
      my ($name,%attributes)=@_;
      $self->{DEPENDENCIES}->{$attributes{'name'}} = 1;
      $self->{nested} == 1 ? push(@{$self->{tagcontent}->{USE}}, $attributes{'name'})
	 : push(@{$self->{content}->{USE}}, $attributes{'name'});
      }
   }

sub architecture()
   {
   my ($object,$name,%attributes)=@_;
   my $flag=$self->{archflag};
   push @{$self->{archs}},$flag;
   my $arch=$attributes{name};
   if (($flag) && ($ENV{SCRAM_ARCH}!~/$arch/)){$self->{archflag}=0;}
   }

sub architecture_()
   {
   my ($object,$name,%attributes)=@_;
   $self->{archflag}=pop @{$self->{archs}};
   }

sub export()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{archflag}){return;}
   $self->pushlevel(); # Set nested to 1;
   }

sub export_()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{archflag}){return;}
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
   if (!$self->{archflag}){return;}
   my $libname = $attributes{'name'};
   # We have a libname, add it to the list:
   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{LIB}}, $libname)
      : push(@{$self->{content}->{LIB}}, $libname);
   }

sub makefile()
   {
   my ($object,$name,%attributes)=@_;
   # The getter part:
   if (ref($object) eq __PACKAGE__)
      {
      return $self->{content}->{MAKEFILE};
      }
   }

sub makefile_()
   {
   my ($object,$name,$cdata)=@_;
   if (!$self->{archflag}){return;}
   $self->{nested} == 1 ? push(@{$self->{tagcontent}->{MAKEFILE}}, join("\n",@$cdata))
      : push(@{$self->{content}->{MAKEFILE}}, join("\n",@$cdata));
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
   if (!$self->{archflag}){return;}
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

sub bin()
   {
   my ($object,$name,%attributes) = @_;
   if (!$self->{archflag}){return;}
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub bin_()
   {
   my ($object,$name,%attributes) = @_;
   if (!$self->{archflag}){return;}
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

sub library()
   {
   my ($object,$name,%attributes) = @_;
   if (!$self->{archflag}){return;}
   $self->pushlevel(\%attributes);# Set nested to 1;
   }

sub library_()
   {
   my ($object,$name,%attributes) = @_;
   if (!$self->{archflag}){return;}
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

sub productcollector()
   {
   my $self=shift;
   my ($name,$typeshort,$typefull)=@_;
   # Create a new Product object for storage of data:
   use BuildSystem::Product;
   my $product = BuildSystem::Product->new();
   my @err=();
   foreach my $attrib (sort keys %{$self->{id}})
   {
     if ($attrib!~/^(file|name)$/){push @err,"Unknown attribute $attrib found.";}
   }
   if (!exists $self->{id}->{'file'}){push @err,"Missing file='files' attribute";}
   if (scalar(@err)>0){$self->{tagcontent}->{ERRORS}=\@err;}
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
   my $buildtags=[ qw(BIN LIBRARY BUILDPRODUCTS) ];
   my $skiptags=[ qw(ARCH EXPORT USE CLASSPATH) ];
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
