#____________________________________________________________________ 
# File: BuildSystem::ToolSettingValidator.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-10-14 10:16:21+0200
# Revision: $Id: ToolSettingValidator.pm,v 1.5.2.1 2008/02/15 14:58:01 muzaffar Exp $ 
#
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
  my ($environments,$toolname,$interactive) = @_;

  $self->{TOOLNAME}    = $toolname;
  $self->{ENVIRONMENT} = $environments->{ENVIRONMENT};
  $self->{RUNTIME}     = $environments->{RUNTIME};
  $self->{VARDATA}     = {}; # Somewhere to store the variables
  $self->{LOCALENV}    = \%ENV;
  $self->{STATUS}      = { 0 => $main::good."[OK]".$main::normal, 1 => $main::error."[FAIL]".$main::normal, 2 => $main::good."[OK (but currently missing)]".$main::normal };
  $self->{INVALIDPATHERRORMSG} = $main::error."Invalid path...please try again!".$main::normal;

  # Are we interactive or not?
  $self->{INTERACTIVE} = $interactive;
  
  bless $self,$class;
  return $self;
  }

sub findvalue()
   {
   my $self=shift;
   my ($name, $data) = @_;
   my $stringtoeval;
   my $path;

   # We pass in this var to checdefaults(). The data (hash) used in the
   # path checking may contain a key 'handler': if this is set to 'warnonly', we
   # don't prompt for this path setting if it happens to be incorrect:
   my $handlertype;
   
   # See if there's a default/value in our data element:
   if ($self->checkdefaults($data,\$stringtoeval,\$handlertype))
      {
      # OK, there's a def/val. 
      $path = $self->_expandvars($stringtoeval);

      if ($self->validatepath($path,$handlertype) )
	 {
	 # Save in VARDATA:
	 $self->savevalue($name,$path);
	 }
      else
	 {
	 # Prompt user for a value:
	 $path = $self->promptuser($name);		    
	 }		 
      }
   else
      {
      # Path was invalid. Fall back to prompting:
      $path = $self->promptuser($name);
      }
   
   # Return the path:
   return $path;
   }

sub ifindvalue()
   {
   my $self=shift;
   my ($name, $data) = @_;
   my $stringtoeval;
   my ($dpath,$path);
   # We pass in this var to checdefaults(). The data (hash) used in the
   # path checking may contain a key 'handler': if this is set to 'warnonly', we
   # don't prompt for this path setting if it happens to be incorrect:
   my $handlertype;

   # See if there's a default/value in our data element:
   if ($self->checkdefaults($data,\$stringtoeval,\$handlertype))
      {
      # OK, there's a def/val. 
      $dpath = $self->_expandvars($stringtoeval);
      
      if ($self->validatepath($dpath,$handlertype))
	 {
	 $path = $self->promptuser($name,$dpath);
	 # Save in VARDATA:
	 $self->savevalue($name, $path);
	 }
      else
	 {
	 # Prompt user for a value:
	 $path = $self->promptuser($name);
	 }		 
      }
   else
      {      
      # Path was invalid. Fall back to prompting:
      $path = $self->promptuser($name);
      }
   
   # Return the path:
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
	 # Return the tag data:
	 return $self->{uc($type)}->{$varname};
	 }
      else
	 {
	 # No tag data so return 0:
	 return 0;
	 }
      }
   elsif ($type)
      {
      # Return all environments of type $type:
      return $self->{uc($type)};
      }
   else
      {
      print "SCRAM: Unknown tag type/var name","\n";
      }
   }

sub validatepath()
   {
   my $self = shift;
   my ($pathvalue,$handlertype) = @_;
   my $path;

   # Either we use the pathvalue supplied or
   # we use PATHFROMDB:
   if ($pathvalue)
      {
      $path = $pathvalue;
      }
   else
      {
      $path = $self->{PATHFROMDB};
      }
   
   scramlogmsg("\tChecks "), if ($path);

   if ( -f $path)
      {
      # File exists:
      scramlogmsg($self->{STATUS}->{0}." for $path","\n");
      return 1;
      }
   # This is done so that some paths can be added which include ".":
   elsif ($path =~ /^\.:.*/ || $path =~ /^\.$/)
      {
      scramlogmsg($self->{STATUS}->{0}." for $path","\n");
      return 1;
      }
   elsif ($handlertype =~ /^[Ww].*$/)
      {
      scramlogmsg($self->{STATUS}->{2}." for $path","\n");
      return 1;
      }
   else
      {
      use DirHandle;
      my $dh = DirHandle->new();
      
      opendir $dh, $path or do
	 {
	 # No path:
	 scramlogmsg($self->{STATUS}->{1}." for $path","\n"), unless ($path eq '');
	 return 0;
	 };
      
      # Dir found:
      scramlogmsg($self->{STATUS}->{0}." for $path","\n");
      return 1;
      }
   }

