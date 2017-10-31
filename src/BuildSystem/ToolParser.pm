#____________________________________________________________________ 
# File: ToolParser.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::ToolParser;
require 5.004;

use Exporter;
use SCRAM::MsgLog;
use ActiveDoc::SimpleDoc;
use Utilities::Verbose;

@ISA=qw(Exporter Utilities::Verbose);
@EXPORT=qw();

#
sub new
   {
   my $proto=shift;
   my $class=ref($proto) || $proto;
   $self={};
   
   bless $self,$class;
   $self->{path_variables}=shift || "";
   $self->{content} = {};
   $self->{nested} = 0;
   $self->{scramdoc}=ActiveDoc::SimpleDoc->new();
   $self->{scramdoc}->newparse("setup","BuildSystem::ToolParser",'Subs',undef,1);
   $self->{envorder}=[];
   return $self;
   }

### Tag handler methods ###
sub tool()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   my $hashref = \%attributes;   
   # A way to distinguish the naming of different nested levels:
   $self->{levels}=['','tag','nexttag'];
   $$hashref{'name'} =~ tr[A-Z][a-z];

   $self->{content}->{TOOLNAME}=$$hashref{'name'};
   $self->{content}->{TOOLVERSION}=$$hashref{'version'};
   $self->{scramdoc}->addfilter("ifversion",$$hashref{'version'});
   
   if (exists ($$hashref{'type'}))
      {
      $$hashref{'type'} =~ tr[A-Z][a-z];
      $self->{content}->{SCRAM_PROJECT} = 0;

      if ($$hashref{'type'} eq 'scram')
	 {
	 $self->{content}->{SCRAM_PROJECT} = 1;
	 }     
      elsif ($$hashref{'type'} eq 'compiler')
	 {
	 $self->{content}->{SCRAM_COMPILER} = 1;
	 }
      else
	 {
	 $::scram->scramwarn("Unknown type \"".$$hashref{'type'}."\" in tool ".$$hashref{'name'}."\n");
	 }
      }
   }

sub tool_()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   $self->{scramdoc}->removefilter("ifversion");
   delete $self->{levels};
   delete $self->{id};
   delete $self->{nested};
   }

sub lib()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   my $type="LIB";
   if (exists $attributes{'type'}){$type=uc($attributes{'type'})."_LIB";}
   my $content = $self->{levels}->[$self->{nested}]."content";
   push(@{$self->{$content}->{$type}},$attributes{'name'});
   if ($type ne "LIB")
     {
     if (!exists $self->{$content}->{LIBTYPES}){$self->{$content}->{LIBTYPES}={};}
     $self->{$content}->{LIBTYPES}->{$type}=1;
     }
   }

sub info()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   $self->{"$self->{levels}->[$self->{nested}]".content}->{INFO} = \%attributes;
   }

sub use()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   push(@{$self->{"$self->{levels}->[$self->{nested}]".content}->{USE}},$attributes{'name'});
   }

sub runtime()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   my $hashref = \%attributes;   
   my $envname = $hashref->{'name'}; $envname=~s/\s//g;
   my $pvar = $self->{path_variables};
   if (($pvar) && ($envname=~/$pvar/))
      {
      if (!exists ($hashref->{'type'})){$hashref->{'type'}="path";}
      }
   # Check to see if we have a "type" arg. If so, we use this to create the key:
   if (exists ($hashref->{'type'}))
      {
      my $type=$hashref->{'type'};
      # Make the type uppercase:
      $type =~ tr/[a-z]/[A-Z]/;
      # Rename the environment as "<type>:<env name>":
      $envname = $type.":".$envname;
      }
   
   # Delete name entry so hash is more tidy
   delete $$hashref{'name'};
   
   # Before we save $hashref we need to know if there are already
   # any runtime tags with the same name. If there are, we must save all
   # data to an aray of hashes:
   if (exists ($self->{"$self->{levels}->[$self->{nested}]".content}->{RUNTIME}->{$envname}))
      {
      push(@{$self->{"$self->{levels}->[$self->{nested}]".content}->{RUNTIME}->{$envname}},$hashref);
      }
   else
      {
      # No entry yet so just store the hashref:
      $self->{"$self->{levels}->[$self->{nested}]".content}->{RUNTIME}->{$envname} = [ $hashref ];
      }   
   }

