# BuildFile
#
# Interface
# ---------
# new(toolbox)
# ParseBuildFile($base,$path,$file)
# ParseBuildFileExport(filename)
# BlockClassPath() : Return the class path
# ignore()	: return 1 if directory should be ignored 0 otherwise

package BuildSystem::BuildFile;
use Utilities::Verbose;
use ActiveDoc::SimpleDoc;
use BuildSystem::ToolBox;
require 5.004;
@ISA=qw(Utilities::Verbose);

BEGIN {
$buildfile="BuildFile";
}

sub new {
	my $class=shift;
	my $self={};
	bless $self, $class;
	$self->{toolbox}=shift;
	$self->{Arch}=1;
	push @{$self->{ARCHBLOCK}}, $self->{Arch};
	return $self;
}

sub ignore {
	my $self=shift;
	$self->verbose(">> ignore......<<");
	
	return (defined $self->{ignore})?$self->{ignore}:0;
}

sub _initswitcher {
	my $self=shift;
	my $switch=ActiveDoc::SimpleDoc->new();
	my $parse="makebuild";
	$self->verbose(">> _initswitcher: <<");
	$switch->newparse($parse);
	$switch->addignoretags($parse);
	$self->_commontags($switch,$parse);
	$switch->addtag($parse,"Build", \&Build_start, $self);
	$switch->addtag($parse,"none",
					\&OutToMakefile,$self,
				        \&OutToMakefile, $self,
					"", $self);
	$switch->addtag($parse,"Bin",
					\&Bin_start,$self,
				        \&OutToScreen, $self,
					"", $self);
	$switch->addtag($parse,"Module",
					\&Module_start,$self,
				        \&OutToScreen, $self,
					"", $self);

	$switch->addtag($parse,"ProductStore",
                                        \&Store_start,$self,
                                        "", $self,
                                        "", $self);
	$switch->addtag($parse,"LibType",
					\&LibType_Start,$self,
				        \&LibType_text, $self,
					\&LibType_end,$self);
	$switch->addtag($parse,"ConfigurationClass",
					\&Class_StartTag,$self,
				        \&OutToMakefile, $self,
					"", $self);
	$switch->addtag($parse,"ClassPath",
					\&setBlockClassPath,$self,
				        \&OutToMakefile, $self,
					"", $self);
	$switch->addtag($parse,"AssociateGroup",
					"",$self,
				        \&AssociateGroup,$self,
					"", $self);
	$switch->addtag($parse,"Environment",
					\&Environment_start,$self,
				        \&OutToMakefile, $self,
					\&Environment_end,$self);
	$switch->addtag($parse,"Export",
					\&export_start,$self,
				        \&OutToMakefile, $self,
					\&export_end,$self);
	return $switch;
}

sub _commontags
   {
   my $self=shift;
   my $switch=shift;
   my $parse=shift;
   
   $self->verbose(">> _commontags: SW ".$switch." PARSE ".$parse." <<");
   
   $switch->grouptag("Export",$parse);
   $switch->addtag($parse,"Use",
		   \&Use_start,$self,
		   \&OutToMakefile, $self,
		   "", $self);
   $switch->addtag($parse,"Group",
		   \&Group_start,$self,
		   \&OutToMakefile, $self,
		   "", $self);
   $switch->grouptag("Group",$parse);
   $switch->addtag($parse,"External",
		   \&External_StartTag,$self,
		   \&OutToMakefile, $self,
		   "", $self);
   $switch->addtag($parse,"lib",
		   \&lib_start,$self,
		   \&OutToMakefile, $self,"", $self);
   $switch->addtag($parse,"debuglib",
		   \&debuglib_start,$self,
		   \&OutToMakefile, $self,
		   "", $self);
   $switch->addtag($parse,"Architecture",
		   \&Arch_Start,$self,
		   \&OutToMakefile, $self,
		   \&Arch_End,$self);
   $switch->addtag($parse,"INCLUDE_PATH",
		   \&IncludePath_Start,$self,
		   \&OutToMakefile, $self,
		   "",$self);
   return $switch;
   }

sub ParseBuildFile {
	my $self=shift;
	my $base=shift;
	my $path=shift;
        my $filename=shift @_;
	my $fullfilename;
	if ( $filename!~/^\// ) {
	 $fullfilename="$base/$path/$filename";
	}
	else {
	 $fullfilename=$filename;
	}

	$self->verbose(">> ParseBuildFile: FN ".$fullfilename." <<");
	
	$self->{path}=$path;
	$numbins=0;
	$self->{envnum}=0;
	$self->{envlevel}=0;
	$self->{currentenv}="$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/".
								"BuildFile.mk";
	$self->{switch}=$self->_initswitcher();
	$self->{switch}->filetoparse($fullfilename);

	# open a temporary gnumakefile to store output.
	use Utilities::AddDir;
	AddDir::adddir("$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}");
	my $fh=FileHandle->new();
	open ( $fh, ">$ENV{LOCALTOP}/$ENV{INTwork}/".$self->{path}."/BuildFile.mk"
          ) or die "Unable to open /$ENV{INTwork}/".$self->{path}."/BuildFile.mk $!\n";
	@{$self->{filehandlestack}}=($fh);
	# make an alias
	*GNUmakefile=$fh;
	if ( -e $ENV{LatestBuildFile} ) {
	  print GNUmakefile "include $ENV{LatestBuildFile}\n";
	}

	$ENV{LatestBuildFile}="$ENV{LOCALTOP}/$ENV{INTwork}/".$self->{path}."/BuildFile.mk";
	$self->{switch}->parse("makebuild"); # sort out supported tags
	if ( $numbins > 0 ) {
	 print GNUmakefile <<ENDTEXT;
ifndef BINMODE
help::
\t\@echo Generic Binary targets
\t\@echo ----------------------
endif
ENDTEXT
	 foreach $target ( keys %$targettypes ) {
	 print GNUmakefile <<ENDTEXT;
ifndef BINMODE
help::
\t\@echo $target
endif
ENDTEXT
	 }
	}
	close GNUmakefile;
}

