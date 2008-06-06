#____________________________________________________________________ 
# File: MakeInterface.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-06-22 14:49:43+0200
# Revision: $Id: MakeInterface.pm,v 1.6.4.1 2008/04/07 09:29:14 muzaffar Exp $ 
#
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::MakeInterface;
require 5.004;

use Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw( );

sub new()
  ###############################################################
  # new                                                         #
  ###############################################################
  # modified : Tue Jun 22 14:49:46 2004 / SFA                   #
  # params   :                                                  #
  #          :                                                  #
  # function :                                                  #
  #          :                                                  #
  ###############################################################
  {
  my $proto=shift;
  my $class=ref($proto) || $proto;
  my $self={ GMAKECMD => '${SCRAM_GMAKE_PATH}gmake', CMDOPTS => ' -r' };
  bless $self,$class;
  $|=1;

  # Useful help strings for the options we're supporting:
  # %help = (
  # 	   "s"     => " do not print any output",
  # 	   "j <n>" => " the number of processes to run simultaneously",
  # 	   "d"     => " run gmake in debug mode",
  # 	   "k"     => " continue for as long as possible after an error",
  # 	   "w"     => " print the working directory before and after entering it",
  # 	   "n"     => " print the commands that would be executed but do not run them",
  # 	   "p"     => " print the data base of rules after scanning makefiles, then build as normal"
  # 	   );

  # The options. These are collected in CMDOPTS:
  my %options =
     (
      "make"        => sub { }, # dummy so we can use help opt just for MakeInterface
      "s"           => sub { $self->{CMDOPTS}.=" -s" },
      "j=i"         => sub { $self->{CMDOPTS}.=" -j ".$_[1] },
      "d"           => sub { $self->{CMDOPTS}.=" -d" },
      "k"           => sub { $self->{CMDOPTS}.=" -k" },
      "printdir"    => sub { $self->{CMDOPTS}.=" -w" },
      "n"           => sub { $self->{CMDOPTS}.=" -n" },
      "printdb"     => sub { $self->{CMDOPTS}.=" -p" }
      );
  
  Getopt::Long::config qw(default no_ignore_case require_order bundling);
  
  if (! Getopt::Long::GetOptions(\%opts, %options))
     {
     print "SCRAM Warning: Ignoring unknown option.","\n";
     exit(1);
     }
  
  return $self;
  }

sub exec()
   {
   my $self=shift;
   my ($makefile)=@_;
   my $PID;
   my $makecmd=$self->{GMAKECMD}.$self->{CMDOPTS}." -f ".$makefile." ".join(" ",@ARGV);

   # Try without forking:
   exec "$makecmd" || die "SCRAM MakeInterface::exec(): Unable to exec()...$!","\n";
   }

1;