sub flags()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   # Extract the flag name and its value:
   my ($flagname,$flagvaluestring) = each %attributes;
   $flagname=~s/\s//g; $flagname =~ tr/[a-z]/[A-Z]/; # Keep flag name uppercase
   chomp($flagvaluestring);
   # Split the value on whitespace so we can push all
   # individual flags into an array:
   my @flagvalues = split(' ',$flagvaluestring);
   
   # Is current tag within another tag block?
   if ($self->{nested} > 0)
      {
      # Check to see if the current flag name is already stored in the hash. If so,
      # just add the new values to the array of flag values:
      if (exists ($self->{"$self->{levels}->[$self->{nested}]".content}->{FLAGS}->{$flagname}))
	 {
	 push(@{$self->{"$self->{levels}->[$self->{nested}]".content}->{FLAGS}->{$flagname}},@flagvalues);
	 }
      else
	 {
	 $self->{"$self->{levels}->[$self->{nested}]".content}->{FLAGS}->{$flagname} = [ @flagvalues ];
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

sub makefile()
   {
   my ($object,$name,%attributes)=@_;
   }

sub makefile_()
   {
   my ($object,$name,$cdata)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   push(@{$self->{"$self->{levels}->[$self->{nested}]".content}->{MAKEFILE}},join("\n",@$cdata));
   }

sub client()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   $self->pushlevel();
   }

sub client_()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   $self->{content}->{CLIENT}=$self->{tagcontent};
   $self->poplevel();
   }

sub environment()
   {
   my ($object,$name,%attributes)=@_;
   if (!$self->{scramdoc}->_isvalid()){return;}
   my $hashref = \%attributes;
   # Save a copy of the name of this environment:
   my $envname=$hashref->{'name'}; $envname=~s/\s//g;
   delete $hashref->{'name'}; # Delete name entry so hash is more tidy
   # Before we save $hashref we need to know if there are already
   # any env tags with the same name. If there are, we must save all
   # data to an aray of hashes:
   my $pvar = $self->{path_variables};
   if (($pvar) && ($envname=~/$pvar/))
      {
      print STDERR "****WARNING: \"$envname\" is not allowed in client environment, it can override runtime environmnet.\nMay be you want to add it as <runtime/>, please fix \"",$self->{content}->{TOOLNAME},"\" tool definition.\n";
      return;
      }
   if (exists ($self->{"$self->{levels}->[$self->{nested}]".content}->{ENVIRONMENT}->{$envname}))
      {
      push(@{$self->{"$self->{levels}->[$self->{nested}]".content}->{ENVIRONMENT}->{$envname}},$hashref);
      my @norder=();
      foreach my $env (@{$self->{envorder}})
         {
         if($env ne $envname) {push @norder,$env;}
         }
         $self->{envorder}=[];
         push @{$self->{envorder}},@norder;
         push @{$self->{envorder}},$envname;
      }
   else
      {
      # No entry yet so just store the hashref:
      $self->{"$self->{levels}->[$self->{nested}]".content}->{ENVIRONMENT}->{$envname} = [ $hashref ];
      push @{$self->{envorder}},$envname;
      }
   }

sub parse
   {
   my $self=shift;
   my ($file)=@_;   
   $self->{scramdoc}->filetoparse($file);   
   $self->verbose("Setup Parse");
   my $fhead='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><doc type="BuildSystem::ToolParser" version="1.0">';
   my $ftail='</doc>';
   $self->{scramdoc}->removefilter("ifversion");
   $self->{scramdoc}->parse("setup",$fhead,$ftail);
   delete $self->{scramdoc};
   return $self;
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
   delete $self->{tagcontent};
   $self->{nested} = 0;
   }

