=head1 NAME

Utilities::Verbose - Add verbosity to the current package.

=head1 DESCRIPTION

Provide a verbosity framework.

=head1 METHODS

=over

=cut

=item C<new()>

   A new Verbose object.

=item C<verbose(string)>

   Print string in verbosity mode.

=item C<verbosity($sw)>

   Turn verbosity on or off ($sw is 0 or 1).

=back

=head1 AUTHOR

Originally Written by Christopher Williams.   
   
=head1 MAINTAINER

Shaun ASHBY 

=cut
   
package Utilities::Verbose;
require 5.004;

sub new {
	my $class=shift;
	$self={};
	bless $self, $class;
	$self->verbose("New ".ref($self)." Created");
	return $self;
}

sub verbosity {
	my $self=shift;
	if ( @_ ) {
	   $self->{verbose}=shift;
	}
	else {
	  my $id="VERBOSE_".ref($self);
	  if ( defined $ENV{$id} ) {
	     return $ENV{$id};
	  }
	}
	$self->{verbose};
}

sub verbose {
	my $self=shift;
	my $string=shift;

	if ( $self->verbosity() ) {
	  print ">".ref($self)."($self) : \n->".$string."\n";
	}
}

sub error {
	my $self=shift;
	my $string=shift;

	print STDERR $string."\n";
	exit 1;
}

1;