sub ParseBuildFile_Export {
	my $self=shift;
        my $filename=shift;

	$self->verbose(">> ParseBuildFile_Export: FN ".$filename." <<");
	
	my $bf=BuildSystem::BuildFile->new($self->{toolbox});
	if ( defined $self->{remoteproject} ) {
	   $bf->{remoteproject}=$self->{remoteproject};
	}
	$bf->_parseexport($filename);
	undef $bf;
}

sub _location {
	my $self=shift;
	use File::Basename;
	$self->verbose(">> _location: <<");
	return dirname($self->{switch}->filetoparse());
}

sub _parseexport {
	my $self=shift;
	my $filename=shift;
	$self->verbose(">> _parseexport: FN ".$filename." <<");
	
	my $switchex=ActiveDoc::SimpleDoc->new();
	$switchex->filetoparse($filename);
	$switchex->newparse("export");
	$switchex->addignoretags("export");
	$switchex->addtag("export","Export",
					\&export_start_export,$self,
				        \&OutToMakefile, $self,
					\&export_end_export,$self);
	$self->_commontags($switchex,"export");
	$switchex->allowgroup("__export","export");
	$self->{switch}=$switchex;
	$switchex->parse("export"); # sort out supported tags
}

sub _pushremoteproject {
	my $self=shift;
	my $path=shift;

	$self->verbose(">> _pushremoteproject: PATH ".$path." <<");
	
	if ( defined $self->{remoteproject} ) {
	  push @{$self->{rpstack}}, $self->{remoteproject};
	}
	$self->{remoteproject}=$path;
}

sub _popremoteproject {
	my $self=shift;
	$self->verbose(">> _popremoteproject:  <<");
	
	if ( $#{$self->{rpstack}} >=0 ) {
	  $self->{remoteproject}=pop @{$self->{rpstack}};
	}
	else {
	  undef $self->{remoteproject};
	}
}

sub _toolmapper {
	my $self=shift;

	if ( ! defined $self->{mapper} ) {
	   require BuildSystem::ToolMapper;
	   $self->{mapper}=BuildSystem::ToolMapper->new();
	}
	$self->verbose(">> _toolmapper: TM ".$self->{mapper}."<<");
	return $self->{mapper};
}


# ---- Tag routines 

#-- Override a class type with the <ConfigurationClass type=xxx> tag
#   the type tag will pick up a pre-defined class type from project space.

sub Class_StartTag {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->verbose(">> Classs_StartTag: NM ".$name." <<");
	
	if ( $self->{Arch} ) {
	 if ( defined $$hashref{'type'} ) {
		$ClassName=$$hashref{'type'};
	 }
	}
}
 
sub IncludePath_Start
   {
   my $self=shift;
   my $name=shift;
   my $hashref=shift;
   
   $self->verbose(">> IncludePath_Start: NM ".$name." <<");
   
   $self->{switch}->checktag( $name, $hashref, 'path');
   if ( $self->{Arch} )
      {
      print GNUmakefile "INCLUDE+=".$self->_location()."/".$$hashref{'path'}."\n";
      }
   }

