package ActiveDoc::SimpleURLDoc;
use ActiveDoc::SimpleDoc;
require 5.001;
@ISA=qw(ActiveDoc::SimpleDoc);

sub new()
   {
   my $class=shift;
   my $self={};
   bless $self, $class;
   return $self;
   }
   
sub fullpath ()
   {
   my $self=shift;
   my $src=shift;
   $src=~s/^\s*file://;
   my $base=$self->{urlbase};
   if ($base ne "") {$src="${base}/${src}";}
   return $src;
   }

sub urldownload()
   {
   my $self=shift;
   my $src=$self->fullpath(shift);
   my $des=shift;
   $des=~s/^\s*file://;
   use Utilities::AddDir;
   use File::Basename;
   Utilities::AddDir::adddir(dirname($des));
   if (-f $src)
      {
      Utilities::AddDir::copyfile($src,$des);
      }
   elsif (-d $src)
      {
      Utilities::AddDir::copydir($src,$des);
      }
   }

# ------------------------ Tag Routines -------------------------------
sub base()
   {
   my $self=shift;
   my (%attributes)=@_;
   if (!exists $self->{configurl}){$self->{configurl}=[];}
   my $url=$attributes{'url'};
   $url=~s/^\s*file://;
   push @{$self->{configurl}},$url;
   $self->{urlbase}=$url;
   }

sub base_()
   {
   my $self=shift;
   $self->{urlbase}=pop @{$self->{configurl}};
   }

1;
