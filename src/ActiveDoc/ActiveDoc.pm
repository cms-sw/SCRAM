#
# The base functionality for the ActiveDocument - inherits from Basetags
#
# Inherits from BaseTags
# --------
# Interface
# ---------
# new(filename, DOChandler): create a new object based on a file and
#                                 associate with a base DOChandler
# parse()			: parse the input file
# include(url) : Activate include file mechanism, returns the object ref if OK
# treenode()   : return the associated TreeNode object reference
# getincludeObjectStore : Return a pointer to the ObectStore that contains all
#                         included objects
# find(string)	: find the object reference related to string in the associated
#		  tree. Mechanism for getting object references
# _addgroup()	: Add group functionality to document
# parseerror(String) : Report an error to the user
# userinterface()	: return the default User Interface object
# checktag($hashref, param , tagname) : Check a hash returned from switcher
#					for a given parameter

package ActiveDoc::ActiveDoc;
require 5.001;
use ActiveDoc::DOChandler;
use ActiveDoc::TreeNode;
use ActiveDoc::UserQuery;
use ObjectStoreCont;

@ISA = qw(BaseTags);

# Initialise
sub _init {
	my $self=shift;
	my $DOChandler=shift;
	my $OC=shift;

	$self->_addurl();
	$self->{urlhandler}->setcache($DOChandler->defaultcache());
	$self->{treenode}=ActiveDoc::TreeNode->new();
        $self->{dochandler}=$DOChandler;
	$self->{UserQuery}=$DOChandler->{UserQuery};
        $self->{tags}->addtag("Use", \&Use_Start, "", "");
	# Add the minimal functionality tag - feel free to override
        $self->{tags}->addtag("Include", \&Include_Start, "", "");
	$self->init();
}

sub init {
	# Dummy Routine - override for derrived classes
}
#
# use mechanism
#
sub include {
        my $self=shift;
        my $url=shift;
	my $linkfile=shift;
	my $filename;
        my $obj;

	$file=$self->{urlhandler}->get($url);
	if ( $linkfile ne "" ) {
	  $filename=$file."/".$linkfile;
	}
        $obj=$self->{dochandler}->newdoc($filename);

	# Now Extend our tree
	$self->{treenode}->grow($obj->treenode());
        return $obj;
}

sub userinterface {
	my $self=shift;
	return $self->{dochandler}->{UserInterface};
}

sub treenode {
	my $self=shift;
	return $self->{treenode};
}

sub getincludeObjectStore {
        my $self=shift;
        return $self->{includeOS};
}

sub find($) {
	my $self=shift;
	my $string=shift;
	my $tn;

	$tn=$self->{treenode}->find($string);
	if ( $tn eq "" ) {
	  $self->parseerror("Unable to find $string");
	}
	return $tn->associate();
}

sub line {
	my $self=shift;
	return $self->{switch}->line();
}

sub error {
	my $self=shift;
	my $string=shift;

	die $string."\n";

}
sub parseerror {
	my $self=shift;
	my $string=shift;

	print "Parse Error in $self->{url}, line ".
					$self->line()."\n";
	print $string."\n";
	die;
}

sub checktag {
	my $self=shift;
	my $hashref=shift;
	my $param=shift;
	my $tagname=shift;

	if ( ! exists $$hashref{$param} ) {
	  $self->parseerror("Incomplete Tag <$tagname> : $param required");  
	}
}

# ------------------------ Tag Routines ------------------------------
#
# The Include tag
#

sub Include_Start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

        $self->{switch}->checkparam( $name, "ref");
	print "<Include> tag not yet implemented\n";
#        $self->include($$hashref{'ref'},$$hashref{'linkdoc'});
}

sub Use_Start {
	my $self=shift;
        my $name=shift;
        my $hashref=shift;

	print "<Use> tag not yet implemented\n";
}
