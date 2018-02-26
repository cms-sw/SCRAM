#____________________________________________________________________ 
# File: BuildDataStorage.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::BuildDataStorage;
require 5.004;
use BuildSystem::BuildFile;
use Exporter;
use File::Basename;

@ISA=qw(Exporter);
@EXPORT_OK=qw( );

sub new()
  ###############################################################
  # new                                                         #
  ###############################################################
  # modified : Tue Jun 22 15:16:08 2004 / SFA                   #
  # params   :                                                  #
  #          :                                                  #
  # function :                                                  #
  #          :                                                  #
  ###############################################################
  {
  my $proto=shift;
  my $class=ref($proto) || $proto;
  my ($configdir) = @_;
  my $self=
     {
     BUILDTREE => {},                # Path/data pairs;
     STATUS => 0,                    # Status of cache
     VERBOSE => 0                    # Verbose mode (0/1);
     };	
  
  bless $self,$class;

  # The location of the top-level BuildFile:
  $self->{CONFIGDIR} = $configdir;

  # Somewhere to store the dependencies:
  $self->{DEPENDENCIES} = {};  # GLOBAL dependencies
  $self->{SKIPPEDDIRS} = {};   # Global skipped dirs
  $self->init_engine();
  
  return $self;
  }

#### The methods ####
sub datapath()
   {
   my $self=shift;
   my ($path)=@_;
   my $datapath;
   # At project-level, the path is src so just return src. Also,
   # if we received a BuildFile path that we need to determine the data path for,
   # check first to see if the path matches config/BuildFile. If it does, we have the top-level
   # datapath which should be src:
   my $conf="$ENV{SCRAM_CONFIGDIR}"; my $src=$ENV{SCRAM_SOURCEDIR};
   my $bf=$ENV{SCRAM_BUILDFILE};
   if ($path=~/^(${conf}\/${bf}(.xml|)|$src)$/)
      {
      return $src;
      }
   
   # For other paths, strip off the src dir (part of LOCALTOP) and the final BuildFile to
   # get a data position to be used as a key:
   ($datapath = $path) =~ s|^\Q$src\L/||;
   if ($datapath =~ m/(.*)\/$bf(.xml|)$/)
      {
      return $1;
      }
   
   return $datapath;
   }

sub check_global_config()
   {
   my $self=shift;
   my $found=0;
   foreach my $bf ("$ENV{SCRAM_BUILDFILE}.xml","$ENV{SCRAM_BUILDFILE}")
      {
      if (-f $self->{CONFIGDIR}."/${bf}")
         {
	 $found=1;
	 last;
	 }
      }
   if (! $found)
      {
      print "SCRAM error: no $ENV{SCRAM_BUILDFILE} at top-level (config)! Invalid area!","\n";
      exit(1);
      }
   
   return $self;
   }

sub scanbranch()
   {
   my $self=shift;
   my ($files, $datapath)=@_;
   my $bfbranch;
   my $buildfiles;
   # Fix (or rather hack) so that only the current buildfile is parsed, not the parent.
   # This is required becuase it's not desired to pick up dependencies from the level lower:
   # one should always do it via a <use name=x> to get the package deps. We don't care about
   # deps in subsystems (they're only used to define groups) and project-wide deps are added at
   # template level:
   my $file = $files->[0];
   return unless -f $file; # Just in case metabf() is empty...
   $bfbranch=BuildSystem::BuildFile->new();
   $bfbranch->parse($file);
   # Store:
   $self->storebranchmetadata($datapath,$bfbranch);
   return $self;
   }

sub buildtreeitem()
   {
   my $self=shift;
   my ($datapath)=@_;
   # This will return the TreeItem object for
   # the corresponding data path:
   return $self->{BUILDTREE}->{$datapath};
   }

sub updatedirbf ()
   {
   my ($self,$dircache,$path,$bf,$buildclass)=@_;
   use BuildSystem::TreeItem;
   my $treeitem = BuildSystem::TreeItem->new();
   my $datapath = $self->datapath($path); 
   $self->{BUILDTREE}->{$datapath} = $treeitem;
   if ($bf)
      {
      $treeitem->metabf($bf);
      $self->scan($bf, $datapath);
      }
   if (!$buildclass) {$buildclass=$self->buildclass($path);}
   my ($class, $classdir, $suffix) = @{$buildclass};
   $treeitem->class($class);
   $treeitem->classdir($classdir);
   $treeitem->suffix($suffix);
   $treeitem->path($path);
   $treeitem->safepath($path);
   $treeitem->parent($datapath);
   $treeitem->children($dircache->dircache());
   $treeitem->name();
   return $treeitem;
   }