#
# generic build tag
#
sub Build_start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->verbose(">> Build_start: NM ".$name." <<");
	
	$self->{switch}->checktag($name,$hashref,'class');
	if ( $self->{Arch} ) {

	  # -- determine the build products name
	  my $name;
	  if ( exists $$hashref{'name'} ) {
	    $name=$$hashref{'name'};
	  }
	  else { 
	    $self->{switch}->parseerror("No name specified for build product");
	  }

	  # -- check we have a lookup for the class type
	  my $mapper=$self->_toolmapper();
	  if ( ! $mapper->exists($$hashref{'class'}) ) {
	    $self->{switch}->parseerror("Unknown class : ".$$hashref{'class'});
	  }
	  else {
	   my @types=$self->_toolmapper()->types($$hashref{'class'});
	   my @deftypes=$self->_toolmapper()->defaulttypes($$hashref{'class'});

	   my $fh=$self->{filehandlestack}[0];
	   my @targets=();

	   # -- generate generic targets
	   print $fh "ifndef _BuildLink_\n";
	   print $fh "# -- Generic targets\n";
	   push @targets, $$hashref{'class'};
	   foreach $dtype ( @deftypes ) {
	    print $fh $$hashref{'class'}."::".$$hashref{'class'}."_".
								$dtype."\n";
	   }
	   print $fh "\n";

	   # -- generate targets for each type
	   foreach $type ( @types ) {

	    # -- generic name for each type
	    my $pattern=$$hashref{'class'}."_".$type;
	    my $dirname=$$hashref{'class'}."_".$type."_".$name;
	    print $fh "# ------ $pattern rules ---------------\n";
	    print $fh $$hashref{'class'}."_".$type."::".$$hashref{'class'}.
							"_".$type."_$name\n\n";

	    # -- create a new directory for each type
	    push @targets, $pattern;
	    my $dirname=$$hashref{'class'}."_".$type."_".$name;
	    my $here="$ENV{LOCALTOP}/$ENV{INTwork}/".$self->{path}."/".$dirname;
	    my $makefile=$here."/BuildFile.mk";

	    # -- create link targets to the directory
	    push @targets, $dirname;
	    print $fh "# -- Link Targets to $type directories\n";
	    print $fh "$dirname: make_$dirname\n";
	    print $fh "\t\@cd $here; \\\n";
	    print $fh "\t\$(MAKE) LatestBuildFile=$makefile _BuildLink_=1".
			" workdir=$here ".
		        " -f \$(TOOL_HOME)/basics.mk datestamp \$\@; \n\n";

	    # -- write target to make makefile for each directory
	    print $fh "# -- Build target directories\n";
	    print $fh "make_$dirname:\n";
	    print $fh "\tif [ ! -e \"$makefile\" ]; then \\\n";
	    print $fh "\t if [ ! -d \"$here\" ]; then \\\n";
	    print $fh "\t  mkdir $here; \\\n";
	    print $fh "\t fi;\\\n";
	    print $fh "\t cd $dirname; \\\n";
	    print $fh "\t echo include ".$self->{currentenv}." > ".
							"$makefile; \\\n";
	    print $fh "\t echo VPATH+=$ENV{LOCALTOP}/".$self->{path}.
					" >> $makefile; \\\n";
	    print $fh "\t echo buildname=$name >> $makefile;\\\n";
	    print $fh "\t echo ".$dirname.":".$pattern." >> $makefile;\\\n";
	    if ( defined (my @file=$mapper->rulesfile($$hashref{'class'})) ) {
	     foreach $f ( @file ) {
	      print $fh "\t echo -include $f >> $makefile; \\\n";
	     }
	    }
	    print $fh "\tfi\n";
	    print $fh "\n";

	    # -- cleaning targets
	    push @targets, "clean_$dirname";
	    print $fh "# -- cleaning targets\n";
	    print $fh "clean::clean_$dirname\n";
	    print $fh "clean_".$dirname."::\n";
	    print $fh "\t\@echo cleaning $dirname\n";
	    print $fh "\t\@if [ -d $here ]; then \\\n";
	    print $fh "\tcd $here; \\\n";
	    print $fh "\t\$(MAKE) LatestBuildFile=$makefile workdir=".
			$here." _BuildLink_=1 -f ".
			"\$(TOOL_HOME)/basics.mk clean; \\\n";
	    print $fh "\tfi\n\n";


	  }
	  # -- help targets
	  print $fh "helpheader::\n";
	  print $fh "\t\@echo Targets available:\n";
	  print $fh "\t\@echo ------------------\n\n";
	  print $fh "help::helpheader\n";
	  foreach $target ( @targets ) {
	    print $fh "help::\n";
	    print $fh "\t\@echo $target\n"
	  }
	  print $fh "endif\n";
	 } # end else
	}
}

