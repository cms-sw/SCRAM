package SCRAM::ProdSymLinks;
require 5.004;
use Exporter;
use File::Temp;

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;
	$self->readlinks();
	return $self;
}

sub readlinks
{
  my $self=shift;
  my $file="$ENV{HOME}/.scramrc/symlinks";
  my $ref;
  if(open($ref,$file))
  {
    while(my $line=<$ref>)
    {
      chomp $line;
      $line=~s/^\s*//;$line=~s/\s*$//;
      if(($line eq "") || ($line=~/^\s*#/)){next;}
      my ($link,$path,@extra)=split /:/,$line;
      $link=~s/^(.*?)\/.*$/$1/;
      while($link=~/^(.*)\$\((.+?)\)(.*)$/){$link="$1$ENV{$2}$3";}
      $self->{symlinks}{$link}=$path;
    }
    close($ref); 
  }
}

sub mklink
{
  my $self=shift;
  my $store=shift;
  my $prems=0755;;
  my $link=$store;
  $link=~s/^(.*?)\/.*$/$1/;
  use File::Path;
  if (!-e "$ENV{LOCALTOP}/${link}")
  {
    unlink "$ENV{LOCALTOP}/${link}";
    if (exists $self->{symlinks}{$link})
    {
      my $path=$self->{symlinks}{$link};
      while($path=~/^(.*)\$\((.+?)\)(.*)$/){$path="$1$ENV{$2}$3";}
      mkpath($path,0,$prems);
      $path = File::Temp::tempdir ( "${link}.XXXXXXXX", DIR => $path);
      if (($path ne "") && (-d $path))
      {symlink($path,"$ENV{LOCALTOP}/${link}");}
    }
  }
  mkpath("$ENV{LOCALTOP}/${store}",0,$prems);
}

1;