sub updateproductstore()
   {
   my $self=shift;
   my $item = shift;
   if (exists $item->{RAWDATA} && exists $item->{RAWDATA}{content} && exists $item->{RAWDATA}{content}{PRODUCTSTORE})
   {
   my $store = {};
   foreach my $H (@{$item->{RAWDATA}{content}{PRODUCTSTORE}})
      {
      my $storename="";
      if ($H->{'type'} eq 'arch')
         {
	 if ($H->{'swap'} eq 'true')
	    {
	    $storename .= $H->{'name'}."/".$ENV{SCRAM_ARCH};
	    }
	 else
	    {
	    $storename .= $ENV{SCRAM_ARCH}."/".$H->{'name'};
	    }
      }
      else
	 {
	 $storename .= $H->{'name'};
	 }
	 my $key ="SCRAMSTORENAME_".uc($H->{'name'});
	 $key=~s/\//_/g;
	 $store->{$key}=$storename;
      }
      $item->productstore($store);
   }
}

sub getbf ()
   {
   my $self=shift;
   my $dpath=shift;
   my $bfile="";
   if (exists $self->{BUILDTREE}->{$dpath})
      {
      my $item=$self->{BUILDTREE}->{$dpath};
      if (defined $item)
	 {
	 my $bf = $item->metabf();
	 if (scalar(@$bf)>0){$bfile=$bf->[0];}
	 }
      }
   return $bfile;
   }