sub Bin_start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	my $fileclass;
	my @tools;
	my $tool;
	my $filename;
	my $objectname;

	$self->verbose(">>          <<");
	
	$self->{switch}->checktag($name,$hashref,'file');
	if ( $self->{Arch} ) {
	if ( ! defined $$hashref{name} ) {
		($$hashref{name}=$$hashref{file})=~s/\..*//;
	}
	($filename=$$hashref{file})=~s/\..*//;

	# Create a new directory for each binary target
	my $dirname="bin_".$$hashref{name};
	AddDir::adddir("$ENV{LOCALTOP}/$ENV{INTwork}/".$self->{path}."/$dirname");
	open (binGNUmakefile, 
	   ">$ENV{LOCALTOP}/$ENV{INTwork}/".$self->{path}."/$dirname/BuildFile.mk") or die           "Unable to make $ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname/".
	   "BuildFile.mk $!\n";

	# Create the link targets
	$numbins++;
	my $fh=$self->{filehandlestack}[0];
	print $fh <<ENDTEXT;

# Link Targets to binary directories
ifdef BINMODE
# We dont want to build a library here
override files:=
endif
ifndef BINMODE

define stepdown_$$hashref{'name'}
if [ -d "$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname" ]; then \\
cd $ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname; \\
\$(MAKE) BINMODE=true LatestBuildFile=$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname/BuildFile.mk workdir=\$(workdir)/$dirname -f \$(TOOL_HOME)/basics.mk datestamp \$\@; \\
fi
endef

define stepdown2_$$hashref{'name'}
if [ -d "$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname" ]; then \\
cd $ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname; \\
\$(MAKE) BINMODE=true LatestBuildFile=$ENV{LOCALTOP}/$ENV{INTwork}/$self{path}/$dirname/BuildFile.mk workdir=\$(workdir)/$dirname -f \$(TOOL_HOME)/basics.mk datestamp \$\*; \\
fi

endef

bin_$$hashref{'name'}_%:: dummy
	\@\$(stepdown2_$$hashref{'name'})

$$hashref{'name'}_%:: dummy
	\@\$(stepdown_$$hashref{'name'})

help bin bin_debug bin_debug_local bin_insure bin_Insure clean $$hashref{'name'}:: dummy
	\@\$(stepdown_$$hashref{'name'})

binfiles+=$$hashref{'file'}
locbinfiles+=$dirname/$$hashref{'file'}
endif


ENDTEXT


# the binary specifics makefile
	print binGNUmakefile "include ".$self->{currentenv}."\n";
	print binGNUmakefile "VPATH+=$ENV{LOCALTOP}/$self{path}\n";

# alias for bin_Insure
	print binGNUmakefile <<ENDTEXT;

bin_insure:bin_Insure
ifdef MAKETARGET_bin_insure
MAKETARGET_$$hashref{name}_Insure=1
endif

# debuggging target
$$hashref{'name'}_echo_% :: echo_%

# help targets
help::
\t\@echo Targets For $$hashref{'name'}
\t\@echo -------------------------------------
\t\@echo $$hashref{'name'}  - default build
\t\@echo bin_$$hashref{'name'}_clean - executable specific cleaning
ENDTEXT

# Make generic rules for each type
	$targettypes={
		"bin" => 'o',
		"bin_debug" => 'd',
		"bin_debug_local" => 'l_d',
		"bin_Insure" => 'Insure'
	};
	#
	foreach $target ( keys %$targettypes ) {
	  print binGNUmakefile <<ENDTEXT;

# Type $target specifics 
ifdef MAKETARGET_$target
MAKETARGET_$$hashref{name}_$$targettypes{$target}=1
endif
$target ::$$hashref{name}_$$targettypes{$target}

bintargets+=$$hashref{name}_$$targettypes{$target}
help::
\t\@echo $$hashref{name}_$$targettypes{$target}
clean::
\t\@if [ -f \$(binarystore)/$$hashref{name}_$$targettypes{$target} ]; then \\
\techo Removing \$(binarystore)/$$hashref{name}; \\
\trm \$(binarystore)/$$hashref{name}_$$targettypes{$target}; \\
\tfi

ENDTEXT
	  ($objectname=$$hashref{file})=~s/\..*/_$$targettypes{$target}\.o/;
	  ${"objectname_$$targettypes{$target}"}=$objectname;
	  print binGNUmakefile "$objectname:$$hashref{name}.dep\n";
	} # end loop

	print binGNUmakefile "$$hashref{name}_Insure.exe:.psrc\n";
 	print binGNUmakefile "$$hashref{name}_d.exe:$objectname_d\n";
	print binGNUmakefile "\t\$(CClinkCmdDebug)\n";
	print binGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
 	print binGNUmakefile "$$hashref{name}_l_d.exe:$objectname_d\n";
	print binGNUmakefile "\t\$(CClinkCmdDebugLocal)\n";
	print binGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
 	print binGNUmakefile "$$hashref{name}_Insure.exe:$objectname_Insure\n";
	print binGNUmakefile "\t\$(CClinkCmdInsure)\n";
	print binGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
 	print binGNUmakefile "$$hashref{name}_o.exe:$objectname_o\n";
	print binGNUmakefile "\t\$(CClinkCmd)\n";
	print binGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
	print binGNUmakefile "$$hashref{name}.dep:$$hashref{file}\n";
	print binGNUmakefile "-include $$hashref{name}.dep\n";
print binGNUmakefile <<ENDTEXT;
clean::
\t\@if [ -f \$(binarystore)/$$hashref{name} ]; then \\
\techo Removing \$(binarystore)/$$hashref{name}; \\
\trm \$(binarystore)/$$hashref{name}; \\
\tfi

$$hashref{name}_d.exe:\$(libslocal_d)
$$hashref{name}_o.exe:\$(libslocal)
ifdef MCCABE_DATA_DIR
$$hashref{name}_mccabe.exe: \$(libslocal_d) \$(MCCABE_DATA_DIR)/mccabeinstr/instplus.cpp
endif
$$hashref{name}_Insure.exe:\$(libslocal_I)
$$hashref{name}_d:$$hashref{name}_d.exe
	\@cp $$hashref{name}_d.exe \$(binarystore)/$$hashref{name}
$$hashref{name}_l_d:$$hashref{name}_l_d.exe
	\@cp $$hashref{name}_l_d.exe \$(binarystore)/$$hashref{name}
$$hashref{name}_Insure:$$hashref{name}_Insure.exe
	\@cp $$hashref{name}_Insure.exe \$(binarystore)/$$hashref{name}_Insure
$$hashref{name}:$$hashref{name}_d.exe
	\@mv $$hashref{name}_d.exe \$(binarystore)/$$hashref{name}
$$hashref{name}_o:$$hashref{name}_o.exe
	\@mv $$hashref{name}_o.exe \$(binarystore)/$$hashref{name}
binfiles+=$$hashref{file}
ENDTEXT
	}
	close binGNUmakefile;
}

