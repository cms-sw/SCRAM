#____________________________________________________________________ 
# File: ToolParser.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-02-09 20:14:55+0100
# Revision: $Id: ToolParser.pm,v 1.4 2005/04/13 16:45:36 sashby Exp $ 
#
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::ToolParser;
require 5.004;

use Exporter;
use ActiveDoc::SimpleDoc;
use Utilities::Verbose;
use BuildSystem::ToolTagUtils;

@ISA=qw(Exporter Utilities::Verbose);
@EXPORT=qw();

#
sub new
   ###############################################################
   # new                                                         #
   ###############################################################
   # modified : Thu Nov 13 10:42:08 2003 / SFA                   #
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
   
   $self->{cache}=shift;
   $self->{mydoctype}="BuildSystem::ToolParser";
   $self->{mydocversion}="1.1";
   $self->{interactive} = 0;
   $self->{content} = {};
   $self->{nested} = 0;
   
   $self->_initparser();
   
   return $self;
   }

sub _initparser
   {
   my $self=shift;
   
   $self->{simpledoc}=ActiveDoc::SimpleDoc->new();
   $self->{simpledoc}->newparse("setup");
   $self->{simpledoc}->addtag("setup","Tool",
			      \&BuildSystem::ToolTagUtils::tooltagOpen, $self,	
			      "", $self,
			      \&BuildSystem::ToolTagUtils::tooltagClose, $self);
   
   $self->{simpledoc}->addtag("setup","Lib",
			      \&BuildSystem::ToolTagUtils::libtagOpen, $self,	
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("setup","info",
			      \&BuildSystem::ToolTagUtils::infotagOpen, $self,	
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("setup","Use",
			      \&BuildSystem::ToolTagUtils::usetagOpen, $self,	
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("setup","Runtime",
			      \&BuildSystem::ToolTagUtils::runtimetagOpen, $self,	
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("setup","Flags",
			      \&BuildSystem::ToolTagUtils::flagstagOpen, $self,	
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("setup","Client",
			      \&BuildSystem::ToolTagUtils::clienttagOpen, $self,	
			      "", $self,
			      \&BuildSystem::ToolTagUtils::clienttagClose, $self);
   
   $self->{simpledoc}->addtag("setup","Environment",
			      \&BuildSystem::ToolTagUtils::environmenttagOpen, $self,	
			      "", $self,
			      "", $self);
   
   $self->{simpledoc}->addtag("setup","Makefile",
			      \&BuildSystem::ToolTagUtils::makefiletagOpen, $self,
			      \&BuildSystem::ToolTagUtils::makefiletagContent, $self,
			      \&BuildSystem::ToolTagUtils::makefiletagClose, $self);
   
   $self->{simpledoc}->grouptag("Tool","setup");
   $self->{simpledoc}->addtag("setup","Architecture",
			      \&BuildSystem::ToolTagUtils::archtagOpen,$self,
			      "", $self,
			      \&BuildSystem::ToolTagUtils::archtagClose,$self);
   
   }

sub parse
   {
   my $self=shift;
   my ($tool,$toolver,$file)=@_;
   
   $self->{tool}=$tool;
   $self->{version}=$toolver;
   $self->{simpledoc}->filetoparse($file);   
   $self->verbose("Setup Parse");
   $self->{simpledoc}->parse("setup");
    
   delete $self->{simpledoc};
   return $self;
   }

sub pushlevel
   {
   my $self = shift;
   my ($info, $nextlevel)=@_;
   
   $self->{id} = $info if (defined $info);

   # Check to see if last tag was arch: if so, ceate new level:
   if ($self->{isarch} == 1)
      {
      $self->{nested} = 2;
      $self->{nexttagcontent}={};
      }
   else
      {
      $self->{nested} = 1;
      $self->{tagcontent}={};
      }

   # Set something which says "last starter tag was ARCH":
   if ($nextlevel)
      {
      $self->{isarch} = 1;
      }
   }

sub poplevel
   {
   my $self = shift;
   
   # Drop level of nesting by one:
   $self->{nested}--;

   if ($self->{isarch} != 1)
      {
      delete $self->{tagcontent};
      }
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
   my ($interactive) = @_;
   my $data = [];
   my $environments = {}; # Somewhere to collect our environments

   # Set interactive mode if required:
   $self->{interactive} = $interactive;

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

   # Establish the order of parsing the value strings:
   my $order = $self->process_environments($environments);

   if ($self->{interactive})
      {
      # Set the values interactively:
      $self->interactively_find_settings($tooldataobj, $environments, $order);
      }
   else
      {
      # Set the values:
      $self->find_settings($tooldataobj, $environments, $order);
      }
     
   # Return a ToolData object:
   return $tooldataobj;
   }

sub process_environments()
   {
   my $self=shift;
   my ($environments)=@_;
   
   use BuildSystem::SCRAMGrapher;
   my $G = BuildSystem::SCRAMGrapher->new();

   foreach $envtype (keys %{$environments})
      {
      while (my ($envcontent,$envdata) = each %{$environments->{$envtype}})
	 {
	 # Add a vertex for the VARIABLE name:
	 $G->vertex($envcontent);

	 foreach my $element (@$envdata)
	    {
	    if (exists($element->{'ELEMENTS'}))
	       {
	       map
		  {
		  # Add a path for each element in ELEMENTS:
		  $G->edge($envcontent, $_);
		  } @{$element->{'ELEMENTS'}};
	       }
	    }
	 }
      }

   my $setup_order = $G->sort();
   return $setup_order;
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
	 print "\nFinding a value for $envname:","\n";
	 print "\n";
	 # We have an environment and only one data element:
	 # Check the lookup DB:
	 if ($tsv->checkDB($envname))
	    {
	    print "\tValidating value for $envname (found in tool DB):","\n";
	    if ($tsv->validatepath())
	       {
	       # Save in TSV and store in ToolData object:
	       $tsv->savevalue($envname,$tsv->pathfromdb());
	       $self->store($tooldataobj, $envname, $tsv->pathfromdb());
	       }
	    else
	       {
	       $path = $tsv->findvalue($envname, $envdata);	     	       
	       # Save the value in ToolData object:
	       $self->store($tooldataobj, $envname, $path);	       
	       }
	    }
	 else
	    {
	    $path = $tsv->findvalue($envname, $envdata);	     	       
	    # Save in ToolData object:
	    $self->store($tooldataobj, $envname, $path);
	    }
	 }
      elsif ($envdata != 0 && $#$envdata > 0)
	 {
	 print "\nFinding a value for $envname:","\n";
	 print "\n";
	 foreach my $elementdata (@$envdata)
	    {
	    $path = $tsv->findvalue($envname, $elementdata);	 	    
	    # Save in ToolData object:
	    $self->store($tooldataobj, $envname, $path);	    
	    }
	 }
      elsif (exists($ENV{$envname}))
	 {
	 # Nothing to do here:
	 push(@$runtime, $envname); # FIX From Shahzad.
	 next;
	 }
      else
	 {
	 push(@$runtime, $envname);
	 }
      }
   
   # Check that the required libraries exist:
   $self->_lib_validate($tooldataobj);
   
   # Now process the runtime settings:
   print "\n";
   print "-------------------------------\n";

   foreach my $rtname (@$runtime)
      {
      my $type = 'RUNTIME';	 
      my $envdata = $tsv->environment($type, $rtname);
      my ($rttype,$realrtname) = split(':',$rtname);      
      
      # Only validate paths:
      if ($rtname =~ /:/)
	 {	
	 # Handle single-occurrence variables first (i.e. VAR appears once
	 # in array of hashes):
	 if ($envdata != 0 && $#$envdata == 0) # One element only!
	    {
	    print "\nRuntime path settings for $realrtname:","\n";
	    print "\n";
	    # We have an environment and only one data element:
	    # Check the lookup DB:
	    if ($tsv->checkDB($rtname))
	       {
	       print "\tValidating value for path $realrtname (found in tool DB):","\n";
	       if ($tsv->validatepath())
		  {
		  # Save in TSV and store in ToolData object:
		  $tsv->savevalue($rtname, $tsv->pathfromdb());
		  $tooldataobj->runtime($rtname, [ $tsv->pathfromdb() ]);
		  }
	       else
		  {
		  $path = $tsv->findvalue($rtname, $envdata);	     	       
		  # Save the value in ToolData object:
		  $tooldataobj->runtime($rtname, [ $path ]);
		  }
	       }
	    else
	       {
	       $path = $tsv->findvalue($rtname, $envdata);	     	       
	       # Save in ToolData object:
	       $tooldataobj->runtime($rtname, [ $path ]);
	       }
	    }
	 elsif ($envdata != 0 && $#$envdata > 0)
	    {
	    print "\nRuntime path settings for $realrtname:","\n";
	    print "\n";
	    foreach my $elementdata (@$envdata)
	       {
	       $path = $tsv->findvalue($rtname, $elementdata);	 	    
	       # Save in ToolData object:
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
	 # Handle runtime variables:
	 if ($envdata != 0 && $#$envdata == 0) # One element only!
	    {
	    my $value='';
	    $tsv->checkdefaults($envdata, \$value);
	    print "\n";
	    
	    # Chck to see if the value contains a variable that should be evaluated:
	    if ($value =~ /$/)
	       {
	       # If so, find the value and substitute. This should work for all
	       # occurrences of variables because by this point (and because the ordering
	       # was established at the start) all other variables will have real values:
 	       my $dvalue = $tsv->_expandvars($value);
	       $value = $dvalue;
	       }
	    
	    print "Runtime variable ",$rtname," set to \"",$value,"\"\n";
	    
	    # Store the variable setting:
	    $tooldataobj->runtime($rtname, [ $value ]);
	    }
	 else
	    {
	    next;
	    }
	 }
      }
   
   print "\n";
   }

sub interactively_find_settings()
   {
   my $self=shift;
   my ($tooldataobj, $environments, $ordering)=@_;
   my $stringtoeval;
   my $runtime=[];
   my ($path, $dpath);
   
   use BuildSystem::ToolSettingValidator;
   
   my $tsv = BuildSystem::ToolSettingValidator->new($environments, $self->toolname(), $self->{interactive});
   
   foreach my $envname (@$ordering)
      {
      my $type = 'ENVIRONMENT';
      my $envdata = $tsv->environment($type, $envname);

      # Handle single-occurrence variables first (i.e. VAR appears once
      # in array of hashes):
      if ($envdata != 0 && $#$envdata == 0) # One element only!
	 {
	 print "\nFinding a value for $envname:","\n";
	 print "\n";
	 # We have an environment and only one data element:
	 # Check the lookup DB:
	 if ($tsv->checkDB($envname))
	    {
	    print "\tValidating value for $envname (found in tool DB):","\n";
	    if ($tsv->validatepath())
	       {
	       # This is our default:
	       $dpath = $tsv->pathfromdb();
	       # Run promptuser() to see if this value can be kept
	       # or should be changed:
	       $path = $tsv->promptuser($envname, $dpath); 
	       # Save in TSV and store in ToolData object:
	       $tsv->savevalue($envname,$path);
	       $self->store($tooldataobj, $envname, $path);
	       }
	    else
	       {
	       $path = $tsv->ifindvalue($envname, $envdata);
	       # Save the value in ToolData object:
	       $self->store($tooldataobj, $envname, $path);
	       }
	    }
	 else
	    {
	    $dpath = $tsv->ifindvalue($envname, $envdata);
	    # Save in ToolData object:
	    $self->store($tooldataobj, $envname, $dpath);
	    }
	 }
      elsif ($envdata != 0 && $#$envdata > 0)
	 {
	 print "\nFinding a value for $envname:","\n";
	 print "\n";
	 foreach my $elementdata (@$envdata)
	    {
	    $path = $tsv->ifindvalue($envname, $elementdata);
	    # Save in ToolData object:
	    $self->store($tooldataobj, $envname, $path);	    
	    }
	 }
      elsif (exists($ENV{$envname}))
	 {
	 # Nothing to do here:
	 next;
	 }
      else
	 {
	 push(@$runtime, $envname);
	 }
      }
   
   # Check that the required libraries exist:
   $self->_lib_validate($tooldataobj);
   
   # Now process the runtime settings:
   print "\n";
   print "-------------------------------\n";
   foreach my $rtname (@$runtime)
      {
      my $type = 'RUNTIME';	 
      my $envdata = $tsv->environment($type, $rtname);
      my ($rttype,$realrtname) = split(':',$rtname);      
      
      # Only validate paths:
      if ($rtname =~ /:/)
	 {	
	 # Handle single-occurrence variables first (i.e. VAR appears once
	 # in array of hashes):
	 if ($envdata != 0 && $#$envdata == 0) # One element only!
	    {
	    print "\nRuntime path settings for $realrtname:","\n";
	    print "\n";
	    # We have an environment and only one data element:
	    # Check the lookup DB:
	    if ($tsv->checkDB($rtname))
	       {
	       print "\tValidating value for path $realrtname (found in tool DB):","\n";
	       if ($tsv->validatepath())
		  {
		  $dpath = $tsv->pathfromdb();
		  # Run promptuser() to see if this value can be kept
		  # or should be changed:
		  $path = $tsv->promptuser($rtname, $dpath);		  
		  # Save in TSV and store in ToolData object:
		  $tsv->savevalue($rtname, $path);
		  $tooldataobj->runtime($rtname, [ $path ]);
		  }
	       else
		  {
		  $dpath = $tsv->ifindvalue($rtname, $envdata);
		  # Save the value in ToolData object:
		  $tooldataobj->runtime($rtname, [ $path ]);
		  }
	       }
	    else
	       {
	       $path = $tsv->ifindvalue($rtname, $envdata);
	       # Save in ToolData object:
	       $tooldataobj->runtime($rtname, [ $path ]);
	       }
	    }
	 elsif ($envdata != 0 && $#$envdata > 0)
	    {
	    print "\nRuntime path settings for $realrtname:","\n";
	    print "\n";
	    foreach my $elementdata (@$envdata)
	       {
	       $path = $tsv->ifindvalue($rtname, $elementdata);
	       # Save in ToolData object:
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
	 # Handle runtime variables:
	 if ($envdata != 0 && $#$envdata == 0) # One element only!
	    {
	    my $dvalue='';
	    $tsv->checkdefaults($envdata, \$dvalue);
	    print "\n";
	    my $value = $tsv->promptuserforvar($rtname, $dvalue);
	    # Store the variable setting:
	    $tooldataobj->runtime($rtname, [ $value ]);
	    }
	 else
	    {
	    next;
	    }
	 }
      }
   
   print "\n";
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
   print "\n\n", if ($#libraries != -1);
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
      printf("* Library check %-10s for lib%-12s\n",$errorstatus->{$errorid}, $library);
      }
   
   print "\n";
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

1;
