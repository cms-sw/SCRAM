#____________________________________________________________________ 
# File: BuildDataStorage.pm
#____________________________________________________________________ 
#  
# Author: Shaun Ashby <Shaun.Ashby@cern.ch>
# Update: 2004-06-22 15:16:01+0200
# Revision: $Id: BuildDataStorage.pm,v 1.3 2005/03/09 19:28:19 sashby Exp $ 
#
# Copyright: 2004 (C) Shaun Ashby
#
#--------------------------------------------------------------------
package BuildSystem::BuildDataStorage;
require 5.004;
use Exporter;
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
  
  # Initialize the Template Engine:
  $self->init_engine();
  
  return $self;
  }

sub grapher()
   {
   my $self=shift;
   my ($mode,$writeopt)=@_;
   
   if ($mode)
      {
      $mode =~ tr[A-Z][a-z];
      # Check to see what the mode is:
      if ($mode =~ /^g.*?/)
	 {	 
	 $self->{GRAPH_MODE} = 'GLOBAL';
	 # GLOBAL package graphing:
	 use BuildSystem::SCRAMGrapher;
	 $self->{SCRAMGRAPHER} = BuildSystem::SCRAMGrapher->new();
	 }
      elsif ($mode =~ /^p.*?/)
	 {
	 # All other cases assume per package. This means that each package
	 # is responsible for creating/destroying grapher objects and writing
	 # out graphs, if required:
	 $self->{GRAPH_MODE} = 'PACKAGE';
	 }
      else
	 {
	 print "SCRAM error: no mode (w=p,w=g) given for graphing utility!","\n";
	 exit(1);
	 }
      
      # Set write option:
      $self->{GRAPH_WRITE} = $writeopt;
      }
   else
      {
      print "SCRAM error: no mode (w=p,w=g) given for graphing utility!","\n";
      exit(1);
      }
   }

sub global_graph_writer()
   {
   my $self=shift;
   my $name='Project';   
   # Only produce graphs with DOT if enabled. This routine is
   # only used at Project level:
   if (defined($self->{SCRAMGRAPHER}) && $self->{GRAPH_WRITE})
      {
      my $data; # Fake data - there isn't a DataCollector object
      $self->{SCRAMGRAPHER}->graph_write($data, $name);
      delete $self->{SCRAMGRAPHER};
      }
   else
      {
      print "SCRAM error: can't write graph!","\n";
      exit(1);
      }
   
   return;
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
   if ($path eq "$ENV{LOCALTOP}/$ENV{SCRAM_CONFIGDIR}/BuildFile" || $path eq $ENV{SCRAM_SOURCEDIR})
      {
      return $ENV{SCRAM_SOURCEDIR};
      }
   
   # For other paths, strip off the src dir (part of LOCALTOP) and the final BuildFile to
   # get a data position to be used as a key:
   ($datapath = $path) =~ s|^\Q$ENV{SCRAM_SOURCEDIR}\L/||;
   
   if ($datapath =~ m|(.*)/BuildFile$|)
      {
      return $1;
      }
   
   return $datapath;
   }

sub check_global_config()
   {
   my $self=shift;
   my $topbuildfile = $self->{CONFIGDIR}."/BuildFile";
   
   if ( ! -f $topbuildfile )
      {
      print "SCRAM error: no BuildFile at top-level (config)! Invalid area!","\n";
      exit(1);
      }
   
   return $self;
   }

sub processtree()
   {
   my $self=shift;
   my $parent = $ENV{SCRAM_SOURCEDIR};
   $self->procrecursive($parent);
   return $self;
   }

sub updatetree()
   {
   my $self=shift;
   my ($startdir) = @_;
   print "Updating metadata from $startdir","\n",if ($ENV{SCRAM_DEBUG});   
   $self->updaterecursive($startdir);
   return $self;
   }

sub updatemkfrommeta()
   {
   my $self=shift;
   my ($startdir)=$ENV{SCRAM_SOURCEDIR};
   print "Updating Makefile from $startdir","\n",if ($ENV{SCRAM_DEBUG});
   $self->updatefrommeta($startdir);
   return $self;
   }

