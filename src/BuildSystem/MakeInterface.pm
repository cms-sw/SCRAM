#____________________________________________________________________ 
# File: MakeInterface.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::MakeInterface;
require 5.004;

use Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw( );

sub new()
  {
  my $proto=shift;
  my $class=ref($proto) || $proto;
  my $self={ GMAKECMD => '${SCRAM_GMAKE_PATH}gmake', CMDOPTS => ' -r' };
  bless $self,$class;
  $|=1;
  return $self;
  }

sub exec()
   {
   my $self=shift;
   my ($makefile)=@_;
   my $makecmd=$self->{GMAKECMD}.$self->{CMDOPTS}." -f ".$makefile." ".join(" ",@ARGV);
   exec("$makecmd") || die "SCRAM MakeInterface::exec(): Unable to run gmake ...$!","\n";
   }

1;

