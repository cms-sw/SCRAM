#
# ActiveDoc.pm
#
# Originally Written by Christopher Williams
#
# Description
#
# Interface
# ---------
# new()		: A new ActiveDoc object
# url()	        : Return/set the docs url - essential
# file()	: Return the local filename of document
#
# parse(parselabel): Parse the document file for the given parse level
# newparse(parselabel) : Create a new parse type
# addtag(parselabel,tagname,start,obj,text,obj,end,obj)
#				: Add tags to the parse given by label
# checktag(tagname, hashref, param) : check for existence of param in
#					hashref from a tag call
# includeparse(local_parsename, objparsename, activedoc) : copy the parse from 
#							one object to another
# currentparsename([name]) : get/set current parse name
# newdoc(file)	: Return an new object of the appropriate type
# getfile(url)	: get a processedfile object given a url
# activatedoc(url) : Return the object ref for a doc described by the given url
# config([ActiveConfig]) : Set up/return Configuration for the document
# basequery([ActiveConfig]) : Set up/return UserQuery for the doc
# copydocconfig(ActiveDoc) : Copy the basic configuration from the ActiveDoc
# copydocquery(ActiveDoc) : Copy the basicquery from the ActiveDoc
# userinterface()	: Return the defaullt userinterface
# options(var)		: return the value of the option var
#
# -- error methods --
# error(string)       : Report an general error to the user
# parseerror(string)  : Report an error during parsing a file
# line()	      : Return the current line number of the document
#			and the ProcessedFileObj it is in

package ActiveDoc::ActiveDoc;
require 5.004;
use ActiveDoc::Parse;
use ActiveDoc::ActiveConfig;
use ActiveDoc::PreProcessedFile;
use ObjectUtilities::StorableObject;
use URL::URLhandler;

@ISA = qw(ObjectUtilities::StorableObject);

sub new {
	my $class=shift;
	$self={};
	bless $self, $class;
	$self->config(shift);
	
	# A URL handler per document
	$self->{urlhandler}=URL::URLhandler->new($self->config()->cache());

	# A default UserInterface
	$self->{userinterface}=ActiveDoc::SimpleUserInterface->new();
	$self->init(@_);
	return $self;
}

# ----- parse related routines --------------
sub parse {
	my $self=shift;
	$parselabel=shift;

	my $file=$self->file();
	if ( $file ) {
	  $self->{currentparsename}=$parselabel;
	  $self->{currentparser}=$self->{parsers}{$parselabel};
	  $self->{parsers}{$parselabel}->parse($file,@_);
	  delete $self->{currentparser};
	  $self->{currentparsename}="";
	}
	else {
	  print "Cannot parse - file not known\n";
	}
}

sub currentparsename {
	my $self=shift;
	@_?$self->{currentparsename}=shift
	  :$self->{currentparsename};
}

sub newparse {
	my $self=shift;
	my $parselabel=shift;

	$self->{parsers}{$parselabel}=ActiveDoc::Parse->new();
	$self->{parsers}{$parselabel}->addignoretags();
	$self->{parsers}{$parselabel}->addgrouptags();
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
	if ( $#_ != 6 ) {
		$self->error("Incorrect addtags specification\n".
				"called with :\n@_ \n");
	}
	$self->{parsers}{$parselabel}->addtag(@_);
}

sub addurltags {
	my $self=shift;
	my $parselabel=shift;
	
	$self->{parsers}{$parselabel}->
		addtag("Base", \&Base_start, $self, "", $self,
			\&Base_end, $self);
}

sub url {
	my $self=shift;
	# get file & preprocess
	if ( @_  ) {$self->{File}=$self->getfile(shift)} 
	$self->{File}->url();
}

sub copydocconfig {
	my $self=shift;
	my $ActiveDoc=shift;
	
	$self->config($ActiveDoc->config());

}

sub copydocquery {
	my $self=shift;
        my $ActiveDoc=shift;

	 $self->basequery($ActiveDoc->basequery());
}

sub config {
	my $self=shift;
	@_?$self->{ActiveConfig}=shift
	   : $self->{ActiveConfig};
}

sub basequery {
	my $self=shift;
	@_ ? $self->{Query}=shift
	   : $self->{Query};
}

sub options {
	my $self=shift;
	my $param=shift;
	$self->basequery()->getparam('option_'.$param);
}

sub getfile() {
	my $self=shift;
	my $origurl=shift; 

	my $fileref;
	my ($url, $file)=$self->{urlhandler}->get($origurl);
	# do we already have an appropriate object?
	($fileref)=$self->config()->find($url);
	#undef $fileref;
	if (  defined $fileref ) {
	 print "found $url in database ----\n";
	 $fileref->update();
	}
	else {
	 if ( $file eq "" ) {
	   $self->parseerror("Unable to get $origurl");
	 }
	 #-- set up a new preprocess file
	 print "Making a new file $url----\n";
	 $fileref=ActiveDoc::PreProcessedFile->new($self->config());
	 $fileref->url($url);
	 $fileref->update();
	}
	return $fileref;
}

sub activatedoc {
	my $self=shift;
	my $url=shift;

	# first get a preprocessed copy of the file 
	my $fileob=$self->getfile($url);

	# now parse it for the <DocType> tag
	$self->{doctypefound}=0;
	$self->newparse("doctype");
	$self->addtag("doctype","Doc", \&Doc_Start, $self,
                                          "", $self, "", $self);
	$self->parse("doctype");

	if ( ! defined $self->{docobject} ) {
          print "No <Doc type=> Specified in ".$fileob->url()."\n";
          exit 1;
        }
	# Set up a new object of the specified type
	my $newobj=$self->{docobject}->new($self->config());
	$newobj->url($url);
	return $newobj;
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

	($line, $file)=$self->line();
        print "Parse Error in ".$file->url().", line ".
                                        $line."\n";
        print $string."\n";
        die;
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

	my ($line, $fileobj)=
		$self->{File}->realline($self->{currentparser}->line());
	return ($line, $fileobj);
}

sub tagstartline {
	my $self=shift;
	my ($line, $fileobj)=$self->{File}->line(
		$self->{currentparser}->tagstartline());
        return ($line, $fileobj);
}

sub file {
	my $self=shift;

	$self->{File}->file();
}

# --------------- Initialisation Methods ---------------------------

sub init {
        # Dummy Routine - override for derived classes
}

# ------------------- Tag Routines -----------------------------------
#
# Base - for setting url bases
#
sub Base_start {
        my $self=shift;
        my $name=shift;
        my $hashref=shift;

        $self->checktag($name, $hashref, 'type' );
        $self->checktag($name, $hashref, 'base' );
       
        # Keep track of base tags
        push @{$self->{basestack}}, $$hashref{"type"};
        # Set the base
        $self->{urlhandler}->setbase($$hashref{"type"},$hashref);

}

sub Base_end {
        my $self=shift;
        my $name=shift;
        my $type;

        if ( $#{$self->{basestack}} == -1 ) {
                print "Parse Error : unmatched </".$name."> on line ".
                        $self->line()."\n";
                die;
        }
        else {
          $type = pop @{$self->{basestack}};
          $self->{urlhandler}->unsetbase($type);
        }
}

sub Doc_Start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;
	
	$self->checktag($name, $hashref, "type");
	$self->{doctypefound}++;
	if ( $self->{doctypefound} == 1 ) { # only take first doctype
	   $self->{docobject}=$$hashref{'type'};
	}
}

sub userinterface {
	my $self=shift;
	@_?$self->{userinterface}=shift
	  :$self->{userinterface}
}
