package SCRAM::MsgLog;
require 5.004;
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(scramloginteractive scramlogmsg scramlogclean scramlogdump);

my $SCRAM_MESSAGE_LOG=[];
my $SCRAM_MESSAGE_LOG_IA=1;

sub scramloginteractive 
{
  $SCRAM_MESSAGE_LOG_IA = shift;
}

sub scramlogmsg
{
  while(my $d=shift)
  {
    if ($SCRAM_MESSAGE_LOG_IA){print "$d";}
    else{push @{$SCRAM_MESSAGE_LOG},$d;}
  }
}

sub scramlogclean
{
  $SCRAM_MESSAGE_LOG=[];
}

sub scramlogdump
{
  foreach my $msg (@{$SCRAM_MESSAGE_LOG})
  {
    print "$msg";
  }
  scramlogclean ();
}

1;
