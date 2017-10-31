#____________________________________________________________________ 
# File: ToolData.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Copyright: 2003 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::ToolData;
require 5.004;

use Exporter;

@ISA=qw(Exporter);
#
sub new
  ###############################################################
  # new                                                         #
  ###############################################################
  # modified : Fri Nov 21 15:26:14 2003 / SFA                   #
  # params   :                                                  #
  #          :                                                  #
  # function :                                                  #
  #          :                                                  #
  ###############################################################
  {
  my $proto=shift;
  my $class=ref($proto) || $proto;
  my $self={SCRAM_PROJECT => 0};
  bless $self,$class;
  return $self;
  }

sub toolname()
   {
   my $self=shift;
   @_ ? $self->{TOOLNAME} = shift
      : $self->{TOOLNAME};
   }

sub toolversion()
   {
   my $self=shift;
   @_ ? $self->{TOOLVERSION} = shift
      : $self->{TOOLVERSION};
   }

sub tool_tag_value()
   {
   my $self=shift;
   my $tag=shift;
   @_ ? push(@{$self->{$tag}},@{$_[0]})
      : @{$self->{$tag}};
   }

sub lib()
   {
   my $self=shift;
   # Add libs to array:
   @_ ? push(@{$self->{LIB}},@{$_[0]})
      : @{$self->{LIB}};
   }

sub include()
   {
   my $self=shift;
   # Add include to array:
   @_ ? push(@{$self->{INCLUDE}},@{$_[0]})
      : @{$self->{INCLUDE}};
   }

sub libdir()
   {
   my $self=shift;
   # Add libdir to array:
   @_ ? push(@{$self->{LIBDIR}},@{$_[0]})
      : @{$self->{LIBDIR}};
   }

sub use()
   {
   my $self=shift;
   # Add deps to array:
   @_ ? push(@{$self->{USE}},@{$_[0]})
      : @{$self->{USE}};
   }

sub makefile()
   {
   my $self=shift;
   @_ ? push(@{$self->{MAKEFILE}},@{$_[0]})
      : @{$self->{MAKEFILE}};
   }

sub flags()
   {
   my $self=shift;
   my ($flag,$flagvalue) = @_;

   if ($flag && $flagvalue)
      {
      if (exists ($self->{FLAGS}->{$flag}))
	 {
	 # Add each flag ONLY if it doesn't already exist:
	 foreach my $F (@$flagvalue)
	    {
	    push(@{$self->{FLAGS}->{$flag}},$F),
	    if (! grep($F eq $_,@{$self->{FLAGS}->{$flag}}));
	    }
	 }
      else
	 {
	 $self->{FLAGS}->{$flag} = [ @$flagvalue ];
	 }
      }
   elsif ($flag && $self->{FLAGS}->{$flag}->[0] ne '')
      {
      return @{$self->{FLAGS}->{$flag}};
      }
   else
      {
      return "";
      }
   }

sub updateflags()
   {
   my $self=shift;
   my ($flag,$flagvalue) = @_;
   # Reset:
   if (exists $self->{FLAGS}->{$flag})
      {
      delete $self->{FLAGS}->{$flag};
      }
   # Reinsert:
   $self->flags($flag,$flagvalue);
   }

sub allflags()
   {
   my $self=shift;
   (scalar(keys %{$self->{FLAGS}}) > 0) ? return $self->{FLAGS} : return undef;
   }

sub scram_project()
   {
   my $self=shift;
   @_ ? $self->{SCRAM_PROJECT} = shift
      : $self->{SCRAM_PROJECT};
   }

sub scram_compiler()
   {
   my $self=shift;
   @_ ? $self->{SCRAM_COMPILER} = shift
      : $self->{SCRAM_COMPILER};
   }

sub variable_data()
   {
   my $self=shift;
   my ($varname,$varvalue) = @_;
   
   if ($varname && $varvalue)
      {
      $self->{$varname} = $varvalue; # Maybe need to handle more than one value?
      # Keep track of all variables:
      if (! grep($varname eq $_, @{$self->{VARIABLES}}))# Remove duplicates!!
	 {
	 push(@{$self->{VARIABLES}},$varname);	    
	 }
      }
   else
      {
      return $self->{$varname};
      }
   }

sub list_variables
   {
   my $self=shift;
   return @{$self->{VARIABLES}};
   }

sub runtime()
   {
   my $self=shift;
   my ($rt,$rtvalue) = @_;

   # If both a runtime name and value are supplied, store this variable:
   if ($rt && $rtvalue)
      {
      # Check to see if the environment already exists:
      if (exists ($self->{RUNTIME}->{$rt}))
	 {
	 push(@{$self->{RUNTIME}->{$rt}},@$rtvalue);
	 }
      else
	 {
	 # Doesn't already exist so just set the value, in an array:
	 $self->{RUNTIME}->{$rt} = [ @$rtvalue ];
	 }
      }
   elsif ($rt)
      {
      # Return the value for this runtime var name:
      return $self->{RUNTIME}->{$rt};
      }
   else
      {
      # Return all RT settings:
      return $self->{RUNTIME};
      }
   }