sub rmenvdata
   {
   my $self=shift;
   delete $self->{ENVDATA};
   }

###################################
##      Data Access Methods      ##
###################################
sub toolname
   {
   my $self=shift;
   # Return tool name:
   return ($self->{content}->{TOOLNAME});
   }

sub toolversion
   {
   my $self=shift;
   # Return tool version:
   return ($self->{content}->{TOOLVERSION});
   }

sub toolcontent
   {
   my $self=shift;
   # Return whole of content hash:
   return $self->{content};
   }

sub getrawdata()
   {
   my $self=shift;
   my ($tagtype)=@_;
   
   # Check to see if we have data for this tag:
   if (! exists ($self->{content}->{$tagtype}))
      {
      # If not, return:
      return 0;
      }
   
   # Check the number of keys for hash referred to by this object.
   # If 0, return:
   if (ref($self->{content}->{$tagtype}) eq 'HASH') # 
      {
      if ((my $nkeys=keys %{$self->{content}->{$tagtype}}) > 0)
	 {
	 # Return the data for the tag $tagtype. ARCH is a bit special because
	 # we want the data for the actual arch (thus, data is on a different level):
	 if ($tagtype eq 'ARCH')
	    {
	    my $archmatch = {};
	    # Check for matching arch key and return hash of relevant data.
	    # Also must take into account the fact that several arch names may match, e.g. Linux, Linux__2 and
	    # Linux__2.4 all match. If we find more than one match, collect ALL matching data and return it:
	    while (my ($k,$v) = each %{$self->{content}->{ARCH}})
	       {
	       # For every matching architecture we snatch the data and squirrel it away:
	       if ( $ENV{SCRAM_ARCH} =~ /$k.*/ )
		  {
		  # Now we check the tags inside the arch block. Note that we do not want to descend
		  # into CLIENT tags, if these exist. We just want to return all data in the ARCH 
		  # block while making sure that multiple matches are handled correctly. We assume that
		  # you will only find one CLIENT block inside and ARCH:
		  while (my ($matchtag, $matchval) = each %{$v})
		     {
		     if ($matchtag =~ /CLIENT|FLAGS|RUNTIME/)
			{
			$archmatch->{$matchtag} = $matchval;
			}
		     else
			{
			# Treat tags differently according to whether they are HASHes or ARRAYs:
			if (ref($matchval) =~ /HASH/)
			   {
			   while (my ($t, $val) = each %{$matchval})
			      {
			      if (exists ($archmatch->{$matchtag}->{$t}))
				 {
				 push(@{$archmatch->{$matchtag}->{$t}},@$val);
				 }
			      else
				 {
				 $archmatch->{$matchtag}->{$t} = $val;
				 }
			      }
			   }
			else # Here we deal with arrays:
			   {			   
			   if (exists ($archmatch->{$matchtag}))
			      {
			      push(@{$archmatch->{$matchtag}},@$matchval);
			      }
			   else
			      {
			      $archmatch->{$matchtag} = $matchval;
			      }			  			   
			   }
			}
		     }
		  }
	       }
	    # Return the squirrel:
	    return $archmatch;
	    
	    } # End of ARCH tag treatment
	 else
	    {
	    # Return other tag data:
	    return $self->{content}->{$tagtype};
	    }
	 }
      else
	 {
	 print "Warning: $tagtype tags contain no other tag data!","\n";
	 return undef;
	 }
      }
   else
      {
      # We have an array of data or a scalar:
      return $self->{content}->{$tagtype}; 
      }
   }

