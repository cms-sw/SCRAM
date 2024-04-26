from os import environ, stat
from os.path import exists, join, abspath
from sys import stdout
import re
from base64 import b64decode, b64encode
from json import dump, load
import SCRAM
from SCRAM.BuildSystem.ToolManager import ToolManager


RUNTIME_SHELLS = {'-sh': 'BOURNE', '-csh': 'TCSH', '-win': 'CYGWIN'}
ORIG_SCRAM_ARCH = ''
try:
    ORIG_SCRAM_ARCH = environ['SCRAM_ARCH']
except:
    pass

class RuntimeEnv(object):
    def __init__(self, area):
        self.recursive = True if 'SCRAM_RTBOURNE_SET' in environ else False
        self.optional_paths = {}
        self.area = area
        for e in [i for i in environ.keys() if i.startswith('SCRAMV3_BACKUP_')] :
            environ[e[15:]] = environ[e]
            del environ[e]
        self.OENV = environ.copy()
        self.OENV['SCRAM_ARCH'] = ORIG_SCRAM_ARCH
        self.env_backup_prefix = 'SRT_'
        self.skip_env = re.compile('^(_|PWD|PROMPT_COMMAND|SCRAM_.+|SCRAMV1_.+|SCRAM|LOCALTOP|RELEASETOP|BASE_PATH)$')
        self.shell = {}
        self.shell['BOURNE'] = {'EQUALS': '=', 'SEP': ':', 'EXPORT': 'export', 'UNEXPORT': 'unset'}
        self.shell['TCSH'] = {'EQUALS': ' ', 'SEP': ':', 'EXPORT': 'setenv', 'UNEXPORT': 'unsetenv'}
        self.shell['CYGWIN'] = {'EQUALS': '=', 'SEP': ';', 'EXPORT': 'unset', 'UNEXPORT': 'set'}
        self.shell['RTBOURNE'] = self.shell['BOURNE']
        self.env = {'variables': {}, 'paths': {}}
        self.force_tools_env = {}
        self.skip_runtime = {}
        self._unsetenv = False
        self.ignore_env = {}
        self._read_ignore_env()
        return

    def runtimebuildenv(self, runtime_build_type=True):
        save_env = {}
        if runtime_build_type:
            environ["SCRAM_RUNTIME_TYPE"]="BUILD"
        for k in ['LD_PRELOAD']:
            if k in environ:
                save_env[k] = environ[k]
                del environ[k]
        self.save('RTBOURNE')
        for k, v in save_env.items():
            if k in self.ignore_env: continue
            environ[k] = v
        self.setenv("RTBOURNE")
        if 'rtstring' in self.env:
            if 'RTBOURNE' in self.env['rtstring']:
                for e in self.env['rtstring']['RTBOURNE']:
                    if e in self.ignore_env: continue
                    environ[e] = self.env['rtstring']['RTBOURNE'][e]
        return environ

    def _fixpathvar(self, var, sep):
        if (var in environ) and (environ[var] != ''):
            return '%s%s' % (sep, environ[var])
        return ''

    def _fixlibenv(self, var):
        if environ['SCRAM_ARCH'].startswith('osx') and var == 'LD_LIBRARY_PATH':
            var = 'DYLD_FALLBACK_LIBRARY_PATH'
        return var

    def setenv(self, shell, ostream=None):
        if self.recursive:
            return
        if not ostream:
            ostream = stdout
        shell_data = self.shell[shell]
        sep = shell_data['SEP']
        udata = {}
        data = []
        if not self._unsetenv:
            env_prefix = self.env_backup_prefix
            env = self._runtime()
            for d in env['variables']:
                for var, val in d.items():
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
            print("%s %s;" % (shell_data['UNEXPORT'], unset), file=ostream)
        for d in data:
            for var, val in d.items():
                if var in self.ignore_env: continue
                environ[var] = val
                if  shell == 'RTBOURNE': continue
                if var != 'PATH' and var in oenv:
                    if val == oenv[var]:
                        continue
                print('%s %s%s\"%s\";' % (shell_data['EXPORT'], var,
                      shell_data['EQUALS'], val), file=stdout)
        return True

    def save(self, shell, ostream=None):
        if self.recursive:
            return
        if not ostream:
            ostream = stdout
        if 'SCRAMRT_SET' in environ:
            self._restore_environment(shell)
        env_prefix = self.env_backup_prefix
        env = self._runtime()
        data = []
        sep = self.shell[shell]['SEP']
        backup_vars = ""
        for h in env['variables']:
            for (name, value) in h.items():
                if name in self.ignore_env: continue
                btype = '_SCRAMRT'
                if name not in environ:
                    btype += 'DEL'
                else:
                    backup_vars += "%s=%s;" % (name, environ[name])
                data.append({'%s%s%s' % (env_prefix, name, btype): value[0]})
        if backup_vars:
            backup_vars = backup_vars.strip(';')
            data.append({'SCRAMRT_BACKUP_ENV': b64encode(backup_vars.encode('utf-8')).decode('utf-8')})
        self.backup_type = {}
        opt = {}
        regexp = re.compile('^(.+?)_SRTOPT_(.+)$')
        for (name, value) in env['path'].items():
            m = regexp.match(name)
            if m:
                if m.group(2) in self.ignore_env: continue
                if m.group(1) in self.optional_paths:
                    if not m.group(2) in opt:
                        opt[m.group(2)] = {}
                    opt[m.group(2)][m.group(1)] = 1
                continue
            btype = '_SCRAMRT'
            if name not in environ:
                btype += 'DEL'
            data.append({'%s%s%s' % (env_prefix, name, btype): self._cleanpath(sep.join(value), sep)})
            self.backup_type[name] = btype
        for v in opt:
            btype = ''
            nbtype = ''
            if v in self.backup_type:
                btype = self.backup_type[v]
                nbtype = btype
            else:
                nbtype = '_SCRAMRT'
                if v in environ:
                    nbtype += 'DEL'
            for t in opt[v]:
                xindex = len(data)
                pval = ''
                if btype:
                    k = '%s%s%s' % (env_prefix, v, btype)
                    i = -1
                    for d in data:
                        i += 1
                        if k not in d:
                            continue
                        xindex = i
                        pval = d[k]
                        break
                nval = sep.join(env['path']['%s_SRTOPT_%s' % (t, v)])
                if pval:
                    nval = '%s%s%s' % (nval, sep, pval)
                if xindex == len(data):
                    data.append({})
                data[xindex]['%s%s%s' % (env_prefix, v, nbtype)] = self._cleanpath(nval, sep)
        scram_set = ''
        for e in ['SCRAM_PROJECTNAME', 'SCRAM_PROJECTVERSION', 'SCRAM_ARCH', 'SCRAM_VERSION']:
            scram_set += '%s:' % environ[e]
        data.append({'SCRAMRT_SET':
                     '%s%s' % (scram_set, env_prefix)})
        for v in data:
            for name, value in v.items():
                environ[name] = value.replace('"', '\\"').replace('`', '\\`')
        return

    def optional_env(self, types=[]):
        self.optional_paths = {}
        for t in types:
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
        prefix = self.env_backup_prefix if len(penv)<5 else penv[4]
        bvar = 'SCRAMRT_BACKUP_ENV'
        bval = {} if bvar not in environ else \
            dict([item.split('=', 1)
                  for item in b64decode(environ[bvar]).decode('utf-8').split(';')
                  if item])
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
                        regex = re.compile('^(.*?%s|)%s(%s.*|)$' % (sep, re.escape(value), sep))
                        m = regex.match(val)
                        if m:
                            val = '%s%s' % (m.group(1), m.group(2))
                        val = val.strip(sep)
                        val = val.replace('%s%s' % (sep, sep), sep)
                    if not val:
                        del backup_env[var]
                    else:
                        backup_env[var] = val
        for e in backup_env:
            environ[e] = backup_env[e]
        for e in list(environ.keys()):
            if not e in backup_env:
                del environ[e]

    def _update_overrides(self):
        if 'PATH' in self.env['rtstring']['path']:
            override = join(SCRAM.BASEPATH, 'share', 'overrides', 'bin')
            if exists(override):
                self.env['rtstring']['path']['PATH'].insert(0, override)
        override = join(SCRAM.BASEPATH, 'share', 'overrides', 'python')
        if exists(override):
            for v in ["PYTHONPATH", "PYTHON27PATH", "PYTHON3PATH"]:
                if v in self.env['rtstring']['path']:
                    self.env['rtstring']['path'][v].insert(0, override)
        for e in ["PATH", "LD_LIBRARY_PATH", "PYTHONPATH", "PYTHON27PATH", "PYTHON3PATH"]:
            if e not in self.env['rtstring']['path']:
                continue
            ev = "SCRAM_PREFIX_%s" % e
            if ev not in self.OENV:
                continue
            for override in self.OENV[ev].split(":"):
                if exists(override):
                    self.env['rtstring']['path'][e].insert(0, override)
        if 'SCRAM_IGNORE_RUNTIME_HOOK' not in self.OENV:
            self._runtime_hooks()
            if 'SCRAM_IGNORE_SITE_RUNTIME_HOOK' not in self.OENV:
                ignore_hooks_file = join(self.area.config(), 'SCRAM', 'hooks', 'ignore-site-hooks')
                if not exists(ignore_hooks_file):
                    ignore_hooks_file = ""
                self._runtime_hooks(hook_dir=SCRAM.get_site_hooks(), ignore_hooks_file=ignore_hooks_file)
        return

    def _runtime_hooks(self, hook_dir=None, ignore_hooks_file=""):
        if not hook_dir: hook_dir = self.area.config()
        debug='SCRAM_HOOKS_DEBUG' in self.OENV
        hook = join(hook_dir, 'SCRAM', 'hooks', 'runtime-hook')
        if debug:
          SCRAM.printerror("SCRAM_HOOK: %s" % hook)
        if not exists(hook):
            return
        if debug:
          SCRAM.printerror("SCRAM_HOOK: Found")
        regexp = re.compile(
            '^runtime:((path:(append|prepend|remove|replace):[a-zA-Z0-9-_]+)|(variable:[a-zA-Z0-9-_]+))=(.*)$',
            re.I)
        err, out = SCRAM.run_command('SCRAM_IGNORE_HOOKS=%s SCRAMRT_SET=true %s 2>&1' % (ignore_hooks_file, hook))
        if debug:
          SCRAM.printerror("SCRAM_HOOK:\n%s" % out)
        for line in out.split('\n'):
            if not regexp.match(line):
                if line.strip(): SCRAM.printerror(line)
                continue
            vals = line.split('=', 1)
            items = vals[0].split(':')
            vtype = items[1].lower()
            if vtype == 'path':
                if vtype not in self.env["rtstring"]:
                    self.env["rtstring"][vtype] = {}
                cache = self.env["rtstring"][vtype]
                vtype = items[2].lower()
                evar = items[3]
                if (vtype == 'replace'):
                    xitems = vals[1].split("=", 1)
                    vals[1] = xitems[0]
                    vals.append(xitems[1])
                elif (vtype != 'remove') and (evar not in cache):
                    cache[evar] = []
                for d in vals[1].split(':'):
                    d = d.strip()
                    if not d:
                        continue
                    if vtype == 'append':
                        cache[evar].append(d)
                    elif vtype == 'prepend':
                        cache[evar].insert(0, d)
                    elif vtype == 'remove':
                        if d in cache[evar]:
                            cache[evar].remove(d)
                    elif vtype == 'replace':
                        npath = []
                        for x in cache[evar]:
                            if x != d:
                                npath.append(x)
                            else:
                                for r in vals[2].split(":"):
                                    npath.append(r)
                        cache[evar] = npath
            elif vtype == 'variable':
                if 'variables' not in self.env['rtstring']:
                    self.env['rtstring']['variables'] = []
                found = False
                for i, val in enumerate(self.env['rtstring']['variables']):
                    if items[2] in val:
                        val[items[2]] = [vals[1]]
                        found = True
                        break
                if not found:
                    self.env['rtstring']['variables'].append({items[2]: [vals[1]]})
        return

    def _runtime(self):
        if 'rtstring' in self.env:
            return self.env['rtstring']
        self.env['rtstring'] = {'variables': [], 'path': {}, 'RTBOURNE': {}, 'xenv': {}}
        cache = join(self.area.archdir(), 'RuntimeCache.json')
        if exists(cache):
            st = stat(cache)
            if (st.st_size > 0):
                toolcache = self.area.toolcachename()
                if st.st_mtime >= stat(toolcache).st_mtime:
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
        for k in list(self.env):
            if k != 'rtstring':
                del self.env[k]
        try:
            with open(cache, 'w') as ref:
                dump(self.env['rtstring'], ref, sort_keys=True, indent=2)
        except (OSError, IOError) as e:
            pass
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
        gmake = ""
        for trtvar, trtval in tool['RUNTIME'].items():
            if trtvar in self.ignore_env: continue
            if trtvar.startswith('PATH:'):
                var = trtvar[5:]
                if var in self.ignore_env: continue
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
                self.env['rtstring']['variables'].append({trtvar: trtval})

    def _read_ignore_env(self):
        if not 'HOME' in environ: return
        env_file = join(environ["HOME"], ".scramrc", "runtime")
        if not exists(env_file): return
        ignore_env = ""
        with open(env_file) as f_in:
            for line in f_in.readlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                items = line.split(":", 1)
                if (len(items)==2) and (items[0]=="ignore"):
                    for e in [ x for x in items[1].split(" ") if x]:
                        ignore_env += "      %s\n" % e
                        self.ignore_env[e] = 1
        if ignore_env:
            SCRAM.printerror("**** Following environment variables are ignored via ~/.scramrc/runtime and will not be set/changed.\n%s" % ignore_env)
        return


    def _cleanpath(self, path, sep):
        upath = {}
        opath = []
        for p in path.split(sep):
            p = abspath(p)
            if not p:
                continue
            while '/./' in p:
                p = p.replace('/./', '/')
            while '//' in p:
                p = p.replace('//', '/')
            while p.endswith('/.'):
                p = p[:-2]
            if not p:
                p = '/'
            if p not in upath:
                upath[p] = 1
                opath.append(p)
        return sep.join(opath)
