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
   my $arg="";
   foreach my $a (@ARGV){$arg.=" '$a'";}
   my $makecmd=$self->{GMAKECMD}.$self->{CMDOPTS}." -f $makefile $arg";
   my $errfile=$ENV{SCRAM_INTwork}."/build_error";
   unlink($errfile);
   exec("($makecmd && [ ! -e $errfile ]) || (err=\$?; echo gmake: \\*\\*\\* [There are compilation/build errors. Please see the detail log above.] Error \$err && exit \$err)") || die "SCRAM MakeInterface::exec(): Unable to run gmake ...$!","\n";
   }

1;