sub processrawtool()
   {
   my $self=shift;
   my $data = [];
   my $environments = {}; # Somewhere to collect our environments

   # Somewhere to store the data:
   use BuildSystem::ToolData;
   my $tooldataobj = BuildSystem::ToolData->new();
   
   # Set the name and version:
   $tooldataobj->toolname($self->toolname());
   $tooldataobj->toolversion($self->toolversion());
   
   # First, collect all tag data so that we only have non-nested tags.
   # Check for architecture-dependent data first, followed by client tags:
   foreach $nested_tag (qw( ARCH CLIENT ))
      {
      if (my $thisdata=$self->getrawdata($nested_tag))
	 {
	 foreach my $item (keys %{ $thisdata })
	    {
	    if ($item eq 'CLIENT')
	       {
	       my $clientdata = $thisdata->{$item};
	       foreach my $ckey (keys %{$clientdata})
		  {
		  $environments->{$ckey} = $clientdata->{$ckey};
		  }
	       }
	    elsif ($item eq 'ENVIRONMENT' || $item eq 'RUNTIME')
	       {
	       # Check to see if tag already exists before saving:
	       if (exists($environments->{$item}))
		  {
		  foreach my $ek (keys %{$thisdata})
		     {
		     if (exists($environments->{$item}->{$ek}))
			{
			push(@{$environments->{$item}->{$ek}}, @{$thisdata->{$item}->{$ek}});
			}
		     else
			{
			$environments->{$item}->{$ek} = $thisdata->{$item}->{$ek};
			}	       
		     }
		  }
	       else
		  {
		  # There isn't an entry yet:
		  $environments->{$item} = $thisdata->{$item};
		  }
	       }
	    else
	       {
	       my $data = $thisdata->{$item};
	       
	       if (ref($data) eq 'HASH')
		  {
		  while (my ($f,$v) = each %$data)
		     {
		     $tooldataobj->flags($f,$v);
		     }
		  }
	       else
		  {
		  my $subname = lc($item);
		  $tooldataobj->$subname($data), if ($#$data != -1);
		  }
	       }
	    }
	 }
      else
	 {
	 # No entry for this nested tag. Proceed.
	 next;
	 }
      }
   # Now handle all other normal tags:
   foreach my $normal_tag (qw( ENVIRONMENT RUNTIME )) 
      {
      # Do we have some data for this tag?
      if (my $thisdata=$self->getrawdata($normal_tag))
	 {
	 # Add the data to our environments hash. We must check to see if
	 # there is an entry already:
	 if (exists($environments->{$normal_tag}))
	    {
	    foreach my $ek (keys %{$thisdata})
	       {
	       if (exists($environments->{$normal_tag}->{$ek}))
		  {
		  push(@{$environments->{$normal_tag}->{$ek}}, @{$thisdata->{$normal_tag}->{$ek}});
		  }
	       else
		  {
		  $environments->{$normal_tag}->{$ek} = $thisdata->{$normal_tag}->{$ek};
		  }
	       }
	    }
	 else
	    {
	    # There isn't an entry yet:
	    $environments->{$normal_tag} = $thisdata;
	    }
	 }
      else
	 {
	 # No data so proceed:
	 next;
	 }
      }

   # Finally, tags that can be stored straight away:
   foreach my $tag (qw( FLAGS MAKEFILE ))
      {
      my $bdata = $self->getrawdata($tag);
      if (ref($bdata) eq 'HASH')
	 {
	 while (my ($f,$v) = each %$bdata)
	    {
	    $tooldataobj->flags($f,$v);
	    }
	 }
      else
	 {
	 $tooldataobj->makefile($bdata), if ($#$bdata != -1);	
	 }
      }

   # Libs and tool dependencise:
   foreach my $tag (qw( LIB USE ))
      {
      my $bdata = $self->getrawdata($tag);
      my $subname = lc($tag);
      $tooldataobj->$subname($bdata), if ($#$bdata != -1);
      }

   my @xtags = keys %{$self->getrawdata('LIBTYPES')};
   $tooldataobj->tool_tag_value('LIBTYPES',\@xtags);
   foreach my $tag (@xtags)
      {
      my $bdata = $self->getrawdata($tag);
      $tooldataobj->tool_tag_value($tag, $bdata), if ($#$bdata != -1);
      }

   # Also check to see if this tool is a scram-managed project. If
   # so, set the SCRAM_PROJECT variable in the ToolData object:
   if (exists ($self->{content}->{SCRAM_PROJECT}))
      {
      $tooldataobj->scram_project($self->{content}->{SCRAM_PROJECT});
      }
   
   # And check to see if this tool is a compiler. If so, set
   # the SCRAM_COMPILER variable in the ToolData object:
   if (exists ($self->{content}->{SCRAM_COMPILER}))
      {
      $tooldataobj->scram_compiler($self->{content}->{SCRAM_COMPILER});
      }
   
   my @order=(); push @order,@{$self->{envorder}};
   my %uorder=(); map {$uorder{$_}=1} @order;
   foreach my $type (qw (ENVIRONMENT RUNTIME))
      {
      if (exists $environments->{$type})
         {
         foreach my $env (keys %{$environments->{$type}})
            {
            if (!exists $uorder{$env}){$uorder{$env}=1; push @order,$env;}
            }
         }
      }
   $self->find_settings($tooldataobj, $environments, \@order);
   return $tooldataobj;
   }

sub find_settings()
   {
   my $self=shift;
   my ($tooldataobj, $environments, $ordering)=@_;
   my $stringtoeval;
   my $runtime=[];
   my $path;
   
   use BuildSystem::ToolSettingValidator;
   
   my $tsv = BuildSystem::ToolSettingValidator->new($environments, $self->toolname());
   
   foreach my $envname (@$ordering)
      {
      my $type = 'ENVIRONMENT';
      my $envdata = $tsv->environment($type, $envname);

      # Handle single-occurrence variables first (i.e. VAR appears once
      # in array of hashes):
      if ($envdata != 0 && $#$envdata == 0) # One element only!
	 {
	 scramlogmsg("\nFinding a value for $envname:","\n\n");
	 $path = $tsv->findvalue($envname, $envdata);	     	       
	 $self->store($tooldataobj, $envname, $path);
	 }
      elsif ($envdata != 0 && $#$envdata > 0)
	 {
	 scramlogmsg("\nFinding a value for $envname:","\n\n");
	 foreach my $elementdata (@$envdata)
	    {
	    $path = $tsv->findvalue($envname, $elementdata);
	    $self->store($tooldataobj, $envname, $path);
	    }
	 }
      else
	 {
	 push(@$runtime, $envname);
	 }
      }
   $self->_lib_validate($tooldataobj);
   scramlogmsg("\n-------------------------------\n");
   foreach my $rtname (@$runtime)
      {
      my $type = 'RUNTIME';	 
      my $envdata = $tsv->environment($type, $rtname);
      my ($rttype,$realrtname) = split(':',$rtname);      

      # Only validate paths:
      if ($rtname =~ /:/)
	 {	
	 if ($envdata != 0 && $#$envdata == 0) # One element only!
	    {
	    scramlogmsg("\nRuntime path settings for $realrtname:","\n\n");
            $path = $tsv->findvalue($rtname, $envdata);	     	       
            $tooldataobj->runtime($rtname, [ $path ]);
	    }
	 elsif ($envdata != 0 && $#$envdata > 0)
	    {
	    scramlogmsg("\nRuntime path settings for $realrtname:","\n\n");
	    foreach my $elementdata (@$envdata)
	       {
	       $path = $tsv->findvalue($rtname, $elementdata);	 	    
	       $tooldataobj->runtime($rtname, [ $path ]);
	       }
	    }
	 else
	    {
	    next;
	    }
	 }
      else
	 {
	 if ($envdata != 0 && $#$envdata == 0) # One element only!
	    {
	    my $value='';
	    if ($tsv->checkdefaults($envdata, \$value)==0)
	       {
	       $tsv->promptuser($rtname,$value);
	       }
	    scramlogmsg("\n");
	    
	    if ($value =~ /$/)
	       {
 	       my $dvalue = $tsv->_expandvars($value);
	       $value = $dvalue;
	       }
	    
	    scramlogmsg("Runtime variable ",$rtname," set to \"",$value,"\"\n");
	    $tooldataobj->runtime($rtname, [ $value ]);
	    }
	 else
	    {
	    next;
	    }
	 }
      }
   
   scramlogmsg("\n");
   }

sub store()
   {
   my $self=shift;
   my ($tooldataobj, $envname, $path) = @_;
   my $subrtn = lc($envname);
   
   if ($tooldataobj->can($subrtn))
      {
      $tooldataobj->$subrtn([ $path ]);
      }
   else
      {
      $tooldataobj->variable_data($envname, $path);
      }
   }

sub _lib_validate()
   {
   my $self=shift;
   my ($toolobj)=@_;
   my $errorstatus = { 0 => $main::good."[OK]".$main::normal, 1 => $main::error."[ERROR]".$main::normal };
   my $libsfound={};
      
   # Firstly, we check to see if there are libraries provided by this tool:
   my @libraries = $toolobj->lib();
   my @libpaths = $toolobj->libdir();
   
   foreach my $ldir (@libpaths)
      {
      my $full_libname_glob="lib".$lib."*.*";
      # Change to lib dir so we avoid the very long paths in our glob:
      chdir($ldir);
      # Next we use a glob to get libs matching this string (so we
      # can see if there's a shared or archive lib):
      my @possible_libs = glob($full_libname_glob);
      # 
      map
	 {
	 $_ =~ s/\.so*|\.a*//g; # Remove all endings
	 # Store in our hash of found libs:
	 $libsfound->{$_} = 1;
	 } @possible_libs;
      }
   
   # Next we iterate over the list of libraries in our tool and
   # see if it was found in one of the libdirs:
   scramlogmsg("\n\n"), if ($#libraries != -1);
   foreach my $library (@libraries)
      {
      # Good status:
      my $errorid = 0;
      if (! exists ($libsfound->{'lib'.$library}))
	 {
	 # Check in system library dirs:
	 if ($self->_check_system_libs($library))
	    {
	    $errorid = 0;
	    }
	 else
	    {
	    $errorid = 1; 
	    }
	 }
      scramlogmsg(sprintf("* Library check %-10s for lib%-12s\n",$errorstatus->{$errorid}, $library));
      }
   
   scramlogmsg("\n");
   }

sub _check_system_libs()
   {
   my $self=shift;
   my ($lib)=@_;
   my $libsfound = {};
   my $systemdirs = [ qw( /lib /usr/lib /usr/local/lib /usr/X11R6/lib ) ];
   my $full_libname_glob="lib".$lib."*.*";
   my $found = 0;
   
   foreach my $dir (@$systemdirs)
      {
      # Change to lib dir so we avoid the very long paths in our glob:
      chdir($dir);
      # Next we use a glob to get libs matching this string (so we
      # can see if there's a shared or archive lib):
      my @possible_libs = glob($full_libname_glob);
      # 
      map
	 {
	 $_ =~ s/\.so*|\.a*//g; # Remove all endings
	 # Store in our hash of found libs:
	 $libsfound->{$_} = 1;
	 } @possible_libs;
      }
   
   # See if we find the library in the system lib directories:
   if (! exists ($libsfound->{'lib'.$library}))
      {
      $found = 1;
      }
   
   return $found;
   }

sub AUTOLOAD()
   {
   my ($xmlparser,$name,%attributes)=@_;
   return if $AUTOLOAD =~ /::DESTROY$/;
   my $xname=$AUTOLOAD; $xname =~ s/.*://;
   $self->{scramdoc}->$xname($name,%attributes);
   }

1;
