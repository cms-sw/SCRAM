import SCRAM
from SCRAM.BuildSystem import get_safename
from SCRAM.BuildSystem.BuildFile import BuildFile as XMLReader
from SCRAM.BuildSystem.BuildData import BuildData
from SCRAM.BuildSystem.ToolManager import ToolManager
from SCRAM.BuildSystem.MakeInterface import MakeInterface
from argparse import ArgumentParser
from SCRAM.Core.RuntimeEnv import RuntimeEnv
from SCRAM.Core.Core import Core
from SCRAM.Core.Utils import create_productstores, cmsos
from os import getcwd, environ, chdir, makedirs, stat, remove
from os.path import join, exists, dirname, normpath, basename
from glob import glob
from json import dump, load
from stat import S_ISDIR
from re import compile

VALID_DIR_NAMES = compile(r'.*/[a-zA-Z0-9][a-zA-Z0-9-_]*$')
IGNORE_DIR_NAMES = compile(r'.*/(CVS|\..*)$')


class DirCache(object):
    def __init__(self, toolmanager, buildfile_name):
        self.stats = {}
        self.toolmanager = toolmanager
        self.reset = False
        self.buildfile = buildfile_name
        self.buildfile_ext = '.xml'
        self.dirty = False
        self.cachefile = join(toolmanager.area.archdir(), 'DirCache.json')
        self.rebuild_make = {}
        self.project_context = None
        self.cache = {'DIRCACHE': {},
                      'ADDEDDIR': {},
                      'REMOVEDDIR': {},
                      'BFCACHE': {},
                      'REMOVEDBF': {},
                      'ADDEDBF': {},
                      'CLASSMAP': {},
                      'PACKMAP': {},
                      'CLASSDATA': []}
        from SCRAM.Plugins.BuildRules import BuildRules
        self.buildrules = BuildRules(toolmanager)
        self.env = {}
        for e in environ:
            if e.startswith('SCRAMRT_'):
                continue
            if (e.startswith('SCRAM')) or (e in ["LOCALTOP", "RELEASETOP"]):
                self.env[e] = environ[e]

    def buildfile_name(self):
        return self.buildfile + self.buildfile_ext

    def load_cache(self):
        if exists(self.cachefile):
            self.dirty = False
            with open(self.cachefile) as ref:
                self.cache = load(ref)
        return

    def load_classdata(self):
        bf = XMLReader(self.toolmanager)
        if not bf.parse(join(environ['SCRAM_CONFIGDIR'], self.buildfile_name())):
            return False
        self.buildrules.project_bf = bf
        classdata = []
        for cp in bf.contents['CLASSPATH']:
            cpdata = []
            for cp_item in cp.split("/"):
                cpdata.append(cp_item.split("+", 1))
            classdata.append(cpdata)
        if classdata != self.cache['CLASSDATA']:
            self.reset = True
            self.cache['CLASSDATA'] = classdata
            self.cache['CLASSMAP'] = {}
        return True

    def save_cache(self):
        self.dirty = False
        with open(self.cachefile, "w") as ref:
            dump(self.cache, ref, sort_keys=True, indent=2)
        return

    def checkfiles(self, reset):
        if not self.load_classdata():
            return False
        self.reset = self.reset or reset
        self.buildclass(environ['SCRAM_CONFIGDIR'])
        self.buildclass(environ['SCRAM_SOURCEDIR'])
        self.checktree(environ['SCRAM_CONFIGDIR'], True, recursive=False)
        self.checktree(environ['SCRAM_SOURCEDIR'], True)
        return True

    def getstats(self, path):
        if path in self.stats:
            return self.stats[path]
        try:
            self.stats[path] = stat(path)
        except Exception:
            self.stats[path] = None
        return self.stats[path]

    def checktree(self, path, required, recursive=True):
        st = self.getstats(path)
        if st is None:
            if required:
                SCRAM.die("Missing required path: %s" % path)
            self.prune(path)
            return
        if path not in self.cache['DIRCACHE']:
            clds = []
            if recursive:
                clds = self.getdir(path)
            self.cache['ADDEDDIR'][path] = 2
            self.cache['DIRCACHE'][path] = [st.st_mtime] + clds
            self.dirty = True
            required = True
        elif self.cache['DIRCACHE'][path][0] != st.st_mtime:
            curdirs = []
            if recursive:
                curdirs = self.getdir(path)
                olddirs = self.cache['DIRCACHE'][path][1:]
                for odir in olddirs:
                    if odir not in curdirs:
                        self.prune(odir, True)
            self.cache['ADDEDDIR'][path] = 1
            self.cache['DIRCACHE'][path] = [st.st_mtime] + curdirs
            self.dirty = True
            required = False
        else:
            required = False
        if self.reset:
            self.cache['ADDEDDIR'][path] = 1
            self.dirty = True
        bf = join(path, self.buildfile_name())
        bf_st = None
        try:
            bf_st = stat(bf)
        except Exception:
            pass
        bfcachedir = join(environ['LOCALTOP'], environ['SCRAM_INTwork'], 'cache/bf/%s' % path)
        cbf = join(bfcachedir, "BuildFile")
        if bf_st is None:
            if bf in self.cache['BFCACHE']:
                self.cache['REMOVEDBF'][bf] = 1
                del self.cache['BFCACHE'][bf]
                self.dirty = True
                makedirs(bfcachedir, exist_ok=True)
                with open(cbf, "w"):
                    pass
        else:
            bfmtime = bf_st.st_mtime
            if self.reset or (bf not in self.cache['BFCACHE']) or \
               (bfmtime != self.cache['BFCACHE'][bf]):
                if not exists(cbf) or bf in self.cache['BFCACHE']:
                    makedirs(bfcachedir, exist_ok=True)
                    with open(cbf, "w"):
                        pass
                self.cache['ADDEDBF'][bf] = 1
                self.cache['BFCACHE'][bf] = bfmtime
                self.dirty = True
        if recursive:
            for sdir in self.cache['DIRCACHE'][path][1:]:
                self.checktree(sdir, required)
        return

    def getdir(self, path):
        dirs = []
        for d in glob(join(path, '*')):
            if not VALID_DIR_NAMES.match(d) or IGNORE_DIR_NAMES.match(d):
                continue
            st = self.getstats(d)
            if S_ISDIR(st.st_mode) and (not self.buildclass(d)[2]):
                dirs.append(d)
        return dirs

    def prune(self, path, skip_parent=False):
        if not skip_parent:
            parent = dirname(path)
            if parent and parent in self.cache['DIRCACHE']:
                self.cache['DIRCACHE'][parent].remove(path)
                self.cache['ADDEDDIR'][parent] = 1
                self.dirty = True
        bf = join(path, self.buildfile_name())
        if bf in self.cache['BFCACHE']:
            if not exists(bf):
                self.cache['REMOVEDBF'][bf] = 1
            del self.cache['BFCACHE'][bf]
            if bf in self.cache['ADDEDBF']:
                del self.cache['ADDEDBF'][bf]
            self.dirty = True
        if path in self.cache['PACKMAP']:
            del self.cache['PACKMAP'][path]
        if path in self.cache['ADDEDDIR']:
            del self.cache['ADDEDDIR'][path]
        if path not in self.cache['DIRCACHE']:
            return
        self.dirty = True
        if not exists(path):
            self.cache['REMOVEDDIR'][path] = 1
        sdirs = self.cache['DIRCACHE'][path][1:]
        del self.cache['DIRCACHE'][path]
        for xdir in sdirs:
            self.prune(xdir, skip_parent=True)
        return True

    def buildclass(self, path):
        if path in self.cache['CLASSMAP']:
            return self.cache['CLASSMAP'][path]
        dirs = normpath(path).split("/")
        ranks = []
        for cp in self.cache['CLASSDATA']:
            rank = [[], dirs]
            idx = 0
            for component in cp:
                try:
                    sdir = rank[1][idx]
                except Exception:
                    rank[1] = []
                    break
                xtype = 0
                if component[0] == '':
                    xtype = 1
                elif component[0] != sdir:
                    break
                rank.append([xtype, component[1]])
                rank[0].append(sdir)
                idx += 1
            rank[1] = rank[1][idx:]
            ranks.append(rank)
        if not ranks:
            return ""
        ranks.sort(key=lambda x: len(x[1]))
        best = []
        brank = len(ranks[0][1])
        for rank in ranks:
            if len(rank[1]) == brank:
                best.append(rank)
        n = 0
        cp = best[n][len(best[n]) - 1]
        self.cache['CLASSMAP'][path] = [cp[1], '/'.join(best[n][0]), '/'.join(best[n][1])]
        return self.cache['CLASSMAP'][path]

    def dir_make(self):
        mk_dir = join(self.toolmanager.area.archdir(), 'MakeData', 'DirCache')
        makedirs(mk_dir, mode=0o755, exist_ok=True)
        mk_dir = join(environ['LOCALTOP'], environ['SCRAM_INTwork'], 'MakeData', 'DirCache')
        makedirs(mk_dir, mode=0o755, exist_ok=True)
        xml = XMLReader()
        for xdir in self.cache['ADDEDDIR']:
            classinfo = self.buildclass(xdir)
            classname = classinfo[0].upper()
            flag = classname in ["PACKAGE", "SUBSYSTEM", "DOMAIN", "PYTHON"]
            if classname == "LIBRARY":
                self.cache['PACKMAP'][dirname(xdir)] = xdir
                continue
            if classname == "SCRIPTS":
                if join(xdir, self.buildfile_name()) in self.cache["BFCACHE"]:
                    continue
                flag = True
            if not flag:
                continue
            name = basename(xdir)
            pkgclass = BuildData('', classinfo)
            pkgclass.branch['parent'] = dirname(xdir)
            pkgclass.branch['name'] = name
            pkgclass.branch['environment'] = self.env
            pkgclass.branch['context'] = xml
            self.buildrules.process(pkgclass.branch["template"], pkgclass, self.cache['DIRCACHE'])
        self.cache['ADDEDDIR'] = {}
        rmv_mk = join(environ['LOCALTOP'], environ['SCRAM_INTwork'], 'MakeData', 'RmvDirCache.mk')
        if self.cache['REMOVEDDIR']:
            self.buildrules.addRemakeDirectory(mk_dir)
            with open(rmv_mk, "w") as mk:
                for xdir in self.cache['REMOVEDDIR']:
                    print("RMVDIR", xdir)
                    sname = get_safename(xdir)
                    SCRAM.run_command("cd %s; rm -f %s.mk %s_*.mk" % (mk_dir, sname, sname))
                    mk.write('REMOVED_DIRS += %s\n' % (xdir))
            self.cache['REMOVEDDIR'] = {}
        if not exists(rmv_mk):
            with open(rmv_mk, "w") as mk:
                pass
        return

    def write_buildfile(self):
        xml = XMLReader(self.toolmanager)
        localarea = self.toolmanager.area
        bf_cache_dir = join(localarea.archdir(), 'BuildFiles')
        for bf in self.cache['ADDEDBF']:
            if not xml.parse(bf):
                return False
            bfdir = dirname(bf)
            bf_class_dir = bfdir
            if bfdir in self.cache['PACKMAP']:
                bf_class_dir = self.cache['PACKMAP'][bfdir]
            classinfo = self.buildclass(bf_class_dir)
            bf_cache = join(bf_cache_dir, bfdir)
            makedirs(bf_cache, mode=0o755, exist_ok=True)
            pkgclass = BuildData(bf, classinfo)
            pkgclass.branch['environment'] = self.env
            pkgclass.branch['context'] = xml
            self.buildrules.process(pkgclass.branch["template"], pkgclass, self.cache['DIRCACHE'])
            xml.save_json(join(bf_cache_dir, bf))
            if pkgclass.branch["class"] == "LIBRARY":
                prod = xml.contents["NAME"]
                with open(join(bf_cache_dir, bfdir, prod), "w") as ref:
                    ref.write("{0}_PACKAGE := self/{1}\n".format(prod, bf_class_dir))
            else:
                prods = xml.get_build_products()
                for ptype in prods:
                    for prod in prods[ptype]:
                        with open(join(bf_cache_dir, bfdir, prod), "w") as ref:
                            ref.write("{0}_PACKAGE := self/{1}\n".format(prod, bfdir))
        self.cache['ADDEDBF'] = {}
        if self.cache['REMOVEDBF']:
            for bf in self.cache['REMOVEDBF']:
                print("RMVBF", bf)
                bf_cache = join(bf_cache_dir, bf)
                if exists(bf_cache):
                    remove(bf_cache)
            self.cache['REMOVEDBF'] = {}
        return

    def get_makerules(self):
        return join(self.toolmanager.area.archdir(), 'BuildFiles', 'ProductCache.txt')

    def has_makerules(self):
        return exists(self.get_makerules())

    def write_gmake(self):
        self.buildrules.startRules()
        makerules = self.get_makerules()
        self.rebuild_make = {}
        if exists(makerules):
            remove(makerules)
        self.dir_make()
        self.write_buildfile()
        self.buildrules.endRules()
        self.save_cache()
        with open(makerules, "w"):
            pass
        return


