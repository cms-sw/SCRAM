package Configuration::BootStrapProject;
use ActiveDoc::SimpleURLDoc;
use Utilities::Verbose;
use SCRAM::MsgLog;
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
   $self->{baselocation}=shift;
   
   if ( @_ )
      {
      $self->{area}=shift;
      }
   
   $self->{scramdoc} = ActiveDoc::SimpleURLDoc->new();
   $self->{scramdoc}->newparse("bootstrap","Configuration::BootStrapProject",'Subs');
   $self->{Arch}=1;
   push @{$self->{ARCHBLOCK}}, $self->{Arch};
   return $self;
   }

sub boot()
   {
   my $self=shift;
   my $url=shift;	
   
   $url=~s/^\s*file://;
   $self->{scramdoc}->filetoparse($url);
   my $fhead='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><doc type="Configuration::BootStrapProject" version="1.0">';
   my $ftail='</doc>';
   $self->{scramdoc}->parse("bootstrap",$fhead,$ftail);
   return $self->{area};
   }

# --- Tag Routines
sub project()
   {
   my ($xmlparser,$name,%attributes)=@_;
   my $name = $attributes{'name'};
   my $version = $attributes{'version'};
   my $src=$attributes{'source'} || 'src';
   
   scramlogmsg("Creating New Project ".$name." Version ".$version."\n\n");
   
   use Configuration::ConfigArea;
   $self->{area}=Configuration::ConfigArea->new($ENV{SCRAM_ARCH});
   
   $self->{area}->name($name);
   $self->{area}->version($version);
   $self->{area}->sourcedir($src);
   $ENV{SCRAM_SOURCEDIR} = $src;
   $self->{area}->setup($self->{baselocation});
   }

sub project_()
   {
   my ($xmlparser,$name,%attributes)=@_;
   my $confdir = $self->{area}->location()."/".$self->{area}->configurationdir();
   my $conf="${confdir}/toolbox/$ENV{SCRAM_ARCH}";
   my $toolbox=$self->{toolbox};
   if (-d $toolbox)
      {
      use Utilities::AddDir;
      if (-d "${toolbox}/tools")
         {
	 Utilities::AddDir::adddir("${conf}/tools");
	 Utilities::AddDir::copydir("${toolbox}/tools/selected","${conf}/tools/");
	 Utilities::AddDir::copydir("${toolbox}/tools/available","${conf}/tools/");
	 }
      else
         {
         my $boot=$self->{scramdoc}->filetoparse();
         die "Project creating error. Missing directory \"${toolbox}/tools\" in the toolbox. Please fix file \"$boo\" and set a valid toolbox directory.";
         }
      }
   else
      {
      my $boot=$self->{scramdoc}->filetoparse();
      die "Project creating error. Missing toolbox directory \"${toolbox}\". Please fix file \"$boot\" and set a valid toolbox directory.";
      }
   $self->{area}->configchksum($self->{area}->calchksum());
   if (!-f "${confdir}/scram_version")
      {
      my $ref;
      if (open($ref,">${confdir}/scram_version"))
         {
	 print $ref "$ENV{SCRAM_VERSION}\n";
	 close($ref);
	 }
      else{die "ERROR: Can not open ${confdir}/scram_version file for writing.";}
      }
   $self->{area}->save();
   }

sub config()
   {
   my ($xmlparser,$name,%attributes)=@_;
   $ENV{SCRAM_CONFIGDIR} = $attributes{'dir'};
   $self->{area}->configurationdir($attributes{'dir'});
   }

sub toolbox () {
   my ($xmlparser,$name,%attributes)=@_;
   my $dir = $attributes{'dir'};
   $dir=~s/^\s*file://;
   $self->{toolbox}=$dir;
}

sub download()
   {
   my ($xmlparser,$name,%attributes)=@_;
   $self->{scramdoc}->urldownload ($attributes{'url'},$self->{area}->location()."/".$attributes{'name'});
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
