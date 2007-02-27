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
#
# -- error methods --
# error(string)       : Report an general error to the user
# parseerror(string)  : Report an error during parsing a file
package ActiveDoc::ActiveDoc;
require 5.004;
use ActiveDoc::SimpleURLDoc;
use Utilities::Verbose;

@ISA = qw(ActiveDoc::SimpleURLDoc Utilities::Verbose);

sub new()
   {
   my $class=shift;
   my $self={};
   bless $self, $class;
   $self->{Ostore}=shift;
   $self->cache($self->{Ostore}->cache());
   $self->{dbstore}=$self->{Ostore};
   return $self;
   }

sub url()
   {
   my $self=shift;
   # get file & preprocess
   if ( @_  )
      {
      $self->{origurl}=shift;
      ($self->{url}, $self->{file})=$self->urlget($self->{origurl});
      $self->filetoparse($self->{file});
      } 
   }

sub included_file()
   {
   my $self=shift;
   @_ ? $self->{included_file} = shift
      : $self->{included_file};
   }

# ------------------- Tag Routines -----------------------------------
sub include()
   {
   my $self=shift;
   my (%attributes)=@_;
   my ($filename,$fullurl);
   
   if ( exists $attributes{'url'} )
      {
      # -- download into our cache
      ($fullurl,$filename)=$self->urlget($attributes{'url'});
      }
   else
      {
      $filename=$attributes{'name'};
      }
   # Set the file name of the included file:
   $self->included_file($filename);
   }

sub include_()
   {
   my $self=shift;

   }

1;