sub scanbranch()
   {
   my $self=shift;
   my ($files,$datapath)=@_;
   # Fix (or rather hack) so that only the current buildfile is parsed, not the parent.
   # This is required becuase it's not desired to pick up dependencies from the level lower:
   # one should always do it via a <use name=x> to get the package deps. We don't care about
   # deps in subsystems (they're only used to define groups) and project-wide deps are added at
   # template level:
   my $nfiles = [ $files->[0] ];
   
   # Scan all buildfiles in a branch:
   use BuildSystem::BuildFile;
   my $bfbranch=BuildSystem::BuildFile->new();
   $bfbranch->parsebranchfiles($nfiles);

   # Store:
   $self->storebranchmetadata($datapath,$bfbranch);
   return $self;
   }

sub procrecursive()
   {
   my $self=shift;
   my ($dir)=@_;
   my $datacollector;
   
   # Data for current dir:
   my $treedata = $self->buildtreeitem($dir);
   # Data for the parent:
   my $parent = $treedata->parent();
   my $parenttree = $self->buildtreeitem($parent);
   # Base classes. These are structural template classes which are fixed in SCRAM:
   my $baseclasses = [ qw( SUBSYSTEM PACKAGE ) ];   
   
   # If we have a parent dir, collect METABF. Skip inheriting from config/BuildFile:
   if (defined ($parenttree) && $parenttree->metabf() && $parent ne 'src')
      {
      # Add the meta (BuildFile) location to the current locations meta:
      $treedata->metabf(@{$parenttree->metabf()});
      }
   
   # Perfect match to class:
   if ($treedata->suffix() eq '')
      {
      # For directories where there's a full match to the classpath, check the class.
      # Only process Buildfiles if the match occurs for a build product class. In either case,
      # run the template engine.
      # Don't process BuildFiles unless we happen to be in a product branch (i.e.,
      # not a baseclass as defined above) except for Project which we do want:
      if (! grep($treedata->class() eq $_, @$baseclasses))
	 {
	 # Scan all BuildFiles in this branch:
	 $self->scanbranch($treedata->metabf(),$self->datapath($dir));
	 # Process the build data:
	 $datacollector = $self->processbuildfile($dir, $treedata->path());
	 $treedata->clean(); # Get rid of BRANCHMETA
	 $treedata->branchdata($datacollector);
	 }
      
      # And run the engine:
      $self->run_engine($treedata);
      
      foreach my $c ($treedata->children())
	 {
	 if ($c ne '')
	    {
	    $self->procrecursive($c);
	    }
	 }
      }
   else
      {
      # For directories where there isn't a full match, just run the template engine:
      $self->run_engine($treedata);
      
      foreach my $c ($treedata->children())
	 {
	 if ($c ne '')
	    {
	    $self->procrecursive($c);
	    }
	 }
      }
   
   return $self;
   }

sub updaterecursive()
   {
   my $self=shift;
   my ($dir)=@_;
   my $datacollector;
   # updaterecursive() only SCANS and UPDATES METADATA. The Makefile is rebuilt in
   # its entirety using updatefrommeta(), called after metadata is updated and stored:

   # Data for current dir:
   my $treedata = $self->buildtreeitem($dir);
   # Data for the parent:
   my $parent = $treedata->parent();
   my $parenttree = $self->buildtreeitem($parent);
   # Base classes. These are structural template classes which are fixed in SCRAM:
   my $baseclasses = [ qw( SUBSYSTEM PACKAGE ) ];   
   
   # If we have a parent dir, collect METABF. Skip inheriting from config/BuildFile:
   if (defined ($parenttree) && $parenttree->metabf() && $parent ne 'src')
      {
      # Add the meta (BuildFile) location to the current locations meta:
      $treedata->metabf(@{$parenttree->metabf()});
      }

   # Perfect match to class:
   if ($treedata->suffix() eq '')
      {
      # For directories where there's a full match to the classpath, check the class.
      # Only process Buildfiles if the match occurs for a build product class. In either case,
      # run the template engine.
      # Don't process BuildFiles unless we happen to be in a product branch (i.e.,
      # not a baseclass as defined above):
      if (! grep($treedata->class() eq $_, @$baseclasses))
	 {
	 # Scan all BuildFiles in this branch:
	 $self->scanbranch($treedata->metabf(),$self->datapath($dir));
	 # Process the build data:
	 $datacollector = $self->processbuildfile($dir, $treedata->path());
	 $treedata->clean();
	 $treedata->branchdata($datacollector);
	 }

      foreach my $c ($treedata->children())
	 {
	 if ($c ne '')
	    {
	    $self->updaterecursive($c);
	    }
	 }
      }
   else
      {
      foreach my $c ($treedata->children())
	 {
	 if ($c ne '')
	    {
	    $self->updaterecursive($c);
	    }
	 }
      }
   
   return $self;
   }

