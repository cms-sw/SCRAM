import SCRAM
from SCRAM.BuildSystem.BuildFile import BuildFile as XMLReader
from SCRAM.BuildSystem.ToolManager import ToolManager
from argparse import ArgumentParser
from SCRAM.Core.RuntimeEnv import RUNTIME_SHELLS, RuntimeEnv
from SCRAM.Utilities.AddDir import adddir, fixpath
from SCRAM.Core.Core import Core
from SCRAM.Core.Utils import create_productstores
from os import getcwd, environ, chdir, makedirs, stat, remove
from os.path import join, exists, getmtime, dirname
from glob import glob
from json import dump, load
from stat import S_ISDIR
from re import compile

VALID_DIR_NAMES = compile('.*/[a-zA-Z0-9][a-zA-Z0-9-_]*$')
IGNORE_DIR_NAMES = compile('.*/(CVS|\..*)$')


class DirCache(object):
    def __init__(self, toolmanager, buildfile_name):
        self.stats = {}
        self.toolmanager = toolmanager
        self.reset = False
        self.buildfile = buildfile_name
        self.buildfile_ext = '.xml'
        self.dirty = False
        self.cache = {'DIRCACHE': {},
                      'ADDEDDIR': {},
                      'REMOVEDDIR': {},
                      'BFCACHE': {},
                      'REMOVEDBF': {},
                      'ADDEDBF': {},
                      'CLASSMAP': {},
                      'CLASSDATA': []}
        self.cachefile = join(toolmanager.area.archdir(), 'DirCache.json')
        return

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
        print("SAVED")
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
        if self.dirty:
            self.cache['ADDEDBF'][join(environ['SCRAM_CONFIGDIR'], self.buildfile_name())] = 1
        return True

    def getstats(self, path):
        if path in self.stats:
            return self.stats[path]
        try:
            self.stats[path] = stat(path)
        except:
            self.stats[path] = None
        return self.stats[path]

    def checktree(self, path, required, recursive=True):
        st = self.getstats(path)
        if st is None:
            if required:
                SCRAM.die(str(e))
            self.prune(path)
            return
        if path not in self.cache['DIRCACHE']:
            self.cache['ADDEDDIR'][path] = 1
            self.cache['DIRCACHE'][path] = [st.st_mtime] + self.getdir(path)
            self.dirty = True
            required = True
        elif self.cache['DIRCACHE'][path][0] != st.st_mtime:
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
        bf_dir = join(environ['SCRAM_INTwork'], 'cache', 'bf', path)
        cbf = join(bf_dir, self.buildfile)
        bf = join(path, self.buildfile_name())
        bf_st = None
        try:
            bf_st = stat(bf)
        except:
            pass
        if bf_st is None:
            if bf in self.cache['BFCACHE']:
                self.cache['REMOVEDBF'][bf] = 1
                del self.cache['BFCACHE'][bf]
                self.dirty = True
        else:
            bfmtime = bf_st.st_mtime
            if self.reset or (bf not in self.cache['BFCACHE']) or \
               (bfmtime != self.cache['BFCACHE'][bf]):
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
            if S_ISDIR(st.st_mode):
                classinfo = self.buildclass(d)
                if not classinfo[2]:
                    dirs.append(d)
        return dirs

    def prune(self, path, skip_parent=False):
        if not skip_parent:
            parent = dirname(path)
            if parent and parent in self.cache['DIRCACHE']:
                self.cache['DIRCACHE'][parent].remove(path)
                self.cache['ADDEDDIR'][parent] = 1
                self.dirty = True
        if path in self.cache['ADDEDDIR']:
            del self.cache['ADDEDDIR'][path]
        if path not in self.cache['DIRCACHE']:
            return
        self.dirty = True
        bf = join(path, self.buildfile_name())
        if bf in self.cache['BFCACHE']:
            if not exists(bf):
                self.cache['REMOVEDBF'][bf] = 1
            del self.cache['BFCACHE'][bf]
            if bf in self.cache['ADDEDBF']:
                del self.cache['ADDEDBF'][bf]
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
        dirs = fixpath(path).split("/")
        ranks = []
        for cp in self.cache['CLASSDATA']:
            rank = [[], dirs]
            idx = 0
            for component in cp:
                try:
                    sdir = rank[1][idx]
                except:
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
        self.cache['CLASSMAP'][path] = [cp[1].upper(), '/'.join(best[n][0]), '/'.join(best[n][1])]
        return self.cache['CLASSMAP'][path]

    def dir_make(self):
        mk_dir = join(environ['SCRAM_INTwork'], 'MakeData', 'DirCache')
        adddir(mk_dir)
        srclen = len(environ['SCRAM_SOURCEDIR']) + 1
        for xdir in dircache.cache['ADDEDDIR']:
            classinfo = dircache.buildclass(xdir)
            if classinfo[0] in ['SUBSYSTEM', 'PACKAGE', 'DOMAIN']:
                name = xdir[srclen:]
                sname = xdir.replace('/', '_')
                with open(join(mk_dir, sname + '.mk'), "w") as mk:
                    mk.write('ALL_%sS += %s\n' % (classinfo[0], name))
                    mk.write('subdirs_%s := %s\n' %
                             (sname, ' '.join([d.replace('/', '_') for d in dircache.cache['DIRCACHE'][xdir][1:]])))
        dircache.cache['ADDEDDIR'] = {}
        return

    def write_buildfile(self):
        xml = XMLReader(self.toolmanager)
        localarea = self.toolmanager.area
        for bf in self.cache['ADDEDBF']:
            if bf == 'src/Utilities/General/test/BuildFile.xml':
                continue
            classinfo = self.buildclass(bf)
            if not xml.parse(bf):
                return False
            bf_cache = join(localarea.archdir(), 'BuildFiles', dirname(bf))
            adddir(bf_cache)
            xml.save_on_change(join(localarea.archdir(), 'BuildFiles', bf))
        dircache.cache['ADDEDBF'] = {}
        return

    def write_gmake(self):
        if dircache.cache['ADDEDDIR']:
            self.dir_make()
        if dircache.cache['ADDEDBF']:
            self.write_buildfile()


def process(args):
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
    env.runtimebuildenv()
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
    prodStore = join(localarea.archdir(), 'BuildFiles', 'ProductCache.txt')
    if not exists(prodStore):
        opts.reset = True
    if not SCRAM.COMMANDS_OPTS.force:
        dircache.checkfiles(opts.reset)
    if dircache.dirty:
        if exists(prodStore):
            remove(prodStore)
        dircache.write_gmake()
        dircache.save_cache()
        with open(prodStore, "w") as ref:
            pass
    return True