sub update()
   {
   my $self=shift;
   my ($dircache) = @_;

   my $newbf  = $dircache->get_data("ADDEDBF");
   my $newdir = $dircache->get_data("ADDEDDIR");
   my $remdir = $dircache->get_data("REMOVEDDIR");
   use File::Path;
   my $mkpath = $ENV{LOCALTOP}."/".$ENV{SCRAM_INTwork}."/MakeData";
   my $mkpubpath = $ENV{LOCALTOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/MakeData";
   mkpath("${mkpath}/DirCache",0,0755);
   mkpath("${mkpath}/RmvDirCache",0,0755);
   mkpath("$mkpubpath/DirCache",0,0755);
   my %runeng = ();
   my $projinfo=undef;
   eval ("use SCRAM_ExtraBuildRule;");
   if(!$@) {$projinfo = SCRAM_ExtraBuildRule->new();}
   if ($newbf)
      {
      foreach my $bf ("$ENV{SCRAM_BUILDFILE}.xml","$ENV{SCRAM_BUILDFILE}")
         {
         if (exists $newbf->{$ENV{SCRAM_CONFIGDIR}."/${bf}"})
	    {
            my $treeitem = $self->updatedirbf($dircache,$ENV{SCRAM_SOURCEDIR},$ENV{SCRAM_CONFIGDIR}."/${bf}");
            $self->updateproductstore($treeitem);
            $runeng{$ENV{SCRAM_SOURCEDIR}}=1;
            delete $newbf->{$ENV{SCRAM_CONFIGDIR}."/${bf}"};
	    last;
	    }
	 }
      }
   $self->{TOPLEVEL_FLAGS} = {};
   if ((exists $self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}) &&
       (exists $self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}->{RAWDATA}) &&
       (exists $self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}->{RAWDATA}->{content}) &&
       (exists $self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}->{RAWDATA}->{content}->{FLAGS}))
      {
      $self->{TOPLEVEL_FLAGS}=$self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}->{RAWDATA}->{content}->{FLAGS};
      }
   if ($newdir)
      {
      foreach my $path (keys %{$newdir})
         {
	 if (!exists $newdir->{$path}) {next;}
	 if ($path!~/^$ENV{SCRAM_SOURCEDIR}\/(.+)/){delete $newdir->{$path};next;}
	 if ($path eq "$ENV{SCRAM_SOURCEDIR}/$ENV{SCRAM_SOURCEDIR}"){print "****WARNING: SCRAM does not support to have directory $ENV{LOCALTOP}/$ENV{SCRAM_SOURCEDIR}/$ENV{SCRAM_SOURCEDIR}.\n";next;}
	 my $cinfo = $self->buildclass($path);
	 if ($cinfo && $cinfo->[2] ne ""){$dircache->prune($path,0,$cinfo->[2]);}
	 else
	    {
	    my $dpath = $self->datapath($path);
	    if (exists $dircache->{PACKMAP}{$dpath})
	       {
	       my $map=$dircache->{PACKMAP}{$dpath};
	       if (($remdir) && (exists $remdir->{$ENV{SCRAM_SOURCEDIR}."/${map}"}))
		  {
		  $bf=$self->getbf($map);
		  if ($bf){$newbf||={};$newbf->{$bf}=1;}
		  delete $newdir->{$path};
		  next;
		  }
	       }
	    else
	       {
	       $bf=$self->getbf($dpath);
	       if (($bf ne "") && ($newbf) && (!exists $newbf->{$bf})){delete $newdir->{$path};next;}
	       }
	    my $item = $self->updatedirbf($dircache,$path,"",$cinfo);
	    my $flag=0;
            if (!defined $projinfo)
               {
	       if ($cinfo->[0] eq "library"){$flag=1;}
               }
            else
               {
               $flag=$projinfo->isPublic($item->class());
               }
	    $runeng{$path}=1;
            if ($flag)
               {
               my $treeitem = $self->{BUILDTREE}->{$dpath};
	       my $parent=$treeitem->parent();
	       my $bf = $self->getbf($parent);
	       if ($bf)
	       {
	         $newbf||={};
		 $newbf->{$bf}=1;
		 if (!exists $runeng{$parent})
		    {
		    $runeng{$parent}=1;
		    delete $self->{BUILDTREE}->{$parent}{RAWDATA};
		    }
	       }
               $dircache->{PACKMAP}{$parent}=$dpath;
	       $item->publictype (1);
               }
	    }
	 }
      }
      
   my %mkrebuild=();
   $mkrebuild{"${mkpath}/RmvDirCache"}=1;
   if ($remdir)
      {
      foreach  my $path (keys %{$remdir})
         {
	 delete $remdir->{$path};
	 my $dpath=$self->datapath($path);
	 if (exists $self->{BUILDTREE}->{$dpath}){delete $self->{BUILDTREE}->{$dpath};}
	 foreach my $map (keys %{$dircache->{PACKMAP}})
	    {
	    if ($dircache->{PACKMAP}{$map} eq $dpath)
	       {
	       delete $dircache->{PACKMAP}{$map};
	       last;
	       }
	    }
	 my $spath = $path; $spath =~ s|/|_|g;
	 open(OFILE,">${mkpath}/RmvDirCache/${spath}.mk");
	 print OFILE "REMOVED_DIRS += $path\n";
	 close(OFILE);
	 my $mpath = "${mkpath}/DirCache/${spath}.mk";
	 if (-f $mpath){unlink $mpath;$mkrebuild{dirname($mpath)}=1;}
	 $mpath = "${mkpubpath}/DirCache/${spath}.mk";
	 if (-f $mpath){unlink $mpath;$mkrebuild{dirname($mpath)}=1;}
	 }
      }
      
   if ($newbf)
      {
      foreach my $bf (keys %{$newbf})
         {
         my $dpath = $self->datapath($bf);
	 if (exists $dircache->{PACKMAP}{$dpath}){$dpath = $dircache->{PACKMAP}{$dpath};}
	 if (!exists $self->{BUILDTREE}->{$dpath}){$dpath=$self->datapath($bf);}
	 $self->scan($bf,$dpath);
	 $self->{BUILDTREE}->{$dpath}->metabf($bf);
	 $runeng{"$ENV{SCRAM_SOURCEDIR}/${dpath}"} = $self->{BUILDTREE}->{$dpath};
	 delete $newbf->{$bf};
         }
      }
   foreach my $path (sort {$a cmp $b} keys %runeng)
      {
      my $dpath=$self->datapath($path);
      delete $newdir->{$path};
      if(!exists $self->{BUILDTREE}->{$dpath}){next;}
      my $treeitem = $self->{BUILDTREE}->{$dpath};
      $self->run_engine($treeitem);
      if (exists $treeitem->{MKDIR})
         {
         foreach my $d (keys %{$treeitem->{MKDIR}})
            {
            $d=~s/\/\//\//g;
            $mkrebuild{$d}=1;
            }
	 delete $treeitem->{MKDIR};
	 }
      }
    foreach my $dir (keys %mkrebuild)
       {
       open(MKFILE,">${dir}.mk") || die "Can not open file for writing: ${dir}.mk";
       close(MKFILE);
       if (-d $dir)
          {
          system("cd $dir; find . -name \"*\" -type f | xargs -n 2000 cat >> ${dir}.mk");
	  }
       }
   }

