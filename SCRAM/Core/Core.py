import SCRAM
from SCRAM.Configuration.ConfigArea import ConfigArea
from SCRAM.Core.ProjectDB import ProjectDB
from os import environ, getcwd
from os.path import join, exists
from re import match


class Core(object):
    def __init__(self):
        self._localarea = None
        self.initialize()
        return

    def localarea(self, area=None):
        if area is not None:
            self._localarea = area
        return self._localarea

    def islocal(self):
        return self._localarea

    def checklocal(self):
        if not self.islocal():
            SCRAM.scramfatal("Unable to locate the top of local release. "
                             "Please run this command from a SCRAM-based area.")

    def init_env(self):
        if self.localarea() is None:
            return
        self.localarea().copyenv(environ)
        if 'SCRAM_TMP' not in environ:
            environ['SCRAM_TMP'] = 'tmp'
        environ['SCRAM_INTwork'] = join(environ['SCRAM_TMP'], environ['SCRAM_ARCH'])
        return

    def initialize(self, arch=None):
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
        rel_file = join(rel, area.admindir(), arch, 'DirCache.json')
        if exists(rel_file):
            return
        err = '********** ERROR: Missing Release top ************\n' \
              '  The release area "%s"\n' \
              '  for "%s" version "%s" is not available/usable.' \
              % (rel, area.name(), area.version())
        SCRAM.printerror(err)
        version = area.version()
        m = match(r'^(([^\d]*\d+_\d+)_).*$', version)
        if not m:
            return
        ver_exp = m.group(1)
        rel_series = m.group(2)
        db = ProjectDB()
        res = db.listall(area.name(), ver_exp + '.+')
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
        SCRAM.printerror(err)
        SCRAM.printerror('***********************************************')
