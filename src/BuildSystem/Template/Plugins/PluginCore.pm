#____________________________________________________________________ 
# File: PluginCore.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-04-29 16:07:07+0200
# Revision: $Id: PluginCore.pm,v 1.1.2.7 2004/11/18 13:01:25 sashby Exp $ 
#
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::Template::Plugins::PluginCore;
use vars qw( @ISA );
use base qw(Template::Plugin);
use Template::Plugin;
use Exporter;
@ISA=qw(Exporter);

##################
sub load()
   ###############################################################
   # load()                                                      #
   ###############################################################
   # modified : Thu Feb 26 12:36:07 2004 / SFA                   #
   # params   :                                                  #
   #          :                                                  #
   # function :                                                  #
   #          :                                                  #
   ###############################################################
   {
   my ($class, $context) = @_;
   return $class;
   }

sub new()
   ###############################################################
   # new()                                                       #
   ###############################################################
   # modified : Thu Apr 29 16:07:56 2004 / SFA                   #
   # params   :                                                  #
   #          :                                                  #
   # function :                                                  #
   #          :                                                  #
   ###############################################################
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   my $self =
      {
      _CONTEXT => shift
      };
   
   bless $self,$class;
   
   # Store data:
   $self->{_BRANCH} = $self->{_CONTEXT}->stash()->get('branch');
   
   my $META = $self->{_BRANCH}->branchdata();
   
   # If there are build products, set them here:
   if (ref($META) ne 'BuildSystem::DataCollector')
      {
      # We have build products in a hash:
      $self->{_BUILDPRODUCTS} = $META;
      }
   else
      {
      # OK, normal DataCollector object:
      $self->{_META} = $META;
      }
   
   # Set the most commonly-used features:
   $self->{_CONTEXT}->stash()->set('safepath', $self->{_BRANCH}->safepath());
   $self->{_CONTEXT}->stash()->set('path', $self->{_BRANCH}->path());
   $self->{_CONTEXT}->stash()->set('suffix', $self->{_BRANCH}->suffix());
   $self->{_CONTEXT}->stash()->set('class', $self->{_BRANCH}->class());
   $self->{_CONTEXT}->stash()->set('classdir', $self->{_BRANCH}->classdir());
   
   return $self;
   }

sub variables()
   {
   my $self=shift;
   (defined $self->{_META}) ? return $self->{_META}->variables()
      : return "";
   }

sub name()
   {
   my $self=shift;
   return $self->{_BRANCH}->name();
   }

sub productname()
   {
   my $self=shift;
   (defined $self->{_THISCOREPRODUCT}) ? return $self->{_THISCOREPRODUCT}->name()
      : return "";
   }

sub productfiles()
   {
   my $self=shift;
   (defined $self->{_THISCOREPRODUCT}) ? return $self->{_THISCOREPRODUCT}->files()
      : return "";
   }

sub producttype()
   {
   my $self=shift;
   (defined $self->{_THISCOREPRODUCT}) ? return $self->{_THISCOREPRODUCT}->type()
      : return "";
   }

sub flags()
   {
   my $self=shift;
   my ($flag)=@_;
   my $localflags=$self->{_META}->allflags() if (defined $self->{_META});

   if (exists $localflags->{$flag})
      {
      return join(" ",$localflags->{$flag});  
      }
   return "";
   }  

sub allflags()
   {
   my $self=shift;
   return $self->{_META}->allflags(), if (defined($self->{_META}));
   }

sub allscramstores()
   {
   my $self=shift;
   return $self->{_META}->allscramstores(), if (defined($self->{_META}));
   }

sub data()
   {
   my $self=shift;
   my ($tag)=@_;   
   return $self->{_META}->data($tag), if (defined($self->{_META}));
   }

sub safesubdirs()
   {
   my $self=shift;
   return $self->{_BRANCH}->safesubdirs(), if (defined($self->{_BRANCH}));
   }

sub scramprojectbases()
   {
   my $self=shift;
   # This is needed at project level only:
   return $self->{_BRANCH}->scramprojectbases(), if (defined($self->{_BRANCH}));
   }

sub bfdeps()
   {
   my $self=shift;
   my $bf={};

   # BuildFiles the current product depends on:
   if (defined($self->{_BRANCH}))
      {
      my $metabf=$self->{_BRANCH}->metabf();
      map
	 {
	 $bf->{$_}=1;
	 } @$metabf;
      }

   return $bf;
   }
   
sub pkdeps()
   {
   my $self=shift;

   # Store dependent package rules:
   $self->{_PACKAGE_RULES} = [];
   # Convert the dependent packages into their rules. We must also append/prepend "src"
   # so that we generate the safe path for each dependent package:
   if (defined $self->{_META})
      {
      map
	 {
	 $_ =~ s|/|_|g;
	 push(@{$self->{_PACKAGE_RULES}},'src_'.$_.'_src');
	 } @{$self->{_META}->local_package_deps()};
      return join(" ",@{$self->{_PACKAGE_RULES}});
      }
   else
      {
      return "";
      }
   }

# Build products:
sub buildproducts()
   {
   my $self=shift;
   return $self->{_BUILDPRODUCTS};
   }

# Set the data for current product object:
sub thisproductdata()
   {
   my $self=shift;
   my ($safename)=@_;
   # The name arg is used to switch to the correct data object
   # _THISCOREPRODUCT points to the Product object:
   $self->{_THISCOREPRODUCT} = $self->{_BUILDPRODUCTS}->{$safename};
   # We obtain the data using the Product::data() method:
   $self->{_META} = $self->{_THISCOREPRODUCT}->data(); # 
   }

1;
