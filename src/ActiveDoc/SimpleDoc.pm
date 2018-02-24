#
# SimpleDoc.pm
#
# Originally Written by Christopher Williams
#
# Description
# -----------
# Simple multi parsing functionality and group manipulation
#
# Interface
# ---------
# new([DocVersionTag])		: A new ActiveDoc object. You can also
#                                 specify an alternative doc version tag
# filetoparse([filename])	: Set/Return the filename of document
# newparse(parselabel) : Create a new parse type
# parse(parselabel)    : Parse the document file for the given parse level
# checktag(tagname, hashref, param) : check for existence of param in
#					hashref from a tag call
# currentparser() : return the current parser object
# currentparsename([name]) : get/set current parse name
#
# filenameref(string)	: A string to refer to the file in parse error messages
#			  etc. Default is filetoparse
# --------------- Error handling routines ---------------
# verbose(string)	: Print string in verbosity mode
# verbosity(0|1)	: verbosity off|on 
# parseerror(string)   :  print error and associate with line number etc.
# error(string)	: handle an error

package ActiveDoc::SimpleDoc;
require 5.004;
use ActiveDoc::Parse;

sub new()
   {
   my $class=shift;
   $self={};
   bless $self, $class;
   $self->addfilter("architecture",$ENV{SCRAM_ARCH});
   if (exists $ENV{SCRAM_PROJECTVERSION}){
     $self->addfilter("release",$ENV{SCRAM_PROJECTVERSION});
     $self->addfilter("compiler",$ENV{DEFAULT_COMPILER});
     $self->addfilter("ifrelease",$ENV{SCRAM_PROJECTVERSION});
     $self->addfilter("ifcompiler",$ENV{DEFAULT_COMPILER});
     $self->addfilter("ifcxx11_abi",$ENV{SCRAM_CXX11_ABI});
     $self->addfilter("ifproject",$ENV{SCRAM_PROJECTNAME});
     $self->addfilter("ifconfig",$ENV{SCRAM_CONFIGCHKSUM});
     $self->addfilter("ifscram",$ENV{SCRAM_VERSION});
   }
   return $self;
   }

sub addfilter()
   {
   my ($self,$filter,$val)=@_;
   $self->{support_filters}{$filter}=$val;
   $self->{$filter}=[];
   $self->{"${filter}_value"}=1;
   }

sub removefilter()
   {
   my ($self,$filter)=@_;
   if (exists $self->{$filter})
      {
      delete $self->{support_filters}{$filter};
      delete $self->{$filter};
      delete $self->{"${filter}_value"};
      }
   }

sub filenameref()
   {
   my $self=shift;
   if ( @_ )
      {
      $self->{filenameref}=shift;
      }
   return (defined $self->{filenameref})?$self->{filenameref} : $self->filetoparse();
   }

sub verbosity()
   {
   my $self=shift;
   $self->{verbose}=shift;
   }

sub verbose()
   {
   my $self=shift;
   my $string=shift;
   
   if ( $self->{verbose} )
      {
      print ">".ref($self)."($self) : \n->".$string."\n";
      }
   }

# ----- parse related routines --------------
sub parse()
   {
   my $self=shift;
   $parselabel=shift;
   my $fhead=shift || "";
   my $ftail=shift || "";
   my $file=$self->filetoparse();

   if ( -f $file )
      {
      if ( exists $self->{parsers}{$parselabel} )
	 {
	 $self->verbose("Parsing $parselabel in file $file");
	 $self->{currentparsename}=$parselabel;
	 $self->{currentparser}=$self->{parsers}{$parselabel};
	 # Parse and store the returned data in content (only for Streams style):
         $self->{parsers}{$parselabel}->filehead($fhead);
         $self->{parsers}{$parselabel}->filetail($ftail);
	 $self->{content} = $self->{parsers}{$parselabel}->parse($file,@_)->data();
	 delete $self->{currentparser};
	 $self->{currentparsename}="";
	 $self->verbose("Parse $parselabel Complete");
	 }
      }
   else
      {
      $self->error("Cannot parse \"$parselabel\" - file $file not known");
      }
   }

