#
# ActiveDoc.pm
#
# Originally Written by Christopher Williams
#
# Description
#
# Interface
# ---------
# new(ActiveConfig[,options])		: A new ActiveDoc object
# url()	        : Return/set the docs url - essential
# file()	: Return the local filename of document
# ProcessFile() : Return the filename of PreProcessed document
#
# parse(parselabel): Parse the document file for the given parse level
# parent()	   : return the object ref of the calling parent
# newparse(parselabel) : Create a new parse type
# addtag(parselabel,tagname,start,obj,text,obj,end,obj)
#				: Add tags to the parse given by label
# checktag(tagname, hashref, param) : check for existence of param in
#					hashref from a tag call
# includeparse(local_parsename, objparsename, activedoc) : copy the parse from 
#							one object to another
# currentparser() : return the current parser object
# currentparsename([name]) : get/set current parse name
# getfile(url)	: get a processedfile object given a url
# activatedoc(url) : Return the object ref for a doc described by the given url
#		     -- any parse called "init" will also be run
# config([ActiveConfig]) : Set up/return Configuration for the document
# basequery([ActiveConfig]) : Set up/return UserQuery for the doc
# copydocconfig(ActiveDoc) : Copy the basic configuration from the ActiveDoc
# copydocquery(ActiveDoc) : Copy the basicquery from the ActiveDoc
# userinterface()	: Return the defaullt userinterface
# option(var)		: return the value of the option var ( or undef )
# requestoption("message") : Ask the user to supply a value for an option 
#			     if it dosnt already exist
# askuser(Query)	: send a query object to the userinterface
# verbose(string)	: Print string in verbosity mode
#
# -- error methods --
# error(string)       : Report an general error to the user
# parseerror(string)  : Report an error during parsing a file
# line()	      : Return the current line number of the document
#			and the ProcessedFileObj it is in
#
# -- support for inheriting classes
# _saveactivedoc(filehandle)
# _restoreactivedoc(filehandle)

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

	# have some override options been passed
	if ( @_ ) {
	   $self->basequery(shift);
	}
	else {
	   # --- is there a starter document?
	   my $basedoc=$self->config()->basedoc();
	   if ( defined $basedoc ) {
	     $self->copydocquery($basedoc);
	     $self->verbose("Initialising from $basedoc");
	   }
	   else {
	     $self->error("ActiveDoc Error : No base doc found");
	   }
	}
	$self->verbose("New ActiveDoc (".ref($self).") Created");
	$self->_init2();
}

sub _init2 {

	my $self=shift;
	# A URL handler per document
	$self->{urlhandler}=URL::URLhandler->new($self->config()->cache());

	# A default UserInterface
	$self->{userinterface}=ActiveDoc::SimpleUserInterface->new();
	$self->init(@_);
	return $self;

}

sub verbose {
	my $self=shift;
	my $string=shift;

	if ( $self->option('verbose_all') || 
			$self->option('verbose_'.ref($self)) ) {
	  print ">".ref($self)."($self) : \n->".$string."\n";
	}
}

# ----- parse related routines --------------
sub parse {
	my $self=shift;
	$parselabel=shift;

	my $file=$self->ProcessFile();
	if ( $file ) {
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
	  $self->error("Cannot parse $parselabel - file not known");
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
	$self->{parsers}{$parselabel}->addignoretags();
	$self->{parsers}{$parselabel}->addgrouptags();
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
	if ( @_  ) {
		$self->{File}=$self->getfile(shift);
		$self->verbose("url downloaded to $self->{File}");
	} 
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

	if ( defined $ActiveDoc->basequery() ) {
	  $self->basequery($ActiveDoc->basequery());
	}
	else {
	  $self->error("Cannot copy basequery - undefined");
	}
}

sub config {
	my $self=shift;
	@_?$self->{ActiveConfig}=shift
	   : $self->{ActiveConfig};
}

sub basequery {
	my $self=shift;
	@_?$self->{Query}=shift
	   :$self->{Query};
}

sub option {
	my $self=shift;
	my $param=shift;
	if ( defined $self->basequery()) {
		return $self->basequery()->getparam($param);
	}
	else {
		return $undef;
	}
}

sub requestoption {
	my $self=shift;
        my $param=shift;
	my $string=shift;

	my $par=undef;
	if ( defined $self->basequery()) {
	$par=$self->basequery()->getparam($param);
        while ( ! defined $par ) {
          $self->basequery()->querytype( $param, "basic");
          $self->basequery()->querymessage( $param, $string);
          $self->userinterface()->askuser($self->basequery());
          $par=$self->basequery()->getparam($param);
        }
	}
	return $par;
}

sub askuser {
	my $self=shift;
	return $self->userinterface()->askuser(@_);
}

sub getfile {
	my $self=shift;
	my $origurl=shift; 

	my $fileref;
	my ($url, $file);
	if ( (defined ($it=$self->option('url_update'))) &&
		( $it eq "1" || $origurl=~/^$it/ )) {
	     $self->verbose("Forced download of $origurl");
	     ($url, $file)=$self->{urlhandler}->download($origurl);
	}
	else {
	   $self->verbose("Attempting to get $origurl");
	   ($url, $file)=$self->{urlhandler}->get($origurl);
	}
	# do we already have an appropriate object?
	($fileref)=$self->config()->find($url);
	#undef $fileref;
	if (  defined $fileref ) {
	 $self->verbose("Found $url in database");
	 $fileref->update();
	}
	else {
	 if ( $file eq "" ) {
	   $self->parseerror("Unable to get $origurl");
	 }
	 #-- set up a new preprocess file
	 $self->verbose("Making a new preprocessed file $url");
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
#	my $fileob=$self->getfile($url);

	# now parse it for the <DocType> tag
	my $tempdoc=ActiveDoc::ActiveDoc->new($self->config());
	$tempdoc->{urlhandler}=$self->{urlhandler};
	my $fullurl=$tempdoc->url($url);
	$url=$fullurl;
	$tempdoc->{doctypefound}=0;
	$tempdoc->newparse("doctype");
	$tempdoc->addtag("doctype","Doc", \&Doc_Start, $tempdoc,
                                          "", $tempdoc, "", $tempdoc);
	$tempdoc->parse("doctype");

	if ( ! defined $tempdoc->{docobject} ) {
          print "No <Doc type=> Specified in ".$url."\n";
          exit 1;
        }
	# Set up a new object of the specified type
	eval "require $tempdoc->{docobject}";
        die $@ if $@;
	my $newobj=$tempdoc->{docobject}->new($self->config());
	undef $tempdoc;
	$newobj->url($url);
	$newobj->parent($self);
	$newobj->_initparse();
	return $newobj;
}

sub parent {
	my $self=shift;

	@_?$self->{parent}=shift
	  :$self->{parent};
}

sub _initparse {
	my $self=shift;

	$self->parse("init");
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
		$self->error($string);
	}
	else {
	 ($line, $file)=$self->line();
         print "Parse Error in ".$file->url().", line ".
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

sub ProcessFile {
	my $self=shift;

	return $self->{File}->ProcessedFile();
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
		$self->parseerror("Parse Error : unmatched </$name>");
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

sub _saveactivedoc {
	my $self=shift;
	my $fh=shift;
	print "Storing $self\n";
	print $fh $self->url()."\n";
}

sub _restoreactivedoc {
	my $self=shift;
        my $fh=shift;

	my $url=<$fh>;
	chomp $url;
	$self->url($url);
}