sub Module_start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	my $fileclass;
	my @tools;
	my $tool;
	my $filename;
	my $objectname;

	$self->verbose(">> In module_start: ".$name." <<");
	
	$self->{switch}->checktag($name,$hashref,'file');
	if ( $self->{Arch} ) {
	if ( ! defined $$hashref{name} ) {
		($$hashref{name}=$$hashref{file})=~s/\..*//;
	}
	($filename=$$hashref{file})=~s/\..*//;

	# Create a new directory for each module target
	my $dirname="module_".$$hashref{name};
	AddDir::adddir("$ENV{LOCALTOP}/$ENV{INTwork}/".$self->{path}."/$dirname");
	open (moduleGNUmakefile, 
	   ">$ENV{LOCALTOP}/$ENV{INTwork}/".$self->{path}."/$dirname/BuildFile.mk") or die           "Unable to make $ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname/".
	   "BuildFile.mk $!\n";

	# Create the link targets
	$numbins++;
	my $fh=$self->{filehandlestack}[0];
	print $fh <<ENDTEXT;

# Link Targets to module directories
ifdef MODULEMODE
# We dont want to build a library here
override files:=
endif
ifndef MODULEMODE

BINMODE=true
   
define stepdown_$$hashref{'name'}
if [ -d "$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname" ]; then \\
cd $ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname; \\
\$(MAKE) MODULEMODE=true LatestBuildFile=$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname/BuildFile.mk workdir=\$(workdir)/$dirname -f \$(TOOL_HOME)/basics.mk datestamp \$\@; \\
fi
endef

define stepdown2_$$hashref{'name'}
if [ -d "$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname" ]; then \\
cd $ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/$dirname; \\
\$(MAKE) MODULEMODE=true LatestBuildFile=$ENV{LOCALTOP}/$ENV{INTwork}/$self{path}/$dirname/BuildFile.mk workdir=\$(workdir)/$dirname -f \$(TOOL_HOME)/basics.mk datestamp \$\*; \\
fi

endef

module_$$hashref{'name'}_%:: dummy
	\@\$(stepdown2_$$hashref{'name'})

$$hashref{'name'}_%:: dummy
	\@\$(stepdown_$$hashref{'name'})

help module module_debug module_debug_local module_insure module_Insure clean $$hashref{'name'}:: dummy
	\@\$(stepdown_$$hashref{'name'})

modulefiles+=$$hashref{'file'}
locmodulefiles+=$dirname/$$hashref{'file'}
endif


ENDTEXT


# the module specifics makefile
	print moduleGNUmakefile "include ".$self->{currentenv}."\n";
	print moduleGNUmakefile "VPATH+=$ENV{LOCALTOP}/$self{path}\n";

# alias for bin_Insure
	print moduleGNUmakefile <<ENDTEXT;

module_insure:module_Insure
ifdef MAKETARGET_module_insure
MAKETARGET_$$hashref{name}_Insure=1
endif

# debuggging target
$$hashref{'name'}_echo_% :: echo_%

# help targets
help::
\t\@echo   
\t\@echo Targets For $$hashref{'name'}
\t\@echo -------------------------------------
\t\@echo $$hashref{'name'}  - default build
\t\@echo module_$$hashref{'name'}_clean - executable specific cleaning
ENDTEXT

# Make generic rules for each type
	$targettypes={
		"module" => 'o',
		"module_debug" => 'd',
		"module_debug_local" => 'l_d',
		"module_Insure" => 'Insure'
	};
	#
	foreach $target ( keys %$targettypes ) {
	  print moduleGNUmakefile <<ENDTEXT;

# Type $target specifics 
ifdef MAKETARGET_$target
MAKETARGET_$$hashref{name}_$$targettypes{$target}=1
endif
$target ::$$hashref{name}_$$targettypes{$target}

moduletargets+=$$hashref{name}_$$targettypes{$target}
help::
\t\@echo $$hashref{name}_$$targettypes{$target}
clean::
\t\@if [ -f \$(modulestore)/$$hashref{name}_$$targettypes{$target} ]; then \\
\techo Removing \$(modulestore)/$$hashref{name}; \\
\trm \$(modulestore)/$$hashref{name}_$$targettypes{$target}; \\
\tfi

ENDTEXT
	  ($objectname=$$hashref{file})=~s/\..*/_$$targettypes{$target}\.o/;
	  ${"objectname_$$targettypes{$target}"}=$objectname;
	  print moduleGNUmakefile "$objectname:$$hashref{name}.dep\n";
	} # end loop
	print moduleGNUmakefile "MDFLAGS= -shared -Wl,-soname,\$\@","\n";
	print moduleGNUmakefile "$$hashref{name}_Insure.so:.psrc\n";
 	print moduleGNUmakefile "$$hashref{name}_d.so:$objectname_d\n";
	print moduleGNUmakefile "\t\$(CClinkCmdDebug) \$(MDFLAGS)\n";
	print moduleGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
 	print moduleGNUmakefile "$$hashref{name}_l_d.so:$objectname_d\n";
	print moduleGNUmakefile "\t\$(CClinkCmdDebugLocal) \$(MDFLAGS)\n";
	print moduleGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
 	print moduleGNUmakefile "$$hashref{name}_Insure.so:$objectname_Insure\n";
	print moduleGNUmakefile "\t\$(CClinkCmdInsure) \$(MDFLAGS)\n";
	print moduleGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
 	print moduleGNUmakefile "$$hashref{name}_o.so:$objectname_o\n";
	print moduleGNUmakefile "\t\$(CClinkCmd) \$(MDFLAGS)\n";
	print moduleGNUmakefile "\t\@\$(SCRAMPERL) \$(SCRAM_HOME)/src/scramdatestamp \$\@\.ds \$\@ \$\^\n";
	print moduleGNUmakefile "$$hashref{name}.dep:$$hashref{file}\n";
	print moduleGNUmakefile "-include $$hashref{name}.dep\n";
print moduleGNUmakefile <<ENDTEXT;
clean::
\t\@if [ -f \$(modulestore)/lib$$hashref{name} ]; then \\
\techo Removing \$(modulestore)/lib$$hashref{name}; \\
\trm \$(modulestore)/lib$$hashref{name}; \\
\tfi

   
$$hashref{name}_d.so:\$(libslocal_d)
$$hashref{name}_o.so:\$(libslocal)
ifdef MCCABE_DATA_DIR
$$hashref{name}_mccabe.so: \$(libslocal_d) \$(MCCABE_DATA_DIR)/mccabeinstr/instplus.cpp
endif
$$hashref{name}_Insure.so:\$(libslocal_I)
$$hashref{name}_d:$$hashref{name}_d.so
	\@cp $$hashref{name}_d.so \$(modulestore)/lib$$hashref{name}
$$hashref{name}_l_d:$$hashref{name}_l_d.so
	\@cp $$hashref{name}_l_d.so \$(modulestore)/lib$$hashref{name}
$$hashref{name}_Insure:$$hashref{name}_Insure.so
	\@cp $$hashref{name}_Insure.so \$(modulestore)/lib$$hashref{name}_Insure
$$hashref{name}:$$hashref{name}_d.so
	\@mv $$hashref{name}_d.so \$(modulestore)/lib$$hashref{name}
$$hashref{name}_o:$$hashref{name}_o.so
	\@mv $$hashref{name}_o.so \$(modulestore)/lib$$hashref{name}.so
modulefiles+=$$hashref{file}
ENDTEXT
	}
	close moduleGNUmakefile;
}


