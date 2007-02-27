#
# Parse.pm
#
# Originally Written by Christopher Williams
#
# Description
# -----------
# maintain parse configurations
#
# Interface
# ---------
# new()		        : A new Parse object
# addtag(name,start,text,end,$object)	: Add a new tag
# addgrouptags()        : add <Group> tag functionality
# addignoretags()       : add <ignore> tag functionality
# parse(filename,[streamhandle], [streamexcludetag]) : 
#				parse the given file - turn on the stream
#				   function of the switcher if a filehandle
#				   supplied as a second argument
# line()	        : return the current linenumber in the file
# tagstartline()	: return the linenumber of the last tag opening 
# includeparse(Parse)   : include the settings from another parse object
# tags()		: return list of defined tags
# cleartags()		: clear of all tags
# opencontext(name)	: open a parse context
# closecontext(name)	: close a parse context
# includecontext(name)  : Process when in a given context
# excludecontext(name)  : No Processing when given context
# contexttag(tagname)   : Register the tagname as one able to change context
#			  if not registerd - the close tag will be ignored
#			  too if outside of the specified context!

package ActiveDoc::Parse;
require 5.004;
use XML::Parser;

sub new()
   {
   my $class=shift;
   $self={};
   bless $self, $class;
   my ($dataclass, $parse_style)=@_;

   $self->{xmlparser} = new XML::Parser (
					 Style => $parse_style,
					 ParseParamEnt => 1,
					 ErrorContext => 3,
					 Pkg   => $dataclass);   
   return $self;
   }

sub parsefilelist()
   {
   my $self=shift;
   my ($files)=@_;
   }

sub parse()
   {
   my $self=shift;
   my ($file)=@_;
   $self->{data} = $self->{xmlparser}->parse($self->getfilestring_($file));
   return $self;
   }

sub getfilestring_()
   {
   my $self=shift;
   my ($file)=@_;
   open (IN, "< $file") or die __PACKAGE__.": Cannot read file $file: $!\n";
   my $filestring = join("", <IN>);
   close (IN) or die __PACKAGE__.": Cannot read file $file: $!\n";
   # Strip spaces at the beginning and end of the line:
   $filestring =~ s/^\s+//g;
   $filestring =~ s/\s+$//g;
   # Finally strip the newlines:
   $filestring =~ s/\n//g;
   # Strip out spaces in between tags:
   $filestring =~ s/>\s+</></g;
   $self->{filestring}=$filestring;
   return $filestring;
   }

sub data()
   {
   my $self=shift;
   return $self->{data}->[0];
   }

sub includeparse
   {
   my $self=shift;
   my $obj=shift;
   my $tag;
   
   # copy the tags from  the remote parse object
   foreach $tag ( $obj->tags() )
      {
      $self->addtag($tag,$obj->{tags}->tagsettings($tag));
      }
   }

sub addtag
   {
   my $self=shift;
   $self->{tags}->addtag(@_);
   }

1;