sub checkdefaults()
   {
   my $self=shift;
   my ($vardata,$pathtoevalref,$handlertyperef) = @_;

   # If $vardata is actually an array (which it will
   # be if there is more than one VAR element), dereference
   # to get only the first hash entry (this is fine as the
   # block of code to handle nmore than one element will loop
   # over all elements of the array so that a hash is passed
   # to this routine:
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
   
   if (exists($data->{'default'}))
      {
      $$pathtoevalref = $data->{'default'};
      }
   elsif (exists($data->{'value'}))
      {
      $$pathtoevalref = $data->{'value'};
      }
   else
      {
      # No value or default. Return 0:
      return 0;
      }

   return 1;
   }

sub pathfromdb()
   {
   my $self=shift;
   return $self->{PATHFROMDB};
   }

sub checkDB()
   {
   my $self = shift;
   my ($varname) = @_;
   
   if ($::lookupdb->checkTool($self->{TOOLNAME}))
      {
      $pathfromdb = $::lookupdb->lookupTag($self->{TOOLNAME}, $varname);

      if ($pathfromdb ne "")
	 {
	 $self->{PATHFROMDB} = $pathfromdb;
	 return 1;
	 }
      else
	 {
	 return 0;     
	 }
      }
   else
      {
      return 0;
      }
   }

sub _expandvars()
   {
   my $self=shift;
   my ($string) = @_;
   
   return "" , if ( ! defined $string );
   
   # To evaluate variables in brackets, like $(X):
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
   
   # To evaluate variables like $X:
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

   # Now return false if the string wasn't properly evaluated (i.e. some $ remain), otherwise
   # return the expanded string:
   ($string =~ /\$/) ? return undef : return $string;
   }

sub promptuser()
   {
   my $self=shift;
   my ($varname, $default)=@_;
   my $pathvalue;
   my $novalid = 1;
   my $dummy = '';
   my $ORKEEP = '';
   scramlogdump();
   scramloginteractive(1);
   print "\n";

   while ($novalid)
      {
      if ($self->interactive())
	 {
	 # Only mention the default stuff if default actually has
	 # a value. It might not (e.g., in the case of a new tool)
	 if ($default ne '')
	    {
	    print "Default value is $default","\n", unless ($default eq '');
	    $ORKEEP=' (or <ret> to keep)';
	    }

	 print "\n";
	 print $main::prompt."Please Enter a Value$ORKEEP: > ".$main::normal;

	 $dummy = <STDIN>;
	 chomp($dummy);
	 # If we have an empty string, return the default value:
	 if ($dummy eq '' && $default ne '')
	    {
	    return $default;
	    }
	 print "\n"
	 }
      else
	 {
	 print "\n";
	 print $main::prompt."Please Enter a Value: > ".$main::normal;
	 $dummy = <STDIN>;
	 chomp($dummy);
	 }
      
      print "\n";
      # Also use _expandvars() here so that env variables
      # can be used:

      $pathvalue=$self->_expandvars($dummy);
      if ($self->validatepath($pathvalue,"")) # No handler here;
	 {
	 $novalid = 0;
	 $self->{VARDATA}->{$varname} = $pathvalue;
	 }
      else
	 {
	 print $self->{INVALIDPATHERRORMSG},"\n";
         if ((!-t STDIN) || (!-t STDOUT))
            {   
            print "ERROR: SCRAM does not allow to prompt for user input when running in batch mode.\n",
                  "       In batch mode all the tool files and site/tools.conf should provide the\n",
                  "       values needed to setup a tool properly.\n";
            exit 1;
            }
	 }
      }
   
   # Return the path:
   return $pathvalue;
   }

sub interactive()
   {
   my $self=shift;
   return $self->{INTERACTIVE};
   }

sub promptuserforvar()
   {
   my $self=shift;
   my ($varname, $default)=@_;
   my $value;
   my $novalid = 1;
   my $dummy = '';
   my $ORKEEP = '';
   scramlogdump();
   scramloginteractive(1);
   print "\n";

   while ($novalid)
      {
      if ($self->interactive())
	 {
	 # Only mention the default stuff if default actually has
	 # a value. It might not (e.g., in the case of a new tool)
	 if ($default ne '')
	    {
	    print "Default value for $varname is $default","\n", unless ($default eq '');
	    $ORKEEP=' (or <ret> to keep)';
	    }
	 
	 print "\n";
	 print $main::prompt."Please Enter a Value$ORKEEP: > ".$main::normal;
	 $dummy = <STDIN>;
	 chomp($dummy);	 
	 # If we have an empty string, set to the default value:
	 if ($dummy eq '')
	    {
	    $dummy = $default;
	    }
	 
	 print "\n";
	 }
      else
	 {
	 print "\n";
	 print $main::prompt."Please Enter a Value: > ".$main::normal;
	 $dummy = <STDIN>;
	 chomp($dummy);
	 }

      print "\n";
      # Also use _expandvars() here so that env variables
      # can be used:
      $value = $self->_expandvars($dummy);
      print "Runtime variable ",$varname," set to \"",$value,"\"\n";
      $novalid = 0;
      }
   
   # Return the path:
   return $value;
   }

1;