sub External_StartTag {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->verbose(">> External_StartTag: NM ".$name." <<");
	
	my $tool;
	if ( $self->{Arch} ) {
	$self->{switch}->checktag($name,$hashref,'ref');

	# -- oo toolbox stuff
	# - get the appropriate tool object
	$$hashref{'ref'}=~tr[A-Z][a-z];
	if ( ! exists $$hashref{'version'} ) {
	 $tool=$self->{toolbox}->gettool($$hashref{'ref'});
	}
	else {
	 $tool=$self->{toolbox}->gettool($$hashref{'ref'},$$hashref{'version'});
	}
	if ( ! defined $tool ) {
	  $self->{switch}->parseerror("Unknown Tool Specified ("
							.$$hashref{'ref'}.")");
	}

	# -- old fashioned GNUmakefile stuff
	print GNUmakefile $$hashref{'ref'};
	if ( defined $$hashref{'version'} ) {
		print GNUmakefile "_V_".$$hashref{'version'};
	}
	print GNUmakefile "=true\n";
	
	# -- Sub system also specified?
	if ( exists $$hashref{'use'} ) {
	   # -- look for a buildfile
	   my @paths=$tool->getfeature("INCLUDE");
	   my $file="";
	   my ($path,$testfile);
	   foreach $path ( @paths ) {
	     $testfile=$path."/".$$hashref{'use'}."/BuildFile" ;
	     if ( -f $testfile ) { 
		$file=$testfile; 
		$self->_pushremoteproject($path);
	     }
	   }
	   if ( $file eq "" ) {
	     $self->{switch}->parseerror("Unable to find SubSystem $testfile");
	   }
	   $self->ParseBuildFile_Export($file);
	   $self->_popremoteproject();
	 }
	}
}	

sub Group_start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;
	
	$self->verbose(">> Group_start: NM ".$name." <<");
	
	$self->{switch}->checktag($name, $hashref, 'name');
	if ( $self->{Arch} ) {
	print GNUmakefile "GROUP_".$$hashref{'name'};
	if ( defined $$hashref{'version'} ) {
		print GNUmakefile "_V_".$$hashref{'version'};
	}
	print GNUmakefile "=true\n";
	}
}	

sub Use_start
   {
   my $self=shift;
   my $name=shift;
   my $hashref=shift;
   my $filename;
   use Utilities::SCRAMUtils;

   $self->verbose(">> Use_start: NM ".$name." <<");
   
   $self->{switch}->checktag($name, $hashref, "name");
   if ( $self->{Arch} )
      {
      if ( exists $$hashref{'group'} )
	 {
	 print GNUmakefile "GROUP_".$$hashref{'group'}."=true\n";
	 }
      if ( ! defined $self->{remoteproject} )
	 {
	 $filename=SCRAMUtils::checkfile("/$ENV{INTsrc}/$$hashref{name}/BuildFile");
	 }
      else
	 {
	 $filename=$self->{remoteproject}."/$$hashref{name}/BuildFile";
	 print "Trying $filename\n";
	 if ( ! -f $filename ) { $filename=""; };
	 }
      if ( $filename ne "" )
	 {
	 $self->ParseBuildFile_Export( $filename );
	 }
      else
	 {
	 $self->{switch}->parseerror("Unable to detect Appropriate ".
				     "decription file for <$name name=".$$hashref{name}.">");
	 }
      }
   }