sub parsefilelist()
   {
   my $self=shift;
   my $parselabel=shift;
   my ($filenames)=@_;

   if ( exists $self->{parsers}{$parselabel} )
      {
      $self->verbose("ParsingFileList: Label = $parselabel (files = ".join(",",@$filenames)." ");
      $self->{currentparsename}=$parselabel;
      $self->{currentparser}=$self->{parsers}{$parselabel};
      $self->{parsers}{$parselabel}->parsefilelist($filenames);
      delete $self->{currentparser};
      $self->{currentparsename}="";
      $self->verbose("ParseFileList $parselabel Complete");
      }
   else
      {
      $self->error("Cannot parse \"$parselabel\" - Unknown parser!!");
      }
   }

sub currentparsename()
   {
   my $self=shift;
   @_?$self->{currentparsename}=shift
      :(defined $self->{currentparsename}?$self->{currentparsename}:"");
   }

sub currentparser()
   {
   my $self=shift;
   return $self->{currentparser};
   }

sub newparse()
   {
   my $self=shift;
   my $parselabel=shift;
   my $dataclass=shift;
   my $parse_style=shift;
   $dataclass ||= "ParsedDoc";
   $parse_style ||= 'Objects';
   $self->{parsers}{$parselabel}=ActiveDoc::Parse->new($dataclass,$parse_style,shift,shift);
   }

sub filetoparse()
   {
   my $self=shift;
   
   if ( @_ )
      {
      $self->{filename}=shift;
      }
   return $self->{filename};
}

sub content()
   {
   my $self=shift;
   return $self->{content};
   }

# -------- Error Handling and Error services --------------
sub error()
   {
   my $self=shift;
   my $string=shift;
   
   die $string."\n";
   }

sub parseerror
   {
   my $self=shift;
   my $string=shift;
   
   if ( $self->currentparsename() eq "" )
      {
      $self->error("Error In file ".$self->filenameref."\n".$string);
      }
   else
      {
      $line=$self->line();
      print "Parse Error in ".$self->filenameref().", line ".
	 $line."\n";
      print $string."\n";
      exit;
      }
   }

sub checktag()
   {
   my $self=shift;
   my $tagname=shift;
   my $hashref=shift;
   my $param=shift;
   
   if ( ! exists $$hashref{$param} )
      {
      $self->parseerror("Incomplete Tag <$tagname> : $param required");
      }
   }

# -- dummy tag routines
sub doc()
   {
   my $self=shift;
   }

sub doc_()
   {
   my $self=shift;
   }

# -- Default for supported filters
sub _isvalid()
   {
   foreach my $flag (keys %{$self->{support_filters}}){if ($self->{"${flag}_value"}==0){return 0;}}
   return 1;
   }

sub _checkfilter()
   {
   my ($object,$name,%attributes)=@_;
   my $flag=$self->{"${name}_value"};
   push @{$self->{$name}},$flag;
   my $filter="";
   my $exact=0;
   if (exists $attributes{value}){$filter=$attributes{value};$exact=1;}
   elsif (exists $attributes{match}){$filter=$attributes{match};}
   else{$filter=$attributes{name};}
   if ($flag)
      {
      my $val = $self->{support_filters}{$name};
      if ($filter=~/^[!](.+)$/)
         {
         $filter=$1;
         if (($exact==1) && ($val eq $filter)){$self->{"${name}_value"}=0;}
         if (($exact==0) && ($val=~/$filter/)){$self->{"${name}_value"}=0;}
         }
      else{
        if (($exact==1) && ($val ne $filter)){$self->{"${name}_value"}=0;}
        elsif (($exact==0) && ($val!~/$filter/)){$self->{"${name}_value"}=0;}
        }
      }
   }

sub _endfilter()
   {
   my ($object,$name,%attributes)=@_;
   $self->{"${name}_value"}=pop @{$self->{$name}};
   }

sub AUTOLOAD()
   {
   my ($xmlparser,$name,%attributes)=@_;
   return if $AUTOLOAD =~ /::DESTROY$/;
   if (exists $self->{support_filters}{$name})
      {
      if ($AUTOLOAD=~/_$/){$self->_endfilter($name,%attributes);}
      else{$self->_checkfilter($name,%attributes);}
      }
   }

1;
