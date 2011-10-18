#____________________________________________________________________ 
# File: BuildSystem::ToolSettingValidator.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::ToolSettingValidator;
require 5.004;
use SCRAM::MsgLog;
use Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw( );

sub new()
  ###############################################################
  # new                                                         #
  ###############################################################
  # modified : Thu Oct 14 10:16:25 2004 / SFA                   #
  # params   :                                                  #
  #          :                                                  #
  # function :                                                  #
  #          :                                                  #
  ###############################################################
  {
  my $proto=shift;
  my $class=ref($proto) || $proto;
  my $self={};
  
  # Store the list of known environments:
  my ($environments,$toolname) = @_;

  $self->{TOOLNAME}    = $toolname;
  $self->{ENVIRONMENT} = $environments->{ENVIRONMENT};
  $self->{RUNTIME}     = $environments->{RUNTIME};
  $self->{VARDATA}     = {};
  $self->{LOCALENV}    = \%ENV;
  $self->{STATUS}      = { 0 => $main::good."[OK]".$main::normal, 1 => $main::error."[FAIL]".$main::normal, 2 => $main::good."[OK (but currently missing)]".$main::normal };

  bless $self,$class;
  return $self;
  }

sub findvalue()
   {
   my $self=shift;
   my ($name, $data) = @_;
   my $stringtoeval;
   my $path;

   my $handlertype;

   # See if there's a default/value in our data element:
   if ($self->checkdefaults($data,\$stringtoeval,\$handlertype))
      {
      $path = $self->_expandvars($stringtoeval);
      if ($self->validatepath($path,$handlertype) )
	 {
	 $self->savevalue($name,$path);
	 }
      else
	 {
	 $self->promptuser($name,$path);		    
	 }		 
      }
   else
      {
      $self->promptuser($name,$path);
      }
   return $path;
   }

sub savevalue()
   {
   my $self = shift;
   my ($varname, $path) = @_;

   if ($varname && $path)
      {
      $self->{VARDATA}->{$varname} = $path;
      }

   return;
   }

sub environment()
   {
   my $self = shift;
   my ($type, $varname) = @_;

   if ($type && $varname)
      {
      if (exists($self->{uc($type)}->{$varname}))
	 {
	 return $self->{uc($type)}->{$varname};
	 }
      else
	 {
	 return 0;
	 }
      }
   elsif ($type)
      {
      return $self->{uc($type)};
      }
   else
      {
      die "SCRAM: Unknown tag type/var name: $type/$varname\n";
      }
   }

sub validatepath()
   {
   my $self = shift;
   my ($path,$handlertype) = @_;
   scramlogmsg("\tChecks "), if ($path);

   # This is done so that some paths can be added which include ".":
   if (($path =~ /^\.:.*/ || $path =~ /^\.$/) || ( -f $path ) || (-d $path))
      {
      scramlogmsg($self->{STATUS}->{0}." for $path","\n");
      return 1;
      }
   elsif ($handlertype =~ /^[Ww].*$/)
      {
      scramlogmsg($self->{STATUS}->{2}." for $path","\n");
      return 1;
      }
   scramlogmsg($self->{STATUS}->{1}." for $path","\n"), unless ($path eq '');
   return 0;
   }

sub checkdefaults()
   {
   my $self=shift;
   my ($vardata,$pathtoevalref,$handlertyperef) = @_;

   if (ref($vardata) eq 'ARRAY')
      {
      $data = $vardata->[0];
      }
   else
      {
      $data = $vardata;
      }

   if (exists($data->{'handler'}))
      {
      $$handlertyperef = $data->{'handler'};
      }

   if (exists($data->{'value'}))
      {
      $$pathtoevalref = $data->{'value'};
      }
   elsif (exists($data->{'default'}))
      {
      $$pathtoevalref = $data->{'default'};
      }
   else
      {
      return 0;
      }

   return 1;
   }

sub _expandvars()
   {
   my $self=shift;
   my ($string) = @_;
   
   return "" , if ( ! defined $string );
   
   $string =~ s{\$\((\w+)\)}
      {
      if (defined $self->{VARDATA}->{$1})
	 {
	 $self->_expandvars($self->{VARDATA}->{$1});
	 }
      elsif (defined $self->{LOCALENV}->{$1})
	 {
	 $self->_expandvars($self->{LOCALENV}->{$1});
	 }
      else
	 {
	 "\$$1";
	 }
      }egx;
   
   $string =~ s{\$(\w+)}
      {
      if (defined $self->{VARDATA}->{$1})
	 {
	 $self->_expandvars($self->{VARDATA}->{$1});
	 }
      elsif (defined $self->{LOCALENV}->{$1})
	 {
	 $self->_expandvars($self->{LOCALENV}->{$1});
	 }
      else
	 {
	 "\$$1";
	 }
      }egx;

   ($string =~ /\$/) ? return undef : return $string;
   }

sub promptuser()
   {
   my ($self,$name,$path)=@_;
   if ($path) { print "**** ERROR: No such file or directory: $path\n"; }
   die "     SCRAM does not allow prompting for user input anymore.\n",
       "     Please fix the tool file for \"",$self->{TOOLNAME},"\" and provide a valid value for \"$name\".\n";
   }

1;