sub scan()
   {
   my $self=shift;
   my ($buildfile, $datapath) = @_;
   my $bfparse;
   $bfparse=BuildSystem::BuildFile->new($self->{TOPLEVEL_FLAGS},1);
   # Execute the parse:
   if (-e  $buildfile) {$bfparse->parse($buildfile);}
   # See if there were skipped dirs:
   my $skipped = $bfparse->skippeddirs($datapath);   
   # Check to see if there was an info array for this location.
   # If so, we extract the first element of the array (i.e. ->[1])
   # and store it under the datapath entry. This is just so that useful
   # messages explaining why the dir was skipped can be preserved.
   if (ref($skipped) eq 'ARRAY')
      {
      $self->skipdir($datapath,$skipped->[1]);
      }
   $self->storedata($datapath, $bfparse);

   return $self;
   }

sub init_engine()
   {
   my $self=shift;
   if (!exists $self->{TEMPLATE_ENGINE})
      {
      # Create the interface to the template engine:
      use BuildSystem::TemplateInterface;
      # Pass in the config dir as the location where templates live:
      $self->{TEMPLATE_ENGINE} = BuildSystem::TemplateInterface->new();
      }
   }

sub run_engine()
   {
   my $self=shift;
   my ($templatedata)=@_;
   $self->{TEMPLATE_ENGINE}->template_data($templatedata);
   $self->{TEMPLATE_ENGINE}->run();
   return $self;
   }

