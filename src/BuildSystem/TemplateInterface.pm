#____________________________________________________________________ 
# File: TemplateInterface.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-07-01 14:03:46+0200
# Revision: $Id: TemplateInterface.pm,v 1.6 2007/12/14 09:03:47 muzaffar Exp $ 
#
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::TemplateInterface;
require 5.004;
use Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw( );

sub new()
   ###############################################################
   # new                                                         #
   ###############################################################
   # modified : Thu Jul  1 14:04:01 2004 / SFA                   #
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

   # Process the environment hash and extract a
   # list of vars that are needed for building.
   # NB: This is done once only!
   my %exportenv;
   map
      {
      if ($_ =~ /^SCRAM/ || $_ =~ /(LOCAL|RELEASE)TOP$/)
	 {
	 $exportenv{$_} = $ENV{$_} if ($_ !~ /^SCRAMRT\_.*$/);
	 }
      } keys %ENV;
   
   # Add the environment information to the TEMPLATE_DATA hash:
   $self->{TEMPLATE_DATA} = { 'environment' => \%exportenv };

   # The filehandle for the generated Makefile:
   my $makefile="$ENV{LOCALTOP}/$ENV{SCRAM_INTwork}/Makefile";

   if (!-f $makefile)
      {
      if (!-f "$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/SCRAM/GMake/Makefile")
         {
	 die "Missing $ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/SCRAM/GMake/Makefile file.";
	 }
      use File::Copy;
      copy("$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/SCRAM/GMake/Makefile",$makefile) or die "Copy failed: $!";
      utime 0,0,$makefile;
      }

   # Init and pass in the template location:
   $self->_init(@_);
   return $self;
   }

sub _init()
   {
   my $self=shift;
   my ($templatedir)=@_;
   
   # Create the new Template object:
   $self->template_object();
   return $self;
   }

sub template_object()
   {
   my $self=shift;
   require SCRAM::Plugins::BuildRules;
   
   $self->{TEMPLATE_OBJECT} = SCRAM::Plugins::BuildRules->new();
   return $self;
   }

sub template_data()
   {
   my $self=shift;
   my ($data) = @_;

   # Set the things that we must set. The "data" key points
   # to a DataCollector object. The "branch" data is a
   # TreeItem object:
   $self->{TEMPLATE} = $data->template();
   # Add required data accessed by key:
   $self->{TEMPLATE_DATA}->{branch} = $data;
   }

sub run()
   {
   use FileHandle;
   my $self=shift;
   
   my $item = $self->{TEMPLATE_DATA}->{branch};
   my $file = $item->safepath().".mk";
   if ($item->class() eq "PROJECT")
      {
      $file = "$ENV{LOCALTOP}/.SCRAM/$ENV{SCRAM_ARCH}/MakeData/${file}";
      }
   elsif ($item->publictype())
      {
      $file = "$ENV{LOCALTOP}/.SCRAM/$ENV{SCRAM_ARCH}/MakeData/DirCache/${file}";
      $item->{MKDIR}{"$ENV{LOCALTOP}/.SCRAM/$ENV{SCRAM_ARCH}/MakeData/DirCache"}=1;
      }
   else
      {
      $file = "$ENV{LOCALTOP}/$ENV{SCRAM_INTwork}/MakeData/DirCache/${file}";
      $item->{MKDIR}{"$ENV{LOCALTOP}/$ENV{SCRAM_INTwork}/MakeData/DirCache"}=1;
      }

   $self->{MAKEFILEFH} = FileHandle->new();
   $self->{MAKEFILEFH}->open(">$file");
   local *FH = $self->{MAKEFILEFH};
   
   $self->{TEMPLATE_OBJECT}->process($self->{TEMPLATE},
				     $self->{TEMPLATE_DATA},
				     $self->{MAKEFILEFH} )
      || die "SCRAM: Template error --> ",$self->{TEMPLATE_OBJECT}->error;
   
   $self->{MAKEFILEFH}->close();
   }

1;