def process(args, main_opts):
    parser = ArgumentParser(add_help=False)
    parser.add_argument('-t', '--testrun',
                        dest='testrun',
                        action='store_true',
                        default=False,
                        help='Do not run gmake but only do any internal SCRAM caches update.')
    parser.add_argument('--ignore-arch',
                        dest='ignore_arch',
                        action='store_true',
                        default=False,
                        help='Avoid SCRAM warning about architecture mismatch e.g. '
                             'compiling on SLC5 machine an slc6_* based release.')
    parser.add_argument('-r', '--reset',
                        dest='reset',
                        action='store_true',
                        default=False,
                        help='Reset/re-generate all internal SCRAM caches.')
    opts, args = parser.parse_known_args(args)
    area = Core()
    area.checklocal()
    area.init_env()
    localarea = area.localarea()
    env = RuntimeEnv(localarea)
    runtime_build_type = True
    for arg in args:
        arg = arg.split("_")[0]
        if arg in ["unittests", "runtests"]:
            runtime_build_type = False
            break
    new_env = env.runtimebuildenv(runtime_build_type)
    for k in environ.keys():
      if not k in new_env:
        del environ[k]
    for k in new_env:
      environ[k] = new_env[k]
    create_productstores(localarea)
    location = localarea.location()
    cwd = getcwd()
    srcloc = join(location, environ['SCRAM_SOURCEDIR'])
    if cwd.startswith(srcloc):
        cwd = cwd[len(location):].strip("/")
    else:
        cwd = environ['SCRAM_SOURCEDIR']
    environ['THISDIR'] = cwd
    environ['SCRAM_BUILDFILE'] = 'BuildFile'
    environ['SCRAMRT_SET'] = 'true'
    chdir(location)
    workdir = join(location, environ['SCRAM_INTwork'])
    if not exists(workdir):
        makedirs(workdir, 0o755)
    toolmanager = ToolManager(localarea)
    dircache = DirCache(toolmanager, environ['SCRAM_BUILDFILE'])
    if exists(dircache.cachefile) and not SCRAM.COMMANDS_OPTS.force and not opts.reset:
        SCRAM.scramdebug("Reading cached data")
        dircache.load_cache()
    ProjectInit = join(environ['SCRAM_CONFIGDIR'], 'ProjectInit')
    if exists(ProjectInit):
        SCRAM.scramdebug("Running %s script" % ProjectInit)
        e, out = SCRAM.run_command(ProjectInit)
        SCRAM.printmsg(out)
        SCRAM.scramdebug("Script exitted with status %s" % e)
    if not exists(dircache.has_makerules()):
        opts.reset = True
    if not SCRAM.COMMANDS_OPTS.force:
        dircache.checkfiles(opts.reset)
    if dircache.dirty:
        dircache.write_gmake()
    chkarch = join(localarea.admindir(), "chkarch")
    if opts.ignore_arch and exists(chkarch):
        remove(chkarch)
    if exists(chkarch):
        os = cmsos()
        if not environ["SCRAM_ARCH"].startswith(os):
            SCRAM.printwarning("You are trying to compile/build for architecture %s on %s OS which"
                               "might not work.\nIf you know this SCRAM_ARCH/OS combination works "
                               "then please first run 'scram build --ignore-arch'.")
    MAKER = MakeInterface()
    MAKER.exec(args, main_opts)
    return True
