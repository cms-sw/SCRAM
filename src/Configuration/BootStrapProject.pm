# Bootstrap file parser
#
# Interface
# ---------
# new(cache,installbase) : a new bootstrapper
# boot(url[,devareaname]) : boot up a new project , return the ConfigArea

package Configuration::BootStrapProject;
use ActiveDoc::SimpleURLDoc;
use URL::URLhandler;
use Utilities::Verbose;
require 5.004;

@ISA=qw(Utilities::Verbose);


sub new {
	my $class=shift;
        my $self={};
        bless $self, $class;
        $self->{cache}=shift;
        $self->{baselocation}=shift;
	$self->{mydoctype}="Configuration::BootStrapProject";
	$self->{mydocversion}="1.0";
        $self->{Arch}=1;
        push @{$self->{ARCHBLOCK}}, $self->{Arch};
        return $self;
}

sub _initswitcher {
        my $self=shift;
        my $switch=ActiveDoc::SimpleURLDoc->new($self->{cache});
        my $parse="boot";
        $switch->newparse($parse);
	$switch->addbasetags($parse);
	$switch->addtag($parse,"RequirementsDoc", \&ReqDoc_start, $self,
				       \&print_text, $self,
				       \&ReqDoc_end, $self);
	$switch->addtag($parse,"config", \&Config_start, $self,
				       "", $self,
				       "", $self);
	$switch->addtag($parse,"project", \&Project_start, $self,
				       \&print_text, $self,
				       \&Project_end, $self);
	$switch->addtag($parse,"download", \&GetToTop_start, $self,
				       \&print_text, $self,
				       "", $self);
	$self->{switch}=$switch;
}

sub boot {
	my $self=shift;
	my $url=shift;	

	# -- override directory name
	if ( @_ ) {
	  $self->{devareaname}=shift;
	}
	else {
	  $self->{devareaname}="";
	}

	# -- initialise file parser 
	$self->_initswitcher();
	my ($fullurl,$filename)=$self->{switch}->urldownload($url);
	$self->{switch}->filetoparse($filename);

	# -- document version check
	my ($doctype,$docversion)=$self->{switch}->doctype();
	if ( ( $doctype ne $self->{mydoctype}) && 
		( $docversion ne $self->{mydocversion}) ) {
	  $self->{switch}->parseerror("Can Only process documents of type ".
		$self->{mydoctype}." version ".$self->{mydocversion}.
		"\nAre you sure you are using the correct scram version?");
	}

	$self->{switch}->parse("boot");
	return $self->{area};
}

# --- Tag Routines

sub print_text {
	my $self=shift;
	my $name=shift;
	my @text=shift;

	print "@text\n";
}

sub Project_start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;

	$self->{switch}->checktag($name, $hashref, 'name');
	$self->{switch}->checktag($name, $hashref, 'version');
	print "Installing Project $$hashref{'name'} ".
		"Version $$hashref{'version'}\n";
	$self->{area}=Configuration::ConfigArea->new();
	$self->{area}->name($$hashref{'name'});
	$self->{area}->version($$hashref{'version'});
	$self->{area}->setup($self->{baselocation});

	# new urlhandler based on area cache
	$self->{switch}->cache($self->{area}->cache());
}

sub Project_end {
	my $self=shift;
	$self->{area}->save();
}

# Set where the project specific configuration files live for the project
sub Config_start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->{switch}->checktag($name, $hashref, "dir");
	$$hashref{'dir'}=~s/`//g;
	$self->{area}->configurationdir($$hashref{'dir'});
}

sub ReqDoc_start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;

	my ($filename,$fullurl);
	if ( exists $$hashref{'url'} ) {
	  # -- download into our cache
	 ($fullurl,$filename)=$self->{switch}->urlget($$hashref{'url'});
	}
	else {
	$self->{switch}->checktag($name, $hashref, "name");
	   $filename=$$hashref{'name'};
	}
	$self->{area}->requirementsdoc($filename);
}

sub GetToTop_start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;

	$self->{switch}->checktag($name, $hashref, "url");
	$self->{switch}->checktag($name, $hashref, "name");

	# -- download into top directory
	my ($fullurl,$filename)=$self->{switch}->urlget($$hashref{'url'},
			$self->{area}->location()."/".$$hashref{'name'});
}
