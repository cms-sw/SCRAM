#
# SimpleURLDoc.pm. - Extends SimpleDoc with URL download functionality 
#
# Originally Written by Christopher Williams
#
# Description
# -----------
#
# Interface
# ---------
# new(URLcache[,DocVersionTag]	: A new SimpleURLDoc object. You can also
#				  specify an alternative doc version tag
# addbasetags(parse) 	: Add Base Tags to the given parse
# urlget(urlstring[,location]) : get the given url - using the cache. 
#				 Returns (url, filename)
# urldownload(urlstring[,location]) : get the given url ignoring any cached
#					version. Returns (url, filename)
# expandurl(urlstring)  : return a URLclass object of the given url expanded
#			  according to the base settings
# cache([cache])	: get/set the current URL cache
# doctype()		: return the (type,version) of the document
#			  as specified by the DocVersionTag

package ActiveDoc::SimpleURLDoc;
use ActiveDoc::SimpleDoc;
use URL::URLhandler;
require 5.001;
@ISA=qw(ActiveDoc::SimpleDoc);

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;
	$self->cache(shift);
        $self->_initdoc("doc",@_);
	return $self;
}

sub addbasetags {
	my $self=shift;
	my $parse=shift;

	$self->addtag($parse,"base", \&Base_start, $self,
				     "", $self,
				     \&Base_end,$self);
}

sub cache {
	my $self=shift;
	if ( @_ ) {
	  $self->{cache}=shift;
	  $self->{urlhandler}=URL::URLhandler->new($self->{cache});
	}
	return $self->{cache};
}

sub expandurl {
	my $self=shift;
	my $urlstring=shift;

	return $self->{urlhandler}->expandurl($urlstring);
}

sub urldownload {
	my $self=shift;
	my $urlstring=shift;

	($fullurl,$filename)=$self->{urlhandler}->download($urlstring, @_);
	if ( ( ! defined $filename ) || ( $filename eq "" ) ) {
	  $self->parseerror("Failed to get $fullurl");
	}
	return ($fullurl,$filename);
}

sub urlget {
	my $self=shift;
	my $urlstring=shift;

	($fullurl,$filename)=$self->{urlhandler}->get($urlstring, @_);
	
	if ( ( ! defined $filename ) || ( $filename eq "" ) ) {
	  $self->parseerror("Failed to get $fullurl");
	}
	return ($fullurl,$filename);
}

# ------------------------ Support Routines ---------------------------

# ------------------------ Tag Routines -------------------------------

sub Base_start {
        my $self=shift;
        my $name=shift;
        my $hashref=shift;

        $self->checktag($name, $hashref, "url");
        my $url=$self->{urlhandler}->setbase($$hashref{'url'});
	# Add store for url of the file currently being parsed. This info can
	# then be extracted in Requirements objects
	$self->{configurl}=$url;
        push @{$self->{basestack}}, $url->type();
}

sub Base_end {
        my $self=shift;
        if ( $#{$self->{basestack}} >= 0 ) {
          my $type=pop @{$self->{basestack}};
          $self->{urlhandler}->unsetbase($type);
        }
        else {
          $self->parseerror("Unmatched <$name>");
        }
}