sub CheckBuildFile {
	 my $self=shift;
         my $classdir=shift;
	 my $ClassName="";
         my $thisfile="$classdir/$buildfile";
	 
         if ( -e $ENV{LOCALTOP}."/".$thisfile ) {
            $DefaultBuildfile="$ENV{LOCALTOP}/$thisfile";
            $self->ParseBuildFile($ENV{LOCALTOP}, $classdir, $buildfile);
         }
         elsif ( -e $ENV{RELEASETOP}."/".$thisfile ) {
            $DefaultBuildfile="$ENV{RELEASETOP}/$thisfile";
            $self->ParseBuildFile($ENV{RELEASETOP}, $classdir, $buildfile);
         }
	 $self->verbose(">> CheckBuildFile: FN ".$thisfile." CN ".$ClassName." <<");
	 return $ClassName;
}

# List association groups between <AssociateGroup> tags
# seperated by newlines or spaces
sub AssociateGroup {
	my $self=shift;
	my $name=shift;
        my $string=shift;
	my $word;

	$self->verbose(">> AssociateGroup: NM ".$name." ST ".$string." <<");
	
	if ( $self->{Arch} ) {
	foreach $word ( (split /\s/, $string) ){
		chomp $word;
		next if /^#/;
		if ( $word=~/none/ ) { 
			$self->{ignore}=1;
		}
	}
	}
}

sub Arch_Start {
	my $self=shift;
        my $name=shift;
        my $hashref=shift;

	$self->verbose(">> Arch_Start: NM ".$name." <<");
	
        $self->{switch}->checktag($name, $hashref,'name');
	( ($ENV{SCRAM_ARCH}=~/$$hashref{name}.*/) )? ($self->{Arch}=1) 
                                                : ($self->{Arch}=0);
        push @{$self->{ARCHBLOCK}}, $self->{Arch};
}

