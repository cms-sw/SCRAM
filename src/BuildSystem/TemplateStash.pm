package BuildSystem::TemplateStash;
require 5.004;
use Exporter;
@ISA=qw(Exporter);

sub new()
{
  my $class=shift;
  my $self={};
  $self->{stash}[0]={};
  $self->{index}=0;
  bless($self, $class);
  return $self;  
}

sub pushstash ()
{
  my $self=shift;
  push @{$self->{stash}},{};
  $self->{index}=$self->{index}+1;
}

sub popstash ()
{
  my $self=shift;
  if($self->{index}>0){pop @{$self->{stash}};$self->{index}=$self->{index}-1;}
}

sub stash()
{
  my $self=shift;
  my ($stash)=@_;
  if($stash)
  {
    $self->{stash}=[];
    $self->{stash}[0]=$stash;
    $self->{index}=0;
  }
  else{return $self;}
}

sub set()
{
  my $self=shift;
  my $key=shift || return;
  my $c=$self->{index};
  $self->{stash}[$c]{$key}=shift;
}

sub get()
{
  my $self=shift;
  my $key=shift || return "";
  my $c=$self->{index};
  for(my $i=$c;$i>=0;$i--){if(exists $self->{stash}[$i]{$key}){return $self->{stash}[$i]{$key};}}
  return "";
}

1;
