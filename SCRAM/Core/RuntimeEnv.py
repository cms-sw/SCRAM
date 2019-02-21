from os import environ, stat
from os.path import exists, join
from sys import stdout
from re import compile, escape
from json import dump, load
import SCRAM
from SCRAM.BuildSystem.ToolManager import ToolManager


RUNTIME_SHELLS = {'-sh': 'BOURNE', '-csh': 'TCSH', '-win': 'CYGWIN'}


class RuntimeEnv(object):
    def __init__(self, area):
        self.recursive = 1 if 'SCRAM_RTBOURNE_SET' in environ else 0
        self.optional_paths = {}
        self.area = area
        self.OENV = environ.copy()
        self.env_backup_prefix = 'SRT_'
        self.skip_env = compile('^(_|PWD|PROMPT_COMMAND|SCRAM_.+|SCRAMV1_.+|SCRAM|LOCALTOP|RELEASETOP|BASE_PATH)$')
        self.shell = {}
        self.shell['BOURNE'] = {'EQUALS': '=', 'SEP': ':', 'EXPORT': 'export', 'UNEXPORT': 'unset'}
        self.shell['TCSH'] = {'EQUALS': ' ', 'SEP': ':', 'EXPORT': 'setenv', 'UNEXPORT': 'unsetenv'}
        self.shell['CYGWIN'] = {'EQUALS': '=', 'SEP': ';', 'EXPORT': 'unset', 'UNEXPORT': 'set'}
        self.shell['RTBOURNE'] = self.shell['BOURNE']
        self.env = {'variables': {}, 'paths': {}}
        self.force_tools_env = {}
        self.skip_runtime = {}
        self._unsetenv = False
        return

    def runtimebuildenv(self):
        save_env = {}
        for e in ['LD_PRELOAD']:
            if k in environ:
                save_env[k] = environ[k]
                del environ[k]
        self.save('RTBOURNE')
        if 'RTBOURNE' in self.env['rtstring']:
            for e in self.env['rtstring']['RTBOURNE']:
                environ[e] = self.env['rtstring']['RTBOURNE'][e]
        return True

    def _fixpathvar(self, var, sep):
        if (var in environ) and (environ[var] != ''):
            return '%s%s' % (sep, environ[var])
        return ''

    def _fixlibenv(self, var):
        if environ['SCRAM_ARCH'].startswith('osx') and var == 'LD_LIBRARY_PATH':
            var = DYLD_FALLBACK_LIBRARY_PATH
        return var

    def setenv(self, shell, where=stdout):
        if self.recursive:
            return
        ref = where
        shell_data = self.shell[shell]
        sep = shell_data['SEP']
        udata = {}
        data = []
        index = 0
        if not self._unsetenv:
            env_prefix = self.env_backup_prefix
            env = self._runtime()
            for d in env['variables']:
                for var, val in data.items():
                    udata[var] = 1
                    data.append({var: val[0]})
            for var in env['path']:
                if '_SRTOPT_' in var:
                    continue
                udata[var] = 1
                benv = '%s%s%s' % (env_prefix, var, self.backup_type[var])
                val = self._fixpathvar(var, sep)
                if benv in environ:
                    val = environ[benv] + val
                data.append({var: val})
            if shell == 'RTBOURNE':
                data.append({'SCRAM_RTBOURNE_SET': environ['SCRAMRT_SET']})
                for var, val in env['xenv'].items():
                    udata[var] = 1
                    data.append({var: val})
        for var, val in environ.items():
            if var not in udata:
                data.insert(0, {var: val})
                udata[var] = 1
        oenv = self.OENV
        unset = ""
        unset_vars = ""
        for v in oenv:
            if v in udata:
                continue
            if v in environ:
                del environ[v]
            if shell == 'RTBOURNE':
                continue
            unset += " %s" % v
            if not v.startswith('SCRAMRT_') and \
               not v.endswith('_SCRAMRT') and \
               not v.endswith('_SCRAMRTDEL'):
                unset_vars += "      %s\n" % v
        if unset:
            if unset_vars and not self._unsetenv:
                SCRAM.printerror("**** Following environment variables are going to be unset.\n%s" % unset_vars)
            print("%s %s;" % (shell_data['UNEXPORT'], unset), file=ref)
        for d in data:
            for var, val in d.items():
                if shell == 'RTBOURNE':
                    if var.startswith('SCRAMRT_') or \
                       var.endswith('_SCRAMRT') or \
                       var.endswith('_SCRAMRTDEL'):
                        if var != 'SCRAMRT_SET':
                            del environ[var]
                            continue
                    environ[var] = val
                    continue
                if var != 'PATH' and var in oenv:
                    if val == oenv[var]:
                        continue
                environ[var] = val
                print ('%s %s%s\"%s\";' % (shell_data['EXPORT'], var,
                       shell_data['EQUALS'], val), file=stdout)
        return True
        XX = """

sub save()
{
  my $self=shift;
  if ($self->{recursive}){return;}
  my $shell=shift;
  my $ref=shift || *STDOUT;
  if (exists($ENV{SCRAMRT_SET}))
  {
    $self->restore_environment_($shell);
    delete $ENV{SCRAMRT_SET};
    $self->save($shell,$ref);
  }
  else
  {
    my $env_prefix=$self->{env_backup_prefix};
    my $env = $self->runtime_();
    my @data=();my $index=0;
    my $sep=$self->{shell}{$shell}{SEP};
    my $skip=$self->{skipenv};
    foreach my $h (@{$env->{variables}})
    {
      while (my ($name, $value) = each %$h)
      {
	my $btype="_SCRAMRT";
	if (!exists $ENV{$name}){$btype="_SCRAMRTDEL";}
	$data[$index++]{"${env_prefix}${name}${btype}"}=$value->[0];
      }
    }
    $self->{backup_type}={};
    my %opt=();
    while (my ($name, $value) = each %{$env->{path}})
    {
      if ($name=~/^(.+?)_SRTOPT_(.+)$/)
      {
        if (exists $self->{optional_paths}{$1}){$opt{$2}{$1}=1;}
        next;
      }
      my $btype="_SCRAMRT";
      if (!exists $ENV{$name}){$btype="_SCRAMRTDEL";}
      $data[$index++]{"${env_prefix}${name}${btype}"}=&cleanpath_(join($sep,@$value),$sep);
      $self->{backup_type}{$name}=$btype;
    }
    foreach my $v (keys %opt)
    {
      my $btype="";
      my $nbtype="";
      if (exists $self->{backup_type}{$v})
      {
        $btype=$self->{backup_type}{$v};
	$nbtype=$btype;
      }
      else
      {
        $nbtype="_SCRAMRT";
	if (!exists $ENV{$v}){$nbtype="_SCRAMRTDEL";}
	$self->{backup_type}{$v}=$nbtype;
      }
      foreach my $t (keys %{$opt{$v}})
      {
	my $xindex=$index;
        my $pval="";
	if ($btype ne "")
	{
          for(my $i=0;$i<$index;$i++)
	  {
	    if (exists $data[$i]{"${env_prefix}${v}${btype}"})
	    {
	      $xindex=$i;
	      $pval=$data[$i]{"${env_prefix}${v}${btype}"};
	      last;
	    }
	  }
        }
	my $nval=join($sep,@{$env->{path}{$t."_SRTOPT_".$v}});
        if ($pval ne ""){$nval="${nval}${sep}${pval}";}
        $data[$xindex]{"${env_prefix}${v}${nbtype}"}=&cleanpath_($nval,$sep);
        if ($xindex == $index){$index++;}
      }
    }
    $data[$index++]{SCRAMRT_SET}="$ENV{SCRAM_PROJECTNAME}:$ENV{SCRAM_PROJECTVERSION}:$ENV{SCRAM_ARCH}:$ENV{SCRAM_VERSION}:${env_prefix}";
    foreach my $v (@data)
    {
      while(my ($name, $value) = each %$v)
      {
        $value =~ s/\"/\\\"/g; $value =~ s/\`/\\\`/g;
        $ENV{$name}=$value;
      }
    }
  }
}
"""

    def optional_env(self, tools=[]):
        self.optional_paths = {}
        for t in tools:
            self.optional_paths[t.upper()] = 1
        return

    def unsetenv(self, shell):
        if 'SCRAMRT_SET' not in environ:
            return
        self._unsetenv = True
        self._restore_environment(shell)
        self.setenv(shell)
        self._unsetenv = False
        return

    def _restore_environment(self, shell):
        global environ
        penv = environ['SCRAMRT_SET'].split(':')
        del environ['SCRAMRT_SET']
        sep = self.shell[shell]['SEP']
        backup_env = environ.copy()
        prefix = penv[4]
        bvar = 'SCRAMRT_BACKUP_ENV'
        bval = {} if bvar not in environ else \
                  dict([item.split('=', 1) for item in environ[bvar].split(';')])
        for name, value in environ.items():
            if name.startswith('SCRAMRT_'):
                del backup_env[name]
            elif self.skip_env.match(name):
                continue
            elif name.endswith('_SCRAMRT') or name.endswith('_SCRAMRTDEL'):
                del backup_env[name]
                type = ''
                var = name
                if name.endswith('_SCRAMRTDEL'):
                    var = name[:-11]
                    type = 'DEL'
                else:
                    var = name[:-8]
                if prefix:
                    var = var[len(prefix):]
                if var in backup_env:
                    if type == 'DEL':
                        del backup_env[var]
                        continue
                    val = backup_env[var]
                    if var in bval:
                        val = bval[var]
                    elif val == value:
                        val = ''
                    else:
                        regex = compile('^(.*?%s|)%s(%s.*|)$' % (sep, escape(value), sep))
                        m = regex.match(val)
                        if m:
                            val = '%s%s' % (m.group(1), m.group(2))
                        val = val.strip(sep)
                        val = val.replace('%s%s' % (sep, sep), sep)
                    if not val:
                        del backup_env[var]
                    else:
                        backup_env[var] = val
        environ = backup_env

    def _update_overrides(self):
        if 'PATH' in self.env['rtstring']['path']:
            override = join(SCRAM.BASEPATH, 'share', 'overrides', 'bin')
            if exists(override):
                self.env['rtstring']['path']['PATH'].insert(0, override)
        if 'SCRAM_IGNORE_RUNTIME_HOOK' not in self.OENV:
            self._runtime_hooks()
        return

    def _runtime_hooks(self):
        return True
        XXX = """
sub runtime_hooks_()
{
  my $self=shift;
  my $debug=0;
  if (exists $self->{OENV}{SCRAM_HOOKS_DEBUG}){$debug=1;}
  my $area = $self->{scram}->localarea();
  my $hook=$area->location()."/".$area->configurationdir()."/SCRAM/hooks/runtime-hook";
  if($debug){print STDERR "SCRAM_HOOK: $hook\n";}
  if (! -x $hook){return;}
  if ($debug){print STDERR "SCRAM_HOOK: Found\n";}
  my $out=`$hook 2>&1`;
  if ($debug){print STDERR "SCRAN_HOOK: $out";}
  foreach my $line (split("\n",$out))
  {
    if ($line!~/^runtime:((path:(append|prepend|remove):[a-zA-Z0-9-_]+)|(variable:[a-zA-Z0-9-_]+))=/io){print STDERR "$line\n"; next;}
    my @vals = split("=",$line,2);
    my @items = split(":",$vals[0]);
    my $vtype = lc($items[1]);
    if ($vtype eq "path")
    {
      if(! exists $self->{env}{rtstring}{path}){$self->{env}{rtstring}{path}={};}
      my $c = $self->{env}{rtstring}{path};
      $vtype=lc($items[2]);
      my $evar = $items[3];
      if (($vtype ne "remove") && (! exists $c->{$evar})){$c->{$evar}=[];}
      foreach my $d (split(":",$vals[1]))
      {
        $d=~s/\s//g;
        if($d eq ""){next;}
        if ($vtype eq "append"){push(@{$c->{$evar}},$d);}
        elsif ($vtype eq "prepend"){unshift @{$c->{$evar}}, $d;}
        elsif ($vtype eq "remove")
        {
          my $npath=[];
          foreach my $x (@{$c->{$evar}})
          {
            if ($x eq $d){next;}
            push(@$npath,$x);
          }
          $c->{$evar}=$npath;
        }
      }
    }
    elsif ($vtype eq "variable")
    {
      if (! exists $self->{env}{rtstring}{variables}){$self->{env}{rtstring}{variables}=[];}
      my $c = $self->{env}{rtstring}{variables};
      my $vindex = 0;
      my $evar = $items[2];
      if (exists $self->{env}{variables}{$evar}){$vindex = $self->{env}{variables}{$evar};}
      else{$vindex = scalar(@{$c});}
      $c->[$vindex]{$evar}=[$vals[1]];
    }
  }
}
"""

    def _runtime(self):
        if 'rtstring' in self.env:
            return self.env['rtstring']
        self.env['rtstring'] = {'variables': [], 'path': {}, 'RTBOURNE': {}, 'xenv': {}}
        cache = join(self.area.archdir(), 'RuntimeCache.json')
        if exists(cache):
            st = stat(cache)
            if (st.st_size > 0):
                toolcache = join(self.area.archdir(), 'Tools.db')
                if st.st_mtime > stat(toolcache).st_mtime:
                    with open(cache) as ref:
                        self.env['rtstring'] = load(ref)
                        self._update_overrides()
                    return self.env['rtstring']
        toolmanager = ToolManager(self.area)
        tools = toolmanager.loadtools()
        otools = toolmanager.toolsdata()
        self.force_tools_env = {'self': 1, environ['SCRAM_PROJECTNAME'].lower(): 1}
        self.skip_runtime = {}
        if 'self' in tools:
            stool = tools['self']
            otools.append(stool)
            if 'FLAGS' in stool:
                for f in ['NO_EXTERNAL_RUNTIME', 'SKIP_TOOLS_SYMLINK', 'DEFAULT_COMPILER']:
                    if f not in stool['FLAGS']:
                        continue
                    if f == 'NO_EXTERNAL_RUNTIME':
                        for x in stool['FLAGS'][f]:
                            x = self._fixlibenv(x)
                            self.skip_runtime[self._fixlibenv(x)] = 1
                    elif f == 'SKIP_TOOLS_SYMLINK':
                        for t in stool['FLAGS'][f]:
                            self.force_tools_env[t.lower()] = 1
                    elif f == 'DEFAULT_COMPILER':
                        self.env['rtstring']['RTBOURNE'][f] = stool['FLAGS'][f][0]
        compilertools = []
        for t in otools[::-1]:
            if 'SCRAM_COMPILER' in t:
                compilertools.append(t)
            else:
                self._toolenv(t)
        for t in compilertools:
            self._toolenv(t)
        vindex = len(self.env['rtstring']['variables'])
        for k in list(self.env):
            if k != 'rtstring':
                del self.env[k]
        with open(cache, 'w') as ref:
            dump(self.env['rtstring'], ref, sort_keys=True, indent=2)
        self._update_overrides()
        return self.env['rtstring']

    def _toolenv(self, tool):
        tname = tool['TOOLNAME']
        if (tname != 'self') and ('FLAGS' in tool) and ('SKIP_TOOL_SYMLINKS' in tool['FLAGS']):
            self.force_tools_env[tname] = 1
        if ('RUNTIME' not in tool) or \
           not tool['RUNTIME']:
            return
        projTool = True if tname == environ['SCRAM_PROJECTNAME'].lower() else False
        vindex = len(self.env['rtstring']['variables'])
        gmake = ""
        for trtvar, trtval in tool['RUNTIME'].items():
            if trtvar.startswith('PATH:'):
                var = trtvar[5:]
                if projTool and environ['SCRAM_ARCH'].startswith('osx') and \
                   var == 'DYLD_LIBRARY_PATH':
                    var = 'LD_LIBRARY_PATH'
                var = self._fixlibenv(var)
                if var not in self.env['rtstring']['path']:
                    self.env['rtstring']['path'][var] = []
                    self.env['paths'][var] = {}
                for val in trtval:
                    if tname == 'gmake' and var == 'PATH' and \
                       gmake == '' and exists(join(val, 'gmake')):
                        gmake = val + "/"
                        self.env['rtstring']['xenv']['SCRAM_GMAKE_PATH'] = gmake
                    if (var not in self.skip_runtime) or (tname in self.force_tools_env):
                        if val not in self.env['paths'][var]:
                            self.env['paths'][var][val] = 1
                            self.env['rtstring']['path'][var].append(val)
            elif trtvar not in self.env['variables']:
                self.env['variables'][trtvar] = vindex
                self.env['rtstring']['variables'].append({trtvar: trtval})
                vindex += 1

    def _cleanpath(self, path, sep):
        upath = {}
        opath = []
        for p in path.split(sep):
            if not p:
                continue
            while '/./' in p:
                p = p.replace('/./', '/')
            while '//' in p:
                p = p.replace('//', '/')
            while '/.' in p.endswith('/.'):
                p = p[:-2]
            if not p:
                p = '/'
            if p not in upath:
                upath[p] = 1
                opath.append(p)
        return sep.join(opath)