sub getfeatures()
   {
   my $self=shift;
   my ($feature)=@_;
   my @feature_vars=$self->list_variables();
   my @features;
   push (@features, @feature_vars, qw(LIB LIBDIR INCLUDE MAKEFILE USE));

   # Make sure feature name is uppercase:
   $feature =~ tr/a-z/A-Z/;
   if ($feature) # A feature name was given
      {
      # Check to see if this feature is valid and is defined for this tool:
      if (grep($feature eq $_, @features) && exists($self->{$feature}))
	 {
	 (ref($self->{$feature}) eq 'ARRAY') ? print join(" ",@{$self->{$feature}})
	    : print join(" ",$self->{$feature});
	 print "\n";
	 }
      else
	 {
	 # This feature isn't a valid feature or is valid but doens't
	 # have a value for this tool:
	 print "SCRAM: No type of variable called \"",$feature,"\" ","defined for this tool.\n";
	 }
      }
   else
      {
      # No feature name so dump list of valid features for current tool:
      map
	 {
	 print $_,"\n", if (exists ($self->{$_}));
	 } @features;
      }
   }

sub summarize_features()
   {
   my $self=shift;
   my @variables = $self->list_variables();

   # Show whether this tool is a SCRAM project or not:
   print "SCRAM_PROJECT=";
   ($self->scram_project() == 1) ? print "yes" : print "no";
   print "\n";

   # A compiler tool?
   if ($self->scram_compiler() == 1)
      {
      print "SCRAM_COMPILER=yes\n";
      }

   # Print out any variables:
   foreach my $var (@variables)
      {
      print $var,"=",$self->{$var},"\n";
      }

   # Makefile and flags first:
   if (exists($self->{'MAKEFILE'}) && $#{$self->{'MAKEFILE'}} != -1)
      {
      print join(" ",@{$self->{'MAKEFILE'}}),"\n\n";
      }

   if (exists($self->{'FLAGS'}) && (my ($nkeys) = scalar(keys %{$self->{'FLAGS'}}) > 0 ))
      {
      my $flags=$self->allflags();
      
      while (my ($f,$fv) = each %{$flags})
	 {
	 print $f,"+=",join(" ",@{$fv}),"\n";
	 }      
      }

   foreach my $feature (qw( LIB LIBDIR INCLUDE USE ))
      {
      if (exists($self->{$feature}) && $#{$self->{$feature}} != -1)
	 {
	 print $feature,"=",join(" ",@{$self->{$feature}}),"\n";
	 }
      }

   # Finally, look for runtime vars:
   if (exists($self->{'RUNTIME'}) && (my ($nkeys) = scalar(keys %{$self->{'RUNTIME'}}) > 0 ))
      {
      while (my ($rt,$val) = each %{$self->{'RUNTIME'}})
	 {
	 if ($rt =~ /:/)
	    {
	    my ($type,$name) = split(":",$rt);
	    print $name,"=",join(":",@$val),"\n";
	    }
	 else
	    {
	    print $rt,"=",join(":",@$val),"\n";
	    }
	 }
      }
   
   print "\n";
   }

   
sub addreleasetoself()
   {
   my $self=shift;
   # Go through the settings obtained so far (only from SELF) and, for
   # every LIBDIR/INCLUDE/RUNTIME path, add another value with
   # LOCALTOP==RELEASETOP:
   my $relldir = [];
   my $relinc = [];
   my @locallibdirs = $self->libdir();
   my @localincdirs = $self->include();
   
   foreach my $libdir (@locallibdirs)
      {
      # Convert LOCAL to RELEASE top, quoting the LOCALTOP
      # value in case funny characters have been used (e.g. ++):
      my $xlibdir = $libdir;
      $xlibdir =~ s/\Q$ENV{LOCALTOP}\E/$ENV{RELEASETOP}/g;
      if ($xlibdir ne $libdir){push(@$relldir, $xlibdir);}
      }
   
   # Add the new libdirs to our object:
   $self->libdir($relldir);
   
   foreach my $incdir (@localincdirs)
      {
      # Convert LOCAL to RELEASE top, quoting the LOCALTOP
      # value in case funny characters have been used (e.g. ++):
      my $xincdir = $incdir;
      $xincdir =~ s/\Q$ENV{LOCALTOP}\E/$ENV{RELEASETOP}/g;
      if ($xincdir ne $incdir){push(@$relinc, $xincdir);}
      }
   
   # Add the new libdirs to our object:
   $self->include($relinc);

   # Handle runtime settings:
   my $runtime=$self->runtime();
   
   while (my ($rt,$val) = each %{$runtime})
      {
      # Only handle anything that's a PATH:
      if ($rt =~ /:/)
	 {
	 my ($type,$name) = split(":",$rt);
	 
	 if ($type eq 'PATH')
	    {
	    my @PATHS=@$val;
	    my $RELPATHS=[];
	    
	    # Process the values for this path:
	    foreach my $rtpath (@PATHS)
	       {
	       my $x=$rtpath;
	       $x =~ s/\Q$ENV{LOCALTOP}\E/$ENV{RELEASETOP}/g;
	       if ($x ne $rtpath){push(@$RELPATHS,$x);}
	       }
	    
	    # Add the new settings:
	    $self->runtime($rt,$RELPATHS);
	    }
	 }
      }
   
   }

sub allfeatures()
   {
   my $self=shift;
   my @feature_vars=$self->list_variables();
   my @features;
   push (@features, @feature_vars, qw(LIB LIBDIR INCLUDE USE));   

   # Make sure feature name is uppercase:
   $feature =~ tr/a-z/A-Z/;
   $feature_data={};
   map
      {
      if (exists ($self->{$_}))
	 {
	 if (ref($self->{$_}) eq 'ARRAY')
	    {
	    $feature_data->{$_} = join(" ",@{$self->{$_}});
	    }
	 else
	    {
	    $feature_data->{$_} = $self->{$_}; # A string
	    }
	 }
      } @features;
   return $feature_data;
   }

sub reset()
   {
   my $self=shift;
   my ($entryname)=@_;

   if (exists($self->{$entryname}))
      {
      $self->{$entryname} = undef;
      }   
   }

1;
