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
# addtag(parselabel,tagname,start,obj,[text,obj,end,obj]) :
#				 Add tags to the parse given by label
# grouptag(tagname, parselabel)	: Allow a tag to switch context 
#				  - if not you can never turn a context off!
# checktag(tagname, hashref, param) : check for existence of param in
#					hashref from a tag call
# includeparse(local_parsename, objparsename, activedoc) : copy the parse from 
#							one object to another
# currentparser() : return the current parser object
# currentparsename([name]) : get/set current parse name
#
# addignoretags(parsename) : add <ignore> </igonore> tags funtionality to the
#				specified parse
# opengroup(name) : declare a group to be open
# closegroup(name) : declare a group to be closed
# allowgroup(name,parse) : allow a group so named
# disallowgroup(name,parse) : disallow the named group
# restoregroup(name,parse) : restore group access setting (that before last change)
# doctype()             : return the (type,version) of the document
#			  as specified by the DocVersionTag
# filenameref(string)	: A string to refer to the file in parse error messages
#			  etc. Default is filetoparse
# --------------- Error handling routines ---------------
# verbose(string)	: Print string in verbosity mode
# verbosity(0|1)	: verbosity off|on 
# line()		: return the current line number in the current parse
# tagstartline()	: return the line number where the current tag was
#			  opened
# parseerror(string)   :  print error and associate with line number etc.
# error(string)	: handle an error

package ActiveDoc::SimpleDoc;
require 5.004;
use ActiveDoc::Parse;

sub new {
	my $class=shift;
	$self={};
	bless $self, $class;
	$self->_initdoc("doc",@_);
	return $self;
}

sub doctype {
        my $self=shift;
        my $rv=1;

        undef $self->{docversion};
        undef $self->{doctype};
        $self->parse("doc");
        return ($self->{doctype},$self->{docversion});
}

sub filenameref {
	my $self=shift;
	if ( @_ ) {
	   $self->{filenameref}=shift;
	}
	return (defined $self->{filenameref})?$self->{filenameref}
					     :$self->filetoparse();
}

sub _initdoc {
        my $self=shift;
        my $parsename=shift;

        $self->{doctag}="DOC";
        if ( @_ ) {
          $self->{doctag}=shift;
        }
        $self->newparse($parsename);
        $self->addtag($parsename,$self->{doctag},\&Doc_Start, $self);
}

sub verbosity {
	my $self=shift;
	$self->{verbose}=shift;
}

sub verbose {
	my $self=shift;
	my $string=shift;

	if ( $self->{verbose} ) {
	  print ">".ref($self)."($self) : \n->".$string."\n";
	}
}

# ----- parse related routines --------------
sub parse {
	my $self=shift;
	$parselabel=shift;

	my $file=$self->filetoparse();
	if ( -f $file ) {
	  if ( exists $self->{parsers}{$parselabel} ) {
	    $self->verbose("Parsing $parselabel in file $file");
	    $self->{currentparsename}=$parselabel;
	    $self->{currentparser}=$self->{parsers}{$parselabel};
	    $self->{parsers}{$parselabel}->parse($file,@_);
	    delete $self->{currentparser};
	    $self->{currentparsename}="";
	    $self->verbose("Parse $parselabel Complete");
	  }
	}
	else {
	  $self->error("Cannot parse \"$parselabel\" - file $file not known");
	}
}

sub currentparsename {
	my $self=shift;
	@_?$self->{currentparsename}=shift
	  :(defined $self->{currentparsename}?$self->{currentparsename}:"");
}

sub currentparser {
	my $self=shift;
	return $self->{currentparser};
}


sub newparse {
	my $self=shift;
	my $parselabel=shift;

	$self->{parsers}{$parselabel}=ActiveDoc::Parse->new();
#	$self->{parsers}{$parselabel}->addgrouptags();
}

sub addignoretags {
	my $self=shift;
	my $parselabel=shift;
	$self->{parsers}{$parselabel}->addignoretags();
}

sub cleartags {
	my $self=shift;
        my $parselabel=shift;

	$self->{parsers}{$parselabel}->cleartags();
}


sub includeparse {
	my $self=shift;
        my $parselabel=shift;
	my $remoteparselabel=shift;
	my $activedoc=shift;

	# Some error trapping
	if ( ! exists $self->{parsers}{$parselabel} ) {
	  $self->error("Unknown local parse name specified");
	}
	if ( ! exists $activedoc->{parsers}{$remoteparselabel} ) {
          $self->error("Unknown parse name specified in remote obj $activedoc");
        }

	#
	my $rp=$activedoc->{parsers}{$remoteparselabel};
	$self->{parsers}{$parselabel}->includeparse($rp);
}

sub addtag {
	my $self=shift;
	my $parselabel=shift;
	if ( ( $#_ != 6 ) && ( $#_ != 2) ) {
		$self->error("Incorrect addtags specification\n".
				"called with :\n@_ \n");
	}
	$self->{parsers}{$parselabel}->addtag(@_);
}

sub filetoparse {
	my $self=shift;

	if ( @_ ) {
	   $self->{filename}=shift;
	}
	return $self->{filename};
}
# --------- Group services
sub grouptag {
	my $self=shift;
	my $name=shift;
	my $parselabel=shift;

	$self->{parsers}{$parselabel}->contexttag($name);
}

sub opengroup {
	my $self=shift;
	my $name=shift;

	if ( defined $self->currentparser ) {
	   $self->currentparser()->opencontext($name);
	}
	else {
	   $self->error("Cannot Call opengroup outside of a parse (".
			caller().")");
	}
}

sub closegroup {
	my $self=shift;
	my $name=shift;

	if ( defined $self->currentparser ) {
	   $self->currentparser()->closecontext($name);
	}
	else {
	   $self->error("Cannot Call closegroup outside of a parse (".
			caller().")");
	}
}

sub allowgroup {
	my $self=shift;
	my $name=shift;
	my $parselabel=shift;

	$self->{parsers}{$parselabel}->includecontext($name);
}

sub disallowgroup {
	my $self=shift;
	my $name=shift;
	my $parselabel=shift;

	$self->{parsers}{$parselabel}->excludecontext($name);
}

# -------- Error Handling and Error services --------------

sub error {
        my $self=shift;
        my $string=shift;

        die $string."\n";
}

sub parseerror {
        my $self=shift;
        my $string=shift;

	if ( $self->currentparsename() eq "" ) {
		$self->error("Error In file ".$self->filenameref."\n".$string);
	}
	else {
	 $line=$self->line();
         print "Parse Error in ".$self->filenameref().", line ".
                                        $line."\n";
         print $string."\n";
         exit;
	}
}

sub checktag {
        my $self=shift;
        my $tagname=shift;
        my $hashref=shift;
        my $param=shift;

        if ( ! exists $$hashref{$param} ) {
          $self->parseerror("Incomplete Tag <$tagname> : $param required");
        }
}

sub line {
	my $self=shift;
	return $self->{currentparser}->line();
}

sub tagstartline {
	my $self=shift;
	return $self->{currentparser}->tagstartline();
}

# -- tag routines
sub Doc_Start {
        my $self=shift;
        my $name=shift;
        my $hashref=shift;

        $self->checktag($name, $hashref, "type");
        $self->checktag($name, $hashref, "version");

        $self->{doctype}=$$hashref{'type'};
        $self->{docversion}=$$hashref{'version'};
}
