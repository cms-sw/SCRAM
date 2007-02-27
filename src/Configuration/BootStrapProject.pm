=head1 NAME

Configuration::BootStrapProject - File parsing utilities for boot files.

=head1 SYNOPSIS

	my $obj = Configuration::BootStrapProject->new([$area]);

=head1 DESCRIPTION

Package containing functions for parsing bootstrap files (project initialisation documents).
These documents are written in XML.

=head1 METHODS

=over

=cut

=item C<new($cache,$installbase)>

A new bootstrapper.

=item C<boot(url[,$devareaname])>

Boot up a new project and return the Configuration::ConfigArea.

=back

=head1 AUTHOR

Originally written by Christopher Williams.

=head1 MAINTAINER

Shaun ASHBY

=cut

package Configuration::BootStrapProject;
use ActiveDoc::SimpleURLDoc;
use URL::URLhandler;
use Utilities::Verbose;
require 5.004;

@ISA=qw(Utilities::Verbose);
$Configuration::BootStrapProject::self;

sub new()
   {
   my $class=shift;
   # Initialise the global package variable:
   no strict 'refs';
   $self = defined $self ? $self
      : (bless {}, $class );
   $self->{havesourcedir}=0;
   $self->{cache}=shift;   
   $self->{baselocation}=shift;
   
   if ( @_ )
      {
      $self->{area}=shift;
      }
   
   $self->{mydoctype}="Configuration::BootStrapProject";
   $self->{mydocversion}="1.0";   
   $self->{scramdoc} = ActiveDoc::SimpleURLDoc->new($self->{cache});
   $self->{scramdoc}->newparse("bootstrap",$self->{mydoctype},'Subs');
   $self->{Arch}=1;
   push @{$self->{ARCHBLOCK}}, $self->{Arch};
   return $self;
   }

sub boot()
   {
   my $self=shift;
   my $url=shift;	
   my $filemode = 0644;
   # Check that the boot file is XML (simplistic check: make sure file
   # suffix is xml!):
   if ($url !~ /xml$/) {
       die __PACKAGE__.": Wrong boot file type (MUST be XML!)\n";
   }
   
   # -- override directory name
   if ( @_ )
      {
      $self->{devareaname}=shift;
      }
   else
      {
      $self->{devareaname}="";
      }
   
   my ($fullurl,$filename)=$self->{scramdoc}->urldownload($url);
   chmod $filemode,$filename;
   $self->{scramdoc}->filetoparse($filename);
   $self->{scramdoc}->parse("bootstrap");
   return $self->{area};
   }

# --- Tag Routines
sub project()
   {
   my ($xmlparser,$name,%attributes)=@_;
   my $name = $attributes{'name'};
   my $version = $attributes{'version'};
   
   print "Creating New Project ".$name.
      " Version ".$version."\n";
   print "\n";
   
   use Configuration::ConfigArea;
   $self->{area}=Configuration::ConfigArea->new();
   
   $self->{area}->name($name);
   $self->{area}->version($version);
   $self->{area}->setup($self->{baselocation});
   
   # new urlhandler based on area cache
   $self->{scramdoc}->cache($self->{area}->cache());
   }

sub project_()
   {
   my ($xmlparser,$name,%attributes)=@_;
   $self->{area}->sourcedir('src');
   $ENV{SCRAM_SOURCEDIR} = $self->{area}->sourcedir();
   $self->{area}->save();
   }

sub config()
   {
   my ($xmlparser,$name,%attributes)=@_;
   # Set the project config dir variable here so that
   # "projconfigdir" value can be used while bootstrapping:
   $ENV{SCRAM_CONFIGDIR} = $attributes{'dir'};
   $self->{area}->configurationdir($attributes{'dir'});
   }

sub download()
   {
   my ($xmlparser,$name,%attributes)=@_;
   # -- download into top directory
   my ($fullurl,$filename)=$self->{scramdoc}->urlget($attributes{'url'},
						     $self->{area}->location()."/".$attributes{'name'});   
   }

sub requirementsdoc() {
    my ($xmlparser,$name,%attributes)=@_;
    my ($filename,$fullurl);
    
    if ( exists $attributes{'url'} ) {
	# -- download into our cache
	($fullurl,$filename)=$self->{scramdoc}->urlget($attributes{'url'});
    } else {
	$filename=$attributes{'name'};
    }
    
    # Check that the requirements file is XML (simplistic check: make sure file
    # suffix is xml!):
    if ($filename !~ /xml$/) {	
	# We have to use exit here because die() doesn't respond...I guess
	# that SIG{__DIE__} has been trapped somewhere:
	print __PACKAGE__.": Wrong requirements file type (MUST be XML!)\n";
	exit(1);
    }
    
    $self->{area}->requirementsdoc($filename);   
}

sub doc()
   {
   my ($xmlparser,$name,%attributes)=@_;
   my $doctype = $attributes{'type'};

   if ($doctype ne $self->{mydoctype})
      {
      warn "Configuration::BootStrapProject::boot: Unable to handle doc of type $doctype";
      }
   }

sub AUTOLOAD()
   {
   my ($xmlparser,$name,%attributes)=@_;
   return if $AUTOLOAD =~ /::DESTROY$/;
   my $name=$AUTOLOAD;
   $name =~ s/.*://;
   if ($name eq 'base' || $name eq 'base_')
      {
      $self->{scramdoc}->$name(%attributes);
      }
   }

1;
