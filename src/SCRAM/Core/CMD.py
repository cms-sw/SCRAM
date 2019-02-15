from os import environ, getcwd, execv
from os.path import exists, join
from sys import stderr, argv
from re import match
try:
    from subprocess import run as run_cmd
except:
    from subprocess import call as run_cmd
import SCRAM
from SCRAM.Configuration.ConfigArea import ConfigArea


class Core(object):
    def __init__(self):
        self._localarea = None
        return

    def localarea(self, area=None):
        if area is not None:
            self._localarea = area
        return self._localarea

    def initialize(self):
        if self.localarea() is not None:
            return
        area = ConfigArea(SCRAM.FORCED_ARCH)
        location = area.location()
        if not location:
            self.localarea(False)
            return
        self._localarea = area
        environ['LOCALTOP'] = location
        area.bootstrapfromlocation()
        arch = area.arch()
        environ['SCRAM_ARCH'] = arch
        environ['THISDIR'] = getcwd().replace(location, '').strip('/')
        rel = area.releasetop()
        if not rel:
            return
        rel_file = join(rel, area.admindir(), arch, 'ProjectCache.db.gz')
        if exists(rel_file):
            return
        err = '********** ERROR: Missing Release top ************\n' \
              '  The release area "%s"\n' \
              '  for "%s" version "%s" is not available/usable.' \
              % (rel, area.name(), area.version())
        print(err, file=stderr)
        version = area.version()
        m = match('^(([^\d]*\d+_\d+)_).*$', version)
        if not m:
            return
        ver_exp = m.group(1)
        rel_series = m.group(2)
        from SCRAM.Core.ProjectDB import ProjectDB
        db = ProjectDB()
        res = db.listall(area.name(), ver_exp+'.+')
        if not res or (arch not in res):
            return
        rels = [item[1] for item in res[arch] if item[1] != version]
        if rels:
            err = '  In case this release has been deprecated, you can move your code to\n' \
                  '  one of the following release(s) of release series "%s".\n\n' \
                  '  %s' % (rel_series, '\n  '.join(rels))
        else:
            err = '  Sorry, there is no other release installed which you can use for this '\
                  'release series "%s".' % rel_series
        print(err, file=stderr)
        print('***********************************************', file=stderr)


def cmd_version(args):
    print("%s" % SCRAM.VERSION)
    return True


def cmd_help(args):
    run_cmd(['man', 'scram'])
    return True


def cmd_arch(args):
    c = Core()
    c.initialize()
    print("%s" % environ['SCRAM_ARCH'])
    return True


def spawnversion(newversion='V2_99_99'):
    environ['SCRAM_VERSION'] = newversion
    execv(SCRAM_BASEPATH + "/common/scram", argv)


def cmd_unsetenv(args):
    spawnversion()
    return True


def cmd_list(args):
    spawnversion()
    return True


def cmd_build(args):
    spawnversion()
    return True


def cmd_config(args):
    spawnversion()
    return True


def cmd_db(args):
    spawnversion()
    return True


def cmd_project(args):
    from SCRAM.Core.ProjectDB import ProjectDB
    d = ProjectDB()
    d.getarea('CMSSW', 'CMSSW_10_5_0_pre1')
    return True


def cmd_runtime(args):
    spawnversion()
    return True


def cmd_setup(args):
    spawnversion()
    return True


def cmd_tool(args):
    spawnversion()
    return True