sub updatefrommeta()
   {
   my $self=shift;
   my $datacollector;
   my ($startdir)=@_;
   # Data for current dir:
   my $treedata = $self->buildtreeitem($startdir);
   # Run the engine:
   $self->run_engine($treedata);

   foreach my $c ($treedata->children())
      {
      if ($c ne '')
	 {
	 $self->updatefrommeta($c);
	 }
      }
   
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

sub bproductparse()
   {
   my $self=shift;
   my ($dataposition, $path, $bcollector, $product, $localg)=@_;
   my $packdir;
   
   if ($dataposition =~ m|(.*)/src|)
      {
      $packdir=$1;
      }
   elsif ($dataposition =~ m|(.*)/|)
      {
      $packdir=$dataposition;
      }
   
   # Probably better to use the bin name/safename:
   $packdir = $product->safename();
   my $label = $product->name();
   
   # Look for architecture-specific tags:
   if (my $archdata=$product->archspecific())
      {
      $bcollector->resolve_arch($archdata,$packdir);
      }
   
   # Groups:
   if (my @groups=$product->group())
      {
      $bcollector->resolve_groups(\@groups,$packdir);
      }
   
   # Check for packages and external tools:
   if (my @otheruses=$product->use())
      {
      $bcollector->localgraph()->vertex($packdir);

      # Add vertex and edges for current package and its dependencies:
      foreach my $OU (@otheruses)     
	 {
	 $bcollector->localgraph()->edge($packdir, $OU);
	 }
      
      $bcollector->resolve_use(\@otheruses);
      }
   
   # For each tag type that has associated data in this buildfile
   # data object, get the data and store it:
   map { my $subname = lc($_); $bcollector->storedata($_, $product->$subname(),$packdir); }
   $product->basic_tags();
   
   # Prepare the metadata for this location:
   my $graphexists = $bcollector->prepare_meta($packdir);

   # Write out the graph if required:
   if ($localg && $self->{GRAPH_WRITE} && $graphexists) 
      {
      $bcollector->localgraph()->graph_write($bcollector->attribute_data(), $packdir);
      }
   
   # Clean up:
   $bcollector->clean4storage();
   return $bcollector;
   }

sub processbuildfile()
   {
   my $self=shift;
   my ($dataposition, $path)=@_;
   my $collector;
   my $packdir;
   my $CURRENTBF = $self->metaobject($dataposition);
   my $localgrapher=0;
   my $scramgrapher;

   if (defined($CURRENTBF))
      {    
      use BuildSystem::DataCollector;	 
      
      # Graphing:
      if (! defined($self->{SCRAMGRAPHER}))
	 {
	 # We don't have a grapher object so we must we working at package level.
	 $localgrapher=1;
	 # Create the object here:
	 use BuildSystem::SCRAMGrapher;
	 $scramgrapher = BuildSystem::SCRAMGrapher->new();
	 }
      else
	 {
	 $scramgrapher = $self->{SCRAMGRAPHER};
	 }
      
      my %projects = %{$self->{SCRAM_PROJECTS}};
      my %projectbases = %{$self->{SCRAM_PROJECT_BASES}};
      
      # Set up the collector object:
      $collector = BuildSystem::DataCollector->new($self, $self->{TOOLMANAGER},
						   $path, \%projects, \%projectbases,
						   $scramgrapher);
      
      # Need the package name for our dep tracking:
      if ($dataposition =~ m|(.*)/src|)
	 {
	 $packdir=$1;
	 }
      elsif ($dataposition =~ m|(.*)/|)
	 {
	 $packdir=$dataposition;
	 }
      elsif ($dataposition eq $ENV{SCRAM_SOURCEDIR})
	 {
	 $packdir = $ENV{SCRAM_SOURCEDIR};
	 }
      
      # Look for architecture-specific tags:
      if (my $archdata=$CURRENTBF->archspecific())
	 {
	 $collector->resolve_arch($archdata,$packdir);
	 }
      
      # Groups:
      if (my @groups=$CURRENTBF->group())
	 {
	 $collector->resolve_groups(\@groups,$packdir);
	 }
      
      # Check for packages and external tools:
      if (my @otheruses=$CURRENTBF->use())
	 {
	 $scramgrapher->vertex($packdir);
	 
	 # Add vertex and edges for current package and its dependencies:
	 foreach my $OU (@otheruses)
	    {
	    $scramgrapher->edge($packdir, $OU);
	    }
	 
	 $collector->resolve_use(\@otheruses);
	 }
      
      # If we are at project-level, also resolve the 'self' tool. We ONLY do this
      # at project-level:
      if ($dataposition eq $ENV{SCRAM_SOURCEDIR})
	 {
	 $collector->resolve_use(['self']);	 
	 }
      
      # For each tag type that has associated data in this buildfile
      # data object, get the data and store it:
      map { my $subname = lc($_); $collector->storedata($_, $CURRENTBF->$subname(),$packdir); }
      $CURRENTBF->basic_tags();
            
      # Check for build products and process them here:
      my $buildproducts=$CURRENTBF->buildproducts();

      my $BUILDP = {};
      
      # If we have build products:
      if ($buildproducts)
 	 {
 	 # Build a list of target types that should built at this location in
 	 # addition to normal libraries:
	 foreach my $type (keys %$buildproducts)
	    {
	    my $typedata=$CURRENTBF->values($type);           
 	    while (my ($name,$product) = each %$typedata)
 	       {
	       # We make a copy from existing collector object. This is basically a "new()"
	       # followed by some copying of relevant data elements:
	       $bcollector = $collector->copy($localgrapher);
	       # The Product object inherits from same core utility packages
	       # as BuildFile so all BuildFile methods can be used on the Product object:
	       $self->bproductparse($dataposition,$path,$bcollector,$product,$localgrapher);
	       $product->data($bcollector);
 	       $BUILDP->{$product->safename()} = $product;
	       }
	    }
	 
	 # Return the hash of products (safe_name/Product object pairs):
	 return $BUILDP;	 
	 }
      else
	 {	 
	 # Prepare the metadata for this location. Also needed for each build product:
	 my $graphexists = $collector->prepare_meta($packdir);

	 # Write out the graph if required (also to be done for each product):
	 if ($localgrapher && $self->{GRAPH_WRITE} && $graphexists)
	    {
	    $scramgrapher->graph_write($collector->attribute_data(), $packdir);
	    }

	 # At this point I think we can clean away the graph object:
	 $collector->clean4storage();

	 # No products: return main collector:
	 return $collector;
	 }     
      }
   else
      {
      # No build data, just return:
      return $collector;
      }
   }

sub create_productstores()
   {
   my $self=shift;
   # This routine will only ever be run for top-level so
   # datapath can be coded here:
   my $datapath='src';
   my $tldata=$self->buildtreeitem($datapath);
   my $stores=$tldata->rawdata()->productstore();

   # Iterate over the stores:
   foreach my $H (@$stores)  
      {
      my $storename="";
      # Probably want the store value to be set to <name/<arch> or <arch>/<name> with
      # <path> only prepending to this value rather than replacing <name>: FIXME...
      if ($$H{'type'} eq 'arch')
	 {
	 if ($$H{'swap'} eq 'true')
	    {
	    (exists $$H{'path'}) ? ($storename .= $$H{'path'}."/".$ENV{SCRAM_ARCH})
	       : ($storename .= $$H{'name'}."/".$ENV{SCRAM_ARCH});
	    }
	 else
	    {
	    (exists $$H{'path'}) ? ($storename .= $ENV{SCRAM_ARCH}."/".$$H{'path'})
	       : ($storename .= $ENV{SCRAM_ARCH}."/".$$H{'name'});
	    }
	 }
      else
	 {
	 (exists $$H{'path'}) ? ($storename .= $$H{'path'})
	    : ($storename .= $$H{'name'});
	 }
      
      # Create the dir: FIXME: may need a more portable mkdir?
      system("mkdir","-p",$ENV{LOCALTOP}."/".$storename);
      }
   }

sub populate()
   {
   my $self=shift;
   my ($paths,$filecache,$toolmanager)=@_;
   my $datapath;
   my $buildfile;
   $|=1; # Flush
   
   # The tool manager:
   $self->{TOOLMANAGER} = $toolmanager;

   # Get scram projects from toolbox. Each project cache is loaded at this point too:
   $self->scramprojects();

   # Check that there's a global config. Exit if not:
   $self->check_global_config();
   
   # Loop over all paths. Apply a sort so that src (shortest path) is first (FIXME!):
   foreach my $path (sort(@$paths))
      {
      # Ignore config content here:
      next if ($path !~ m|^\Q$ENV{SCRAM_SOURCEDIR}\L|);

      # Set the data path:
      $datapath = $self->datapath($path);     
      
      # Create a TreeItem object:
      use BuildSystem::TreeItem;
      my $treeitem = BuildSystem::TreeItem->new();
      $self->{BUILDTREE}->{$datapath} = $treeitem;

      # If we have the project root (i.e. src), we want to process the
      # top-level (project config) BuildFile:
      if ($path eq $ENV{SCRAM_SOURCEDIR})
	 {
	 $buildfile = $ENV{SCRAM_CONFIGDIR}."/BuildFile";
	 # Parse the top-level BuildFile. We must do this here
	 # because we need the ClassPaths. Store as RAWDATA:
	 $self->scan($buildfile, $datapath);
	 # At this point, we've scanned the top-level BuildFile so we can
	 # create the store dirs and setup "self":
	 $self->create_productstores();
	 # We need scram project base vars at project-level:
	 $treeitem->scramprojectbases($self->{SCRAM_PROJECT_BASES});
	 }
      else
	 {
	 $buildfile = $path."/BuildFile";
	 }
      
      # If this BuildFile exists, store in METABF:
      if ( -f $buildfile )
	 {
	 # This level has a buildfile so store this path:
	 $treeitem->metabf($buildfile);
	 # Scan to resolve groups. Store as RAWDATA:
	 $self->scan($buildfile, $datapath);
	 ($ENV{SCRAM_DEBUG}) ? print "Scanning ",$buildfile,"\n" : print "." ;
	 }
      
      if ($self->skipdir($datapath))
	 {
	 $treeitem->skip(1);
	 print $datapath," building skipped.\n", if ($ENV{SCRAM_DEBUG});
	 }

      # Now add the class and path info to the TreeItem:
      my ($class, $classdir, $suffix) = @{$self->buildclass($path)};
      
      $treeitem->class($class);
      $treeitem->classdir($classdir);
      $treeitem->suffix($suffix);
      $treeitem->path($path);
      $treeitem->safepath($path);
      $treeitem->parent($datapath);
      $treeitem->children($filecache);
      $treeitem->name();
      }

   print "\n";

   # Check dependencies- look for cycles in the global dependency data:
   $self->check_dependencies();
   $self->skipdir() if ($ENV{SCRAM_DEBUG});
   }

sub check_dependencies()
   {
   my $self=shift;
   # Use the SCRAMGrapher to process the deps and return a
   # Graph object:
   use BuildSystem::SCRAMGrapher;   
   
   my $SG = BuildSystem::SCRAMGrapher->new($self->{DEPENDENCIES}); # GLOBAL dependencies
   my $G = $SG->_graph_init();
   my @classification = $G->edge_classify();
   my @cycles;
   my $status=0;

   # Dump the vertex classification if required:
   if ($ENV{SCRAM_DEBUG})
      {
      print "\n";
      print "Dumping vertex/path classifications:","\n";
      print "\n";
      printf("%-40s %-40s %-15s\n",'Vertex_i','Vertex_j','CLASS');
      printf("%-95s\n",'-'x95);
      }
   
   foreach my $element (@classification)
      {
      printf("%-40s %-40s %-15s\n",$element->[0],$element->[1],$element->[2]), if ($ENV{SCRAM_DEBUG});
      # Save our cycles to list separately:
      if ($element->[2] eq 'back')
	 {
	 push(@cycles,$element);
	 $status++;
	 }
      }
   
   print "\n";   
   if ($status)
      {
      map
	 {
	 print $::fail."SCRAM buildsystem ERROR:   Cyclic dependency ",$_->[0]," <--------> ",$_->[1].$::normal."\n";
	 } @cycles;
      print "\n";
      
      # Exit:
      exit(1);
      }
   
   # Otherwise return:
   return;
   }

sub update_toplevel()
   {
   my $self=shift;
   my (@buildfiles) = @_;
   my $treeitem;

   print "Re-scanning at top-level..\n";
   
   my $datapath = $self->datapath($ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR}."/BuildFile");
   
   # This updates the raw data:
   $self->scan($ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR}."/BuildFile", $datapath); 

   # Update everything else:
   foreach my $B (@buildfiles)
      {
      next if ($B eq $ENV{LOCALTOP}."/config/BuildFile");
      $datapath = $self->datapath($B);
      # Check to see if we already have the raw data for this buildfile.
      # Note that we won't if this scan was run from update mode. In this
      # case, we set up the TreeItem object:
      if (! exists($self->{BUILDTREE}->{$datapath}))
	 {	    
	 use BuildSystem::TreeItem;
	 $treeitem = BuildSystem::TreeItem->new();	 
	 my $path=$ENV{SCRAM_SOURCEDIR}."/".$datapath;
	 my ($class, $classdir, $suffix) = @{$self->buildclass($path)};

	 $treeitem->class($class);
	 $treeitem->classdir($classdir);
	 $treeitem->suffix($suffix);
	 $treeitem->path($path);
	 $treeitem->safepath($path);
	 $treeitem->parent($datapath);
	 $treeitem->children($filecache);
	 $treeitem->name();

	 $self->{BUILDTREE}->{$datapath} = $treeitem;

	 print "Scanning ",$B,"\n";
	 $self->scan($B,$datapath); # This updates the raw data
	 }
      else
	 {
	 print "Scanning ",$B,"\n";
	 $self->scan($B,$datapath); # This updates the raw data
	 }
      
      # Recursively update the tree from this data path:
      $self->updatetree($datapath);	 
      }   
   }

