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
# new()		: A new Parse object
# addtag(name,start,text,end,$object)	: Add a new tag
# addgrouptags()  : add <Group> tag functionality
# addignoretags() : add <ignore> tag functionality
# parse(filename,[streamhandle], [streamexcludetag]) : 
#				parse the given file - turn on the stream
#				   function of the switcher if a filehandle
#				   supplied as a second argument
# line()	: return the current linenumber in the file
# tagstartline()	: return the linenumber of the last tag opening 
# includeparse(Parse) : include the settings from another parse object
# tags()		: return list of defined tags
# cleartags()		: clear of all tags
# opencontext(name)		: open a parse context
# closecontext(name)	: close a parse context
# includecontext(name)  : Process when in a given context
# excludecontext(name)  : No Processing when given context
# contexttag(tagname)   : Register the tagname as one able to change context
#			  if not registerd - the close tag will be ignored
#			  too if outside of the specified context!


package ActiveDoc::Parse;
require 5.004;
use ActiveDoc::Switcher;
use ActiveDoc::TagContainer;
use ActiveDoc::GroupChecker;

sub new {
	my $class=shift;
	$self={};
	bless $self, $class;
	$self->init();
	return $self;
}

sub init {
	my $self=shift;
	$self->{gc}=GroupChecker->new();
	$self->{gc}->include("all");
	$self->{tags}=ActiveDoc::TagContainer->new();
}

sub parse {
	my $self=shift;
	my $file=shift;
	
	# basic setup of switcher
	$self->{switch}=ActiveDoc::Switcher->new($file);
	$self->{switch}->usegroupchecker($self->{gc});
	$self->{switch}->usetags($self->{tags});

	# do we need to switch on the streamer?
	if ( @_ ) {
	   $fh=shift;
	   $self->{switch}->stream($fh);
	   foreach $tag ( @_ ) {
		$self->{switch}->streamexclude($tag);
	   }
	}

	# -- parse
	$self->{switch}->parse();
	undef $self->{switch};
}

sub line {
	my $self=shift;
	if ( defined $self->{switch} ) {
	  return $self->{switch}->line();
	}
	return undef;
}

sub tagstartline {
	my $self=shift;
	if ( defined $self->{switch} ) {
	  return $self->{switch}->tagstartline();
	}
	return undef;
}

sub includeparse {
	my $self=shift;
	my $obj=shift;

	my $tag;
	# copy the tags from  the remote parse object
	foreach $tag ( $obj->tags() ) {
	  $self->addtag($tag,$obj->{tags}->tagsettings($tag));
	}
	# now the group settings
}

sub addtag {
	my $self=shift;
	$self->{tags}->addtag(@_);
}

sub addgrouptags {
        my $self=shift;
        $self->{tags}->addtag("Group", \&Group_Start,$self, 
				"", $self, \&Group_End, $self);
        $self->{tags}->setgrouptag("Group");
}

sub addignoretags {
        my $self=shift;
        $self->{gc}->exclude("ignore");
        $self->{tags}->addtag("Ignore", \&Ignore_Start, $self,
			"",$self, \&Ignore_End,$self);
        $self->{tags}->setgrouptag("Ignore");
}

sub contexttag {
	my $self=shift;
	$self->{tags}->setgrouptag(shift);
}

sub opencontext {
	my $self=shift;
	$self->{gc}->opencontext(shift);
}

sub closecontext {
	my $self=shift;
	$self->{gc}->closecontext(shift);
}

sub includecontext {
	my $self=shift;
	my $name=shift;

	$self->{gc}->unexclude($name);
	$self->{gc}->include($name);
}

sub excludecontext {
	my $self=shift;
	my $name=shift;
	$self->{gc}->exclude($name);
	$self->{gc}->uninclude($name);
}

sub cleartags {
	my $self=shift;
	$self->{tags}->cleartags();
}

sub tags {
	 my $self=shift;
	 return $self->{tags}->tags();
}

# ---------  Basic Group Related Tags ---------------------------------

sub Group_Start {
        my $self=shift;
        my $name=shift;
        my $vars=shift;
        my $lastgp;

        $lastgp="group::".$$vars{name};
        $self->{switch}->checkparam($name, 'name');
        $self->{gc}->opencontext("group::".$$vars{name});

}

sub Group_End {
        my $self=shift;
        my $name=shift;
        my $lastgp;

        $self->{gc}->closelastcontext("group");
}

sub Ignore_Start {
        my $self=shift;
        my $name=shift;

        $self->{gc}->opencontext("ignore");
}

sub Ignore_End {
        my $self=shift;
        $self->{gc}->closecontext("ignore");
}