sub buildclass
   {
   my $self=shift;
   my ($path)=@_;
   my $cache=[];
   # From Lassi TUURA (with mods by me):
   #
   # Associate a path with ClassPath setting.
   # For now, just assumes global data has been scanned and class settings
   # are already known (in $self->{CONFIGDATA}->classpath()).   
   # Generate more optimal classpath data structure, only once.
   # Split every cache definition into an array of pairs, directory
   # name and class.  So ClassPath of type "+foo/+bar/src+library"
   # becomes [ [ "" "foo" ] [ "" "bar" ] [ "src" "library" ] ]

   my @CLASSPATHS=@{$self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}->rawdata()->{content}->{CLASSPATH}};
   # This does not work, even though classpath() is a valid method and rawdata()
   # returns an object blessed into the correct type:
   # my @CLASSPATHS=@{$self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}->rawdata()->classpath()};

   if (! scalar @$cache)
      {
      foreach my $classpath (@CLASSPATHS)
         {
	 push (@$cache, [map { [ split(/\+/, $_) ] } split(/\//, $classpath)]);
	 }
      }
   
   print "WARNING: No ClassPath definitions, nothing will be done!","\n",
   if (! scalar @$cache);
   # Now scan the class paths.  All the classpaths are given a rank
   # to mark how relevant they are, and then the best match is chosen.
   #
   # The ranking logic is as follows.  We scan each class path and
   # drop if it doesn't match at all.  For paths that match, we
   # record how many components of the class was *not* used to match
   # on the class: for a short $path, many classes will match.
   # For each path component we record whether the match was exact
   # (if the class part is empty, i.e. "", it's a wildcard that
   # matches everything).  Given these rankings, we pick
   #   - the *first* class that
   #   - has least *unmatched* components
   #   - with *first* or *longest* exact match sequence in
   #     left-to-right order.
   my @ranks = ();
   my @dirs = split(/\/+/, $path);
   CLASS: foreach my $class (@$cache)
      {
      # The first two members of $rank are fixed: how much of path
      # was and was not used in the match.
      my $rank = [[], [@dirs]];
      foreach my $component (@$class)
         {
	 my $dir = $rank->[1][0];
	 if (! defined $dir)
	    {
	    # Path exhausted.  Leave used/unused as is.
	    last;
            }
	 elsif ($component->[0] eq "")
	    {
	    # Wildcard match, push class and use up path
	    push(@$rank, [1, $component->[1]]);
	    push(@{$rank->[0]}, shift(@{$rank->[1]}));
            }
	 elsif ($component->[0] eq $dir)
	    {
	    # Exact match, push class and use up path
	    push(@$rank, [0, $component->[1]]);
	    push(@{$rank->[0]}, shift(@{$rank->[1]}));
    	    }
	 else
	    {
	    # Unmatched, leave used/unused as is.
	    last;
            }
	 }

      push(@ranks, $rank);
      }

   # If no classes match, bail out:
   if (! scalar @ranks)
      {
      return "";
      }
   
   # Sort in ascending order by how much was of class was not used;
   # the first entry has least "extra" trailing match data.  Then
   # truncate to only those equal to the best rank.
   my @sorted = sort { scalar(@{$a->[1]}) <=> scalar(@{$b->[1]}) } @ranks;
   my @best = grep(scalar(@{$_->[1]}) == scalar(@{$sorted[0][1]}), @sorted);

   # Now figure which of the best-ranking classes have the longest
   # exact match in left-to-right order (= which one is first, and
   # those with equal first exact match, longest exact match).
   my $n = 0;
   my $class = $best[$n][scalar @{$best[$n]}-1];
   # Return the class data:
   return [ $class->[1], join('/', @{$best[$n][0]}), join('/', @{$best[$n][1]}) ];
   }

sub storedata
   {
   my $self=shift;
   my ($datapath, $data)=@_;
   # Store the content of this BuildFile in cache:
   $self->{BUILDTREE}->{$datapath}->rawdata($data);
   return $self;
   }

sub removedata
   {
   my $self=shift;
   my ($removedpaths) = @_;
   
   foreach my $rd (@$removedpaths)
      {
      my $datapath = $self->datapath($rd);
      # Remove all data, recursively, from $datapath:
      $self->recursive_remove_data($datapath);
      }
   
   return $self;
   }

sub recursive_remove_data()
   {
   my $self=shift;
   my ($datapath)=@_;
   
   # Delete main entry in build data via TreeItem:
   if (exists($self->{BUILDTREE}->{$datapath}))
      {
      # We also must modify the parent TreeItem to remove the child
      # from SAFE_SUBDIRS as well as from CHILDREN array:      
      my $parent = $self->{BUILDTREE}->{$datapath}->parent();
      $self->{BUILDTREE}->{$parent}->updatechildlist($datapath);     
      
      # Get the children:
      my @children = $self->{BUILDTREE}->{$datapath}->children();
      
      foreach my $childpath (@children)
	 {
	 # The child path value is the datapath so can be used
	 # directly when deleting data entries
	 $self->recursive_remove_data($childpath);	 
	 }
      
      # Finally, delete the parent data (a TreeItem):
      delete $self->{BUILDTREE}->{$datapath};
      }
   
   # return:
   return $self;
   }

sub storebranchmetadata()
   {
   my $self=shift;
   my ($datapath,$data)=@_;
   
   # Store the content of this BuildFile in cache:
   $self->{BUILDTREE}->{$datapath}->branchmetadata($data);
   return $self;
   }

sub buildobject
   {
   my $self=shift;
   my ($datapath)=@_;

   if (exists($self->{BUILDTREE}->{$datapath}) && defined($self->{BUILDTREE}->{$datapath}->rawdata()))
      {
      return $self->{BUILDTREE}->{$datapath}->rawdata();
      }
   else
      {
      return undef;
      }
   }

sub metaobject
   {
   my $self=shift;
   my ($datapath)=@_;
   
   if (exists($self->{BUILDTREE}->{$datapath}) && defined($self->{BUILDTREE}->{$datapath}->branchmetadata()))
      {
      return $self->{BUILDTREE}->{$datapath}->branchmetadata();
      }
   else
      {
      return undef;
      }
   }

sub searchprojects()
   {
   my $self=shift;
   my ($group,$projectref)=@_;
   
   foreach my $pjt (keys %{$self->{SCRAM_PROJECTS}})
      {
      print "Checking for group $group in SCRAM project $pjt","\n", if ($ENV{SCRAM_DEBUG});
      # As soon as a project is found to have defined $group, we return
      # the project name:
      if (exists $self->{SCRAM_PROJECTS}->{$pjt}->{KNOWNGROUPS}->{$group})
	 {
	 # Store the project name and data path:
	 $$projectref="project ".uc($pjt)." (".$self->{SCRAM_PROJECTS}->{$pjt}->{KNOWNGROUPS}->{$group}."/".$ENV{SCRAM_BUILDFILE}.")";
	 return(1);
	 }
      }
   
   # No group found to have been defined already so return false:
   return (0);
   }

sub findgroup
   {
   my $self=shift;
   my ($groupname) = @_;

   if (exists $self->{KNOWNGROUPS}->{$groupname})
      {
      # If group exists, return data:
      return $self->{KNOWNGROUPS}->{$groupname};
      }
   else
      {
      # Not found so return:
      return(0);
      }
   }

sub knowngroups
   {
   my $self=shift;
   @_ ? $self->{KNOWNGROUPS}=shift
      : $self->{KNOWNGROUPS}
   }

sub scramprojectbases()
   {
   my $self=shift;
   return $self->{SCRAM_PROJECT_BASES};
   }

sub alldirs
   {
   my $self=shift;
   return @{$self->{ALLDIRS}};
   }

sub skipdir
   {
   my $self=shift;
   my ($dir, $message) = @_;   

   # Set the info if we have both args:
   if ($dir && $message)
      {
      $self->{SKIPPEDDIRS}->{$dir} = $message;
      }
   # If we have the dir name only, return true if
   # this dir is to be skipped:
   elsif ($dir)
      {
      (exists($self->{SKIPPEDDIRS}->{$dir})) ? return 1 : return 0;
      }
   else
      {
      # Dump the list of directories and the message for each:
      foreach my $directory (keys %{$self->{SKIPPEDDIRS}})
	 {
	 print "Directory \"",$directory,"\" skipped by the build system";
	 if (length($self->{SKIPPEDDIRS}->{$directory}->[0]) > 10)
	    {
	    chomp($self->{SKIPPEDDIRS}->{$directory}->[0]);
	    my @lines = split("\n",$self->{SKIPPEDDIRS}->{$directory}->[0]); print ":\n";
	    foreach my $line (@lines)
	       {
	       next if ($line =~ /^\s*$/);
	       print "\t-- ",$line,"\n";
	       }
	    print "\n";
	    }
	 else
	    {
	    print ".","\n";
	    }
	 }
      }
   }

# Keep a record of which packages are missed by each location
# so that, on subsequent updates, these can be inserted auto-
# matically in the metadata for the location:
sub unresolved()
   {
   my $self=shift;
   my ($location, $pneeded) = @_;   
   # Need to record a mapping "LOCATION -> [ missing packages ]" and a
   # reverse-lookup "<missing package> -> [ LOCATIONS (where update required) ]"   
   $self->{UNRESOLVED_DEPS_BY_LOC}->{$location}->{$pneeded} = 1;
   $self->{UNRESOLVED_DEPS_BY_PKG}->{$pneeded}->{$location} = 1;
   }

sub verbose
   {
   my $self=shift;
   # Turn on verbose mode:
   @_ ? $self->{VERBOSE} = shift
      : $self->{VERBOSE}
   }

sub cachestatus()
   {
   my $self=shift;
   # Set/return the status of the cache:
   @_ ? $self->{STATUS} = shift
      : $self->{STATUS}
   }

sub logmsg
   {
   my $self=shift;
   # Print a message to STDOUT if VERBOSE is true:
   print STDERR @_ if $self->verbose();
   }

sub name()
   {
   my $self=shift;
   # Set/return the name of the cache to use:
   @_ ? $self->{CACHENAME} = shift
      : $self->{CACHENAME}
   }

sub save()
   {
   my $self=shift;
   # Delete unwanted stuff:
   delete $self->{DEPENDENCIES};
   delete $self->{TEMPLATE_ENGINE};
   delete $self->{SCRAM_PROJECTS};
   delete $self->{SCRAM_PROJECT_BASES};
   delete $self->{TOPLEVEL_FLAGS};
   return $self;
   }

1;
