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
   return $self;
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
   $self->included_file($self->fullpath($attributes{'url'}));
   }

sub include_()
   {
   }

1;
