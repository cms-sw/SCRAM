#
# The base functionality for the ActiveDocument - inherits from Basetags
#
# Inherits from BaseTags
# --------
# Interface
# ---------
# new(filename, ObjectStoreCont): create a new object based on a file and
#                                 associate with the given ObjectStoreCont
# parse()			: parse the input file
# include(url) : Activate include file mechanism, returns the object ref if OK
# treenode()   : return the associated TreeNode object reference
# getincludeObjectStore : Return a pointer to the ObectStore that contains all
#                         included objects
# find(string)	: find the object reference related to string in the associated
#		  tree. Mechanism for getting object references


package ActiveDoc;
use BaseTags;
use DOChandler;
use ObjectStoreCont;

@ISA = qw (BaseTags);

# Initialise
sub _init {
	my $self=shift;
	my $OC=shift;

	$self->_addurl();
	$self->{OC}=$OC;
	$self->{treenode)=TreeNode->new();
	$self->{includeOS}=$self->{OC}->newStore();
        $self->{dochandler}=DOChandler->new($self->{includeOS});
	# Add the minimal functionality tag - feel free to override
        $self->{tags}->addtag("Include", \&Include_Start, "", "");
}

#
# Include mechanism
#
sub include {
        my $self=shift;
        my $url=shift;
        my $obj;

        $obj=$self->{dochandler}->newdoc($url);
	# Now Extend our tree
	$self->{treenode}->grow($obj->treenode());
        return $obj;
}

sub treenode {
	my $self=shift;
	return $self->treenode;
}

sub getincludeObjectStore {
        my $self=shift;
        return $self->{includeOS};
}

sub find($) {
	my $self=shift;
	my $string=shift;

	$self->{treenode}->find($string);
}

# ------------------------ Tag Routines ------------------------------
#
# A default Include tag
#
sub Include_Start {
        my $returnval;
        # Just call the basic - this is only a default wrapper for the
        # <INCLUDE> tag assuming with no futher processing of the DOCObjref
        $returnval=_includetag(@_)
        # dont return anything if its a basic tag
}

# ----------------------- Support Routines ---------------------------
#
# the real workings of the include tag returns the ref
#
sub _includetag {
        my $self=shift;
        my $name=shift;
        my $hashref=shift;

        $self->{switch}->checkparam( $name, "ref");
        $url=$$hashref{'ref'};
        return $self->include($url);
}