sub update()
   {
   my $self=shift;
   my ($changeddirs, $addeddirs, $bf, $removedpaths, $toolmanager, $filecache) = @_;
   my $buildfiles = {};
   # Copy the contents of the array of BuildFiles to a hash so that
   # we can track which ones have been parsed:
   map
      {
      $buildfiles->{$_} = 0;
      } @$bf;
   
   # Tool manager:
   $self->{TOOLMANAGER} = $toolmanager;
   # Get scram projects from toolbox. Each project cache is
   # loaded at this point too:
   $self->scramprojects();
   
   # Remove build data for removed directories:
   $self->removedata($removedpaths);
 
   # Now check to see if something changed at the top-level. If so we reparse everything:  
   my $toplevel = $ENV{LOCALTOP}."/".$ENV{SCRAM_CONFIGDIR}."/BuildFile";
   
   if (exists($buildfiles->{$toplevel}))
      {
      $buildfiles->{$toplevel} = 1; # Parsed
      $self->update_toplevel(@$bf);
      }
   else
      {
      # Process all new directories first then changed ones. This means that everything will be in
      # place once we start parsing any modified BuildFiles and once we run updatetree():

      $self->update_newdirs($addeddirs);

      $self->update_existingdirs($changeddirs);
            
      # Now check for any modified BuildFiles that have not yet been rescanned:
      foreach my $bftoscan (keys %$buildfiles)
	 {
	 if ($buildfiles->{$bftoscan} == 0)
	    {
	    my $datapath = $self->datapath($bftoscan);
	    $self->scan($bftoscan,$datapath); # This updates the raw data
	    }     
	 }
      }

   # Also rebuild the project Makefile from scratch:
   $self->updatemkfrommeta();
   print "\n";
   }

