#
# ActiveDoc.pm
#
# Originally Written by Christopher Williams
#
# Description
#
# Interface
# ---------
# new(ActiveStore)		: A new ActiveDoc object
# url()	        : Return/set the docs url - essential
# file()	: Return the local filename of document
# ProcessFile() : Return the filename of PreProcessed document
#
# parent()	   : return the object ref of the calling parent
# getfile(url)	: get a processedfile object given a url
# activatedoc(url) : Return the object ref for a doc described by the given url
#
# -- error methods --
# error(string)       : Report an general error to the user
# parseerror(string)  : Report an error during parsing a file
# line([linenumber])	 : Return the line number of the document
#			and the ProcessedFileObj it is in corresponding to the
#			supplied number of the expanded document
# 			If no number supplied - the currentparse number will be #			used

package ActiveDoc::ActiveDoc;
require 5.004;
use ActiveDoc::SimpleURLDoc;
use ActiveDoc::PreProcessedFile;
use Utilities::Verbose;

@ISA = qw(ActiveDoc::SimpleURLDoc Utilities::Verbose);

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;
	$self->{Ostore}=shift;
	$self->cache($self->{Ostore}->cache());
	$self->{dbstore}=$self->{Ostore};
	$self->_initdoc("doc",@_);
#	$self->{switch}=ActiveDoc::SimpleURLDoc->new($self->{cache});
	return $self;
}

sub url {
	my $self=shift;
	# get file & preprocess
	if ( @_  ) {
	 	$self->{origurl}=shift;
		$self->{File}=$self->getfile($self->{origurl});
		$self->filetoparse($self->{File}->ProcessedFile());
		$self->verbose("url downloaded to ".$self->{File}->ProcessedFile());
	} 
	if ( defined $self->{File} ) {
	  return $self->{File}->url();
	}
	else { return "undefined"; }
}

sub getfile {
	my $self=shift;
	my $origurl=shift; 

	my $fileref;
	my ($url, $file);
	if ( 0 ) {
	     $self->verbose("Forced download of $origurl");
	     ($url, $file)=$self->urldownload($origurl);
	}
	else {
	   $self->verbose("Attempting to get $origurl");
	   ($url, $file)=$self->urlget($origurl);
	}
	# do we already have an appropriate object?
	($fileref)=$self->{dbstore}->find($url);
	if (  defined $fileref ) {
	 $self->verbose("Found $url in database");
	 $fileref->update();
	}
	else {
	 if ( $file eq "" ) {
	   $self->parseerror("Unable to get $origurl");
	 }
	 # -- set up a new preprocess file
	 $self->verbose("Making a new preprocessed file $url");
	 $fileref=ActiveDoc::PreProcessedFile->new($self->{Ostore});
	 #$fileref->cache($self->{cache});
	 $fileref->url($url);
	 $fileref->update();
	}
	return $fileref;
}

sub activatedoc {
	my $self=shift;
	my $url=shift;

	# first get a preprocessed copy of the file 
	my $fileobj=$self->getfile($url);

	# now parse it for the <Doc> tag
	my $tempdoc=ActiveDoc::SimpleURLDoc->new($self->{cache});
	$tempdoc->filetoparse($fileobj->ProcessFile());
	my ($doctype,$docversion)=$tempdoc->doctype();
	undef $tempdoc;
	
	if ( ! defined $doctype ) {
	  $self->parseerror("No <Doc type=> Specified in ".$url);
        }
	$self->verbose("doctype required is $doctype $docversion");

	# Set up a new object of the specified type
	eval "require $doctype";
        die $@ if $@;
	my $newobj=$doctype->new($self->{Ostore}, $url);
	$newobj->url($url);
	#$newobj->parent($self);
	return $newobj;
}

sub parent {
	my $self=shift;

	@_?$self->{parent}=shift
	  :$self->{parent};
}

# -------- Error Handling and Error services --------------

sub parseerror {
        my $self=shift;
        my $string=shift;

	if ( $self->currentparsename() eq "" ) {
		$self->error($string);
	}
	elsif ( ! defined $self->{File} ) {
	 print "Parse Error in ".$self->filenameref()." line "
				.$self->{currentparser}->line()."\n";
         print $string."\n";
	}
	else {
	 ($line, $file)=$self->line();
         print "Parse Error in ".$file->url().", line ".
                                        $line."\n";
         print $string."\n";
	}
        exit;
}

sub line {
	my $self=shift;
	my $parseline;

	if ( @_ ) {
	  $parseline=shift;
	}
	else {
	  $parseline=$self->{currentparser}->line();
	}

	my ($line, $fileobj)=
		$self->{File}->realline($parseline);
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

#
# Delegate all else to the switch
#
#sub AUTOLOAD {
#        my $self=shift;

        # dont propogate destroy methods
#        return if $AUTOLOAD=~/::DESTROY/;

        # remove this package name
#        ($name=$AUTOLOAD)=~s/ActiveDoc::ActiveDoc:://;

        # pass the message to SimpleDoc
#        $self->{switch}->$name(@_);
#}


# ------------------- Tag Routines -----------------------------------
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
