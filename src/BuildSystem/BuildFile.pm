#
# BuildFile.pm - An Active Document
#
# Originally Written by Christopher Williams
#
# Description
# -----------
# Parse a BuildFile to figure out the required build rules
#
# Interface
# ---------
# new()		: A new BuildFile object

package BuildSystem::BuildFile;
require 5.001;
@ISA=qw(ActiveDoc)

sub init {
	my $self=shift;

	# set up our data structures
	$self->{Benv}=BuildEnvironment->new();
	# Specific tags
	# environment tags
	$self->{tags}->addtag("Environment", \&Environment_Start, "", 
			\&Environment_End);
	# bin tags
	$self->{bincontext}=0;
	$self->{tags}->addtag("bin", \&bin_Start, \&bin_text, \&bin_End);

	$self->_addignore();
}

# --------------------- Support Routines ----
sub _expandvars {
	my $self=shift;
	my $string=shift;

	# Deal with Use in the environment
	
	# expand directly from the local build Env
	$self->{Benv}->expandvars($string);
}

# ------------------- Tag Routines ------------------------------

sub Environment_Start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->{Benv}->newenv();
	
}

sub Environment_End {
        my $self=shift;
        my $name=shift;
        my $hashref=shift;

	$self->{Benv}->restoreenv();
}

sub Use_Start {
	my $self=shift;
        my $name=shift;
        my $hashref=shift;

	# checks
	$self->checktag($hashref, 'name' ,$name );

	$self->{Benv}->addparam('scram_use', $$hashref->{'name'});
	$self->{Benv}->addparam('scram_use_group', $$hashref->{'group'});
}

# ---- binary specific tags
sub bin_Start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;
	
	my $extension;

	# checks
	if ( $self->{bincontext} == 0 ) {
	  $self->{bincontext}=1;
	  $self->checktag($hashref, 'file' ,$name );
	  ($extension=$$hashref{file})=~s/.*\.//;
	  if ( ! defined $$hashref{name} ) {
                ($$hashref{name}=$$hashref{file})=~s/\..*//;
          }

	  push @{$self->{bins}}, $self->_expandvars(
		$self->{Toolbox}->gettool($extension, "exe"));
	}
	else {
	  $self->parseerror("Attempt to open a new <$name> before a </$name>");
	}
} 

sub bin_text {
	my $self=shift;
        my $name=shift;
	my $string=shift;

	push @{$self->{binstext}}, $string;
}

sub bin_End {
	my $self=shift;
        my $name=shift;

	$self->{bincontext}=0;
}

sub lib_start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;
}

# libray specific tags
sub libtype {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;
}
