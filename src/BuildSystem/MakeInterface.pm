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
   my $job_args=0;
   my $job_val="";
   foreach my $a (@ARGV)
     {
     if($a=~/^(-j|--jobs=)([0-9]*)$/o)
       {
       $job_args=1;
       $job_val=$2;
       next;
       }
     if(($job_args) && ($job_val eq ""))
       {
       if ($a=~/^[0-9]+$/){$job_val=$a; next;}
       else{$job_val="0";}
       }
     $arg.=" '$a'";
     }
   if($job_args)
     {
     if($job_val=~/^(0+|)$/o)
       {
       my $os="$^O";
       if($os=~/darwin/io){$job_val=`sysctl -n hw.ncpu`;}
       else{$job_val=`nproc`;}
       chomp $job_val;
       if ($job_val!~/^[0-9]+$/o){$job_val="0";}
       }
     $arg.=" '-j' '${job_val}'";
     }
   my $makecmd=$self->{GMAKECMD}.$self->{CMDOPTS}." -f $makefile $arg";
   my $errfile=$ENV{SCRAM_INTwork}."/build_error";
   unlink($errfile);
   exec("($makecmd && [ ! -e $errfile ]) || (err=\$?; echo gmake: \\*\\*\\* [There are compilation/build errors. Please see the detail log above.] Error \$err && exit \$err)") || die "SCRAM MakeInterface::exec(): Unable to run gmake ...$!","\n";
   }

1;