sub update_newdirs()
   {
   my $self=shift;
   my ($newdirs) = @_;
   foreach my $path (@$newdirs)
      {
      print "Processing new directory \"",$path,"\"\n",if ($ENV{SCRAM_DEBUG});
      $self->updateadir($path);
      }
   }

sub update_existingdirs()
   {
   my $self=shift;
   my ($changeddirs) = @_;
   foreach my $path (@$changeddirs)
      {
      print "Processing modified directory \"",$path,"\"\n",if ($ENV{SCRAM_DEBUG});
      $self->updateadir($path);
      }
   }

sub updateadir()
   {
   my $self=shift;
   my ($path) = @_;
   my $datapath = $self->datapath($path);
   my $possiblebf = $path."/BuildFile";
   my $treeitem;
   
   if (! exists($self->{BUILDTREE}->{$datapath}))
      {
      use BuildSystem::TreeItem;
      $treeitem = BuildSystem::TreeItem->new();

      # Get the class info:
      my ($class, $classdir, $suffix) = @{$self->buildclass($path)};
      
      $treeitem->class($class);
      $treeitem->classdir($classdir);
      $treeitem->suffix($suffix);
      $treeitem->path($path);
      $treeitem->safepath($path);
      $treeitem->parent($datapath);
      $treeitem->children($filecache);
      $treeitem->name();
      # Store the TreeItem object:
      $self->{BUILDTREE}->{$datapath} = $treeitem;	   
      }

   # Update the status of the parent. Add the child and update
   # the safe subdirs:
   my $parent = $self->{BUILDTREE}->{$datapath}->parent();
   $self->{BUILDTREE}->{$parent}->updateparentstatus($datapath);
   
   # Now check to see if there is a BuildFile here. If there is, parse it:
   if ( -f $possiblebf)
      {
      # This level has a buildfile so store this path:
      $self->{BUILDTREE}->{$datapath}->metabf($possiblebf);
      # Scan to resolve groups. Store as RAWDATA:
      print "Scanning ",$possiblebf,"\n";
      $self->scan($possiblebf, $datapath);
      # Check to see if this BuildFile is known to have needed scanning. If so,
      # mark it as read:
      if (exists($buildfiles->{$possiblebf}))
	 {
	 $buildfiles->{$possiblebf} = 1;
	 }
      }
   
   # Recursively update the tree from this data path:
   $self->updatetree($datapath);   
   }