sub Arch_End {
	my $self=shift;
        my $name=shift;
	
	$self->verbose(">> Arch_End: NM ".$name." <<");

	pop @{$self->{ARCHBLOCK}};
        $self->{Arch}=$self->{ARCHBLOCK}[$#{$self->{ARCHBLOCK}}];
}

# Split up the Class Block String into a useable array
sub _CutBlock {
    my $self=shift;
    my $string= shift @_;

    $self->verbose(">> _CutBlock: ST ".$string." <<");
    
    @BlockClassA = split /\//, $string;
}

sub OutToMakefile {
        my $self=shift;
	my $name=shift;
        my @vars=@_;
	
	$self->verbose(">> OutToMakefile: <<");

	if ( $self->{Arch} ) {
	  $self->verbose(">> CONT: ".$#vars." lines <<");
	  print GNUmakefile @vars;
	}
}

sub OutToScreen {
	my $name=shift;
        my @vars=@_;
	
	if ( $self->{Arch} ) {
	  print @vars;
	}
}
sub setBlockClassPath {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->verbose(">> setBlockClassPath: NM ".$name." <<");
	
	$self->{switch}->checktag($name, $hashref, 'path');
	$self->{BlockClassPath}=$self->{BlockClassPath}.":".$$hashref{path};
	$self->_CutBlock($$hashref{path});
}

sub BlockClassPath {
	my $self=shift;

	$self->verbose(">> BlockClassPath: <<");

	return $self->{BlockClassPath};
}

sub export_start_export {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->verbose(">> export_start_export: NM ".$name." <<");
	
	$self->{switch}->opengroup("__export");
}

sub export_start {
	my $self=shift;
	my $name=shift;
	my $hashref=shift;

	$self->verbose(">> export_start: NM ".$name." <<");
	
	$self->{switch}->opengroup("__export");
	if ( exists $$hashref{autoexport} ) {
	  print GNUmakefile "scram_autoexport=".$$hashref{autoexport}."\n";
	  if ( $$hashref{autoexport}=~/true/ ) {
	   $self->{switch}->allowgroup("__export","makebuild");
	  }
	  else {
	   $self->{switch}->disallowgroup("__export","makebuild");
	  }
	}
	# -- allow default setting from other makefiles
	print GNUmakefile "ifeq (\$(scram_autoexport),true)\n";
}

sub export_end_export {
	my $self=shift;
	$self->verbose(">> export_end_export: <<");
	$self->{switch}->closegroup("__export");
}

sub export_end {
	my $self=shift;
	$self->verbose(">> export_end: <<");
	$self->{switch}->closegroup("__export");
	print GNUmakefile "endif\n";
}

#
# Standard lib tag 
#
sub lib_start
   {
   my $self=shift;
   my $name=shift;
   my $hashref=shift;
   
   $self->verbose(">> lib_start: NM ".$name." <<");
   
   $self->{switch}->checktag($name, $hashref, 'name');

   if ( $self->{Arch} )
      {
      print GNUmakefile "lib+=$$hashref{name}\n";
      }
   }

# Standard debug lib tag 
#
sub debuglib_start
   {
   my $self=shift;
   my $name=shift;
   my $hashref=shift;
   
   $self->verbose(">> debuglib_start: NM ".$name." <<");
   $self->{switch}->checktag($name, $hashref, 'name');

   if ( $self->{Arch} )
      {
      print GNUmakefile "debuglib+=$$hashref{name}\n";
      }
   }

#
# libtype specification
#
sub LibType_Start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;
	
	$self->verbose(">> LibType_Start: NM ".$name." <<");
	
	if ( $self->{Arch} ) {
	if ( defined $self->{libtype_conext} ) {
	  $self->{switch}->parseerror("<$name> tag cannot be specified".
		" without a </$name> tag to close previous context");
	}
	else {
	$self->{libtype_conext}=1;
        $self->{switch}->checktag($name, $hashref, 'type');
	
	print GNUmakefile "# Specify Library Type\n";
	print GNUmakefile "DefaultLibsOff=yes\n";
	if ( $$hashref{'type'}=~/^archive/i ) {
	  print GNUmakefile "LibArchive=true\n";
	}
	elsif ($$hashref{'type'}=~/debug_archive/i ) {
	  print GNUmakefile "LibDebugArchive=true\n";
	}
	elsif ($$hashref{'type'}=~/debug_shared/i ) {
	  print GNUmakefile "LibDebugShared=true\n";
	}
	elsif ($$hashref{'type'}=~/shared/i ) {
	  print GNUmakefile 'LibShared=true'."\n";
	}
	print GNUmakefile "\n";
	}
	}
}

sub LibType_text {
	my $self=shift;
        my $name=shift;
        my $string=shift;
	$self->verbose(">> LibType_text: NM ".$name." <<");

	if ( $self->{Arch} ) {
	  $string=~s/\n/ /g;
          print GNUmakefile "libmsg::\n\t\@echo Library info: ";
	  print GNUmakefile $string;
	  print GNUmakefile "\n";
        }
}

sub LibType_end {
	my $self=shift;
        my $name=shift;

	$self->verbose(">> LibType_end: NM ".$name." <<");

	undef $self->{libtype_conext};
}

sub Environment_start {
	my $self=shift;
	my $name=shift;
        my $hashref=shift;

	$self->verbose(">> Environment_start: NM ".$name." <<");
	
        if ( $self->{Arch} ) {
	  $self->{envnum}++;

	  # open a new Environment File
	  my $envfile="$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/Env_".
		$self->{envnum}.".mk";
	  use FileHandle;
	  my $fh=FileHandle->new();
	  open ($fh,">$envfile") or die "Unable to open file $envfile \n$!\n";
	  push @{$self->{filehandlestack}}, $fh;
	  *GNUmakefile=$fh;

	  # include the approprate environment file
	  if ( $self->{envlevel} == 0 ) {
	     print GNUmakefile "include $ENV{LOCALTOP}/$ENV{INTwork}/".
		$self->{path}."/BuildFile.mk\n";
	  }
	  else {
	     print GNUmakefile "include $ENV{LOCALTOP}/$ENV{INTwork}/".
		$self->{path}."/Env_".$self->{Envlevels}[$self->{envlevel}].".mk\n";
	  }
	  $self->{envlevel}++;
	  $self->{Envlevels}[$self->{envlevel}]=$self->{envnum};
	  $self->{currentenv}="$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/Env_$self->{envnum}.mk";
	}
}

sub Environment_end {
	my $self=shift;
	my $fd;

	$self->verbose(">> Environment_end: NM ".$name." <<");

	if ( $self->{Arch} ) {
	  $self->{envlevel}--;
	  if ( $self->{envlevel} < 0 ) {
	    print "Too many </Environent> Tags on $self->{switch}->line()\n";
	    exit 1;
	  }
	  close GNUmakefile;
	  # restore the last filehandle
	  $fd=pop @{$self->{filehandlestack}};
	  close $fd;
	  *GNUmakefile=$self->{filehandlestack}[$#{$self->{filehandlestack}}];
	  if ( $self->{envlevel} < 1 ) {
	    $self->{currentenv}="$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/".
			"BuildFile.mk";
	  }
	  else {
	    $self->{currentenv}=
	     "$ENV{LOCALTOP}/$ENV{INTwork}/$self->{path}/Env_".
		$self->{Envlevels}[$self->{envlevel}];
	  }
	}
}

sub Store_start {
        my $self=shift;
        my $name=shift;
        my $hashref=shift;

	$self->verbose(">> Store_start: NM ".$name." <<");

        if ( $self->{Arch} ) {
          $self->{switch}->checktag( $name, $hashref, 'name' );

          # -- store creation
          my $dir=$$hashref{'name'};
          AddDir::adddir($ENV{LOCALTOP}."/".$dir);
          if ( exists $$hashref{'type'} ) {
            # -- architecture specific store
            if ( $$hashref{'type'}=~/^arch/i ) {
                $dir=$dir."/".$ENV{SCRAM_ARCH};
                AddDir::adddir($ENV{LOCALTOP}."/".$dir);
            }
            else {
                $self->parseerror("Unknown type in <$name> tag");
            }
          }

          # -- set make variables for the store
          print GNUmakefile "SCRAMSTORENAME_".$$hashref{'name'}.":=".$dir."\n";
          print GNUmakefile "SCRAMSTORE_".$$hashref{'name'}.":=".
                                        $ENV{LOCALTOP}."/".$dir."\n";
          print GNUmakefile "VPATH+=".$ENV{LOCALTOP}
                        ."/".$dir.":".$ENV{RELEASETOP}."/".$dir."\n";
        }
}
