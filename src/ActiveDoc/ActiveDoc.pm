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
# newdoc(file)	: Return an new object of the appropriate type
# getfile(url)	: get a processedfile object given a url
# config([ActiveConfig]) : Set up/return Configuration for the document
# basequery([ActiveConfig]) : Set up/return UserQuery for the doc
# copydocconfig(ActiveDoc) : Copy the basic configuration from the ActiveDoc
# copydocquery(ActiveDoc) : Copy the basicquery from the ActiveDoc
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
use ObjectUtilities::ObjectBase;
use URL::URLhandler;

@ISA = qw(ObjectUtilities::ObjectBase);

sub new {
	my $class=shift;
	$self={};
	bless $self, $class;
	$self->config(shift);
	
	# A URL handler per document
	$self->{urlhandler}=URL::URLhandler->new($self->config()->cache());

	$self->init(@_);
	return $self;
}

# ----- parse related routines --------------
sub parse {
	my $self=shift;
	$parselabel=shift;

	my $file=$self->file();
	if ( $file ) {
	  $self->{currentparser}=$self->{parsers}{$parselabel};
	  $self->{parsers}{$parselabel}->parse($file,@_);
	  delete $self->{currentparser};
	}
	else {
	  print "Cannot parse - file not known\n";
	}
}

sub newparse {
	my $self=shift;
	my $parselabel=shift;

	$self->{parsers}{$parselabel}=ActiveDoc::Parse->new();
	$self->{parsers}{$parselabel}->addignoretags();
	$self->{parsers}{$parselabel}->addgrouptags();
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
	@_ ?$self->{File}=$self->getfile(shift)
	    : $self->{File};
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
	@_ ? $self->{UserQuery}=shift
	   : $self->{UserQuery};
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
		$self->{PPfile}->line($self->{currentparser}->line());
	return ($line, $fileobj);
}

sub tagstartline {
	my $self=shift;
	my ($line, $fileobj)=$self->{PPfile}->line(
		$self->{currentparser}->tagstartline());
        return ($line, $fileobj);
}

sub file {
	my $self=shift;

	$self->{PPf}->file();
}

# --------------- Initialisation Methods ---------------------------

sub preprocess_init {
	my $self=shift;
	$self->{PPfile}=PreProcessedFile->new($self->config());
}

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