sub scan()
   {
   my $self=shift;
   my ($buildfile, $datapath) = @_;
   
   use BuildSystem::BuildFile;
   my $bfparse=BuildSystem::BuildFile->new();   
   $bfparse->parse($buildfile);

   # Store group data:
   $self->addgroup($bfparse->defined_group(), $datapath)
      if ($bfparse->defined_group());

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
   
   # Add the dependency list to our store:
   $self->{DEPENDENCIES}->{$datapath} = $bfparse->dependencies();   
   return $self;
   }

sub init_engine()
   {
   my $self=shift;
   
   # Create the interface to the template engine:
   use BuildSystem::TemplateInterface;
   # Pass in the config dir as the location where templates live:
   $self->{TEMPLATE_ENGINE} = BuildSystem::TemplateInterface->new();
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
   # Associate a path with ClassPath setting.
   # For now, just assumes global data has been scanned and class settings
   # are already known (in $self->{CONFIGDATA}->classpath()).   
   # Generate more optimal classpath data structure, only once.
   # Split every cache definition into an array of pairs, directory
   # name and class.  So ClassPath of type "+foo/+bar/src+library"
   # becomes [ [ "" "foo" ] [ "" "bar" ] [ "src" "library" ] ]
   my @CLASSPATHS=@{$self->{BUILDTREE}->{$ENV{SCRAM_SOURCEDIR}}->rawdata()->classpath()};
   
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

sub addgroup
   {
   my $self=shift;
   my ($grouparray,$datapath)=@_;
   
   foreach my $group (@{$grouparray})
      {
      # Only give a warning if the group is defined already in a
      # BuildFile other than the one at $path (avoids errors because KNOWNGROUPS
      # is not reset before re-parsing a BuildFile in which a group is defined):
      if (exists $self->{KNOWNGROUPS}->{$group}
	  && $self->{KNOWNGROUPS}->{$group} ne $datapath)
	 {
	 print "ERROR: Group \"",$group,"\", defined in ",$datapath,"/BuildFile, is already defined in ",
	 $self->{KNOWNGROUPS}->{$group}."/BuildFile.","\n";
	 exit(0); # For now, we exit.
	 }
      else
	 {
	 $self->{KNOWNGROUPS}->{$group} = $datapath;
	 }
      }
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

sub scramprojects()
   {
   my $self=shift;
   # Need this to be able to read our project cache:
   use Cache::CacheUtilities;

   $self->{SCRAM_PROJECTS} = $self->{TOOLMANAGER}->scram_projects();

   # Also store the BASE of each project:
   $self->{SCRAM_PROJECT_BASES}={};
   
   # Load the project cache for every scram-managed project in our toolbox:
   while (my ($project, $info) = each %{$self->{SCRAM_PROJECTS}})
      {
      if ( -f $info."/.SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db")
	 {
	 print "Reading cache for ",uc($project),"\n", if ($ENV{SCRAM_DEBUG});
	 $self->{SCRAM_PROJECTS}->{$project} =
	    &Cache::CacheUtilities::read($info."/.SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db");
	 $self->{SCRAM_PROJECT_BASES}->{uc($project)."_BASE"} = $info;
	 }
      else
	 {
	 print "WARNING: Unable to read project cache for ",uc($project)," tool.\n", if ($ENV{SCRAM_DEBUG});
	 print "         It could be that the project has not been built for your current architecture.","\n",
	 if ($ENV{SCRAM_DEBUG});
	 delete $self->{SCRAM_PROJECTS}->{$project};
	 }
      }
   
   # Also check to see if we're based on a release area. If so, store the cache as above. Don't store
   # the project name but instead just use 'RELEASE':
   if (my $releasearea=$::scram->releasearea() && exists $ENV{RELEASETOP})
      {
      if ( -f $ENV{RELEASETOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db")
	 {
	 # OK, so we found the cache. Now read it and store in the projects list:
	 $self->{SCRAM_PROJECTS}->{RELEASE} =
	    &Cache::CacheUtilities::read($ENV{RELEASETOP}."/.SCRAM/".$ENV{SCRAM_ARCH}."/ProjectCache.db");
	 print "OK found release cache ",$self->{SCRAM_PROJECTS}->{RELEASE},"\n", if ($ENV{SCRAM_DEBUG});
	 }
      else
	 {
	 print "WARNING: Current area is based on a release area but the project cache does not exist!","\n";
	 }
      }   
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
   delete $self->{TOOLMANAGER};
   delete $self->{TEMPLATE_ENGINE};
   delete $self->{SCRAM_PROJECTS};
   delete $self->{SCRAM_PROJECT_BASES};   
   return $self;
   }

1;
