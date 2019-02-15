from os import environ, chmod, getcwd
from os.path import join, exists, isdir, basename, dirname
from sys import stderr, exit
from subprocess import getstatusoutput as cmd
from glob import glob
from SCRAM.Utilities.AddDir import adddir, copydir, copyfile


class ConfigArea(object):
    def __init__(self, forcearch=""):
        self._admindir = '.SCRAM'
        self._configurationdir = 'config'
        self._forcearch = forcearch
        self._sourcedir = None
        self._releasetop = None
        self._location = None
        self._configchksum = None
        self._symlinks = 0
        self._name = None
        self._version = None
        self._archdir = None
        self._archs = None
        if not forcearch:
            forcearch = environ['SCRAM_ARCH']
        self._arch = forcearch

    def toolcachename(self):
        return join(self.archdir(), 'ToolCache.db.gz')

    def projectcachename(self):
        return join(self.archdir(), 'ProjectCache.db.gz')

    def symlinks(self, links=-1):
        if links >= 0:
            self._symlinks = links
        return self._symlinks

    def calchksum(self):
        conf = join(self.location(), self.configurationdir(), 'config_tag')
        if exists(conf):
            tag = open(conf, 'r').readline().strip('\n')
            return tag
        return ''

    def configchksum(self, chsum=None):
        if chsum:
            self._configchksum = chsum
        return self._configchksum

    def name(self, name=None):
        if name:
            self._name = name
        return self._name

    def version(self, version=None):
        if version:
            self._version = version
        return self._version

    def setup(self, location, areaname=None, symlink=False, localarea=None):
        if (not areaname):
            areaname = self.version()
        self.location

    def setup(self, location, areaname=None, symlink=0, locarea=None):
        if not areaname:
            areaname = self.version()
        self.location(join(location, areaname))
        self.symlinks(symlink)
        if self.configchksum():
            envfile = join(self.location(), self.admindir(), 'Environment')
            if (not locarea) and exists(envfile):
                locarea = ConfigArea()
                locarea.bootstrapfromlocation(self.location())
            if locarea and locarea.configchksum() != self.configchksum():
                err = "ERROR: Can not setup your current working area for " \
                      "SCRAM_ARCH: $ENV{SCRAM_ARCH}\n"
                err += "Your current development area ${location}/${" \
                       "areaname}\n"
                err += "is using a different ${areaname}/config then the " \
                       "one used for\n"
                err += self.releasetop()
                print(err, file=stderr)
                exit(1)
        adddir(self.archdir())
        return

    def configurationdir(self, dir=None):
        if dir:
            self._configurationdir = dir
        return self._configurationdir

    def sourcedir(self, dir=None):
        if dir:
            self._sourcedir = dir
        return self._sourcedir

    def releasetop(self, dir=None):
        if dir:
            self._releasetop = dir
        return self._releasetop

    def admindir(self, dir=None):
        if dir:
            self._admindir = dir
        return self._admindir

    def bootstrapfromlocation(self, location=None):
        if location is not None or self._location is None:
            location = self.searchlocation(location)
            if not location:
                return False
            self.location(location)
        self._LoadEnvFile()
        return True

    def location(self, dir=None):
        if dir:
            self._location = dir
            self._archs = None
            self._setAreaArch()
        elif self._location is None:
            self._location = self.searchlocation()
            if self._location:
                self._setAreaArch()
        return self._location

    def searchlocation(self, thispath=None):
        if not thispath:
            thispath = getcwd()
        while thispath and (thispath != '/') and (thispath != '.'):
            admindir = join(thispath, self.admindir())
            if isdir(admindir):
                return thispath
            thispath = dirname(thispath)
        return ''

    def archname(self, arch=None):
        if arch:
            self._arch = arch
            if self._location:
                self.archdir(join(self._location, self._admindir, self._arch))
        return self._arch

    def archdir(self, dir=None):
        if dir:
            self._archdir = dir
        return self._archdir

    def satellite(self, location, areaname=None, symlink=0, locarea=None):
        relloc = self.location()
        sat = ConfigArea(environ['SCRAM_ARCH'])
        sat.name(self.name())
        sat.version(self.version())
        sat.configurationdir(self.configurationdir())
        sat.sourcedir(self.sourcedir())
        sat.releasetop(relloc)
        sat.configchksum(self.configchksum())
        sat.setup(location, areaname, symlink, locarea)
        devconf = join(sat.location(), sat.configurationdir())
        relconf = join(self.location(), self.configurationdir())
        if not isdir(devconf):
            copydir(relconf, devconf)
        else:
            adddir(join(devconf, 'toolbox'))
            copydir(join(relconf, 'toolbox', self.arch()),
                    join(devconf, 'toolbox', self.arch()))
        adddir(join(sat.location(), sat.sourcedir()))
        copyfile(self.toolcachename(), sat.archdir())
        copydir(join(self.archdir(), 'timestamps'),
                join(sat.archdir(), 'timestamps'))
        envfile = join(sat.archdir(), 'Environment')
        with open(envfile, 'w') as ref:
            ref.write('RELEASETOP=%s\n' % relloc)
        chkarch = join(sat.archdir(), 'chkarch')
        ref = open(chkarch, 'w')
        ref.close()
        envfile = join(sat.location(), sat.admindir(), 'Environment')
        if not exists(envfile):
            sat.save()
        return sat

    def copyenv(self, env):
        for e in self.ENV:
            env[e] = self.ENV[e]
        return

    def arch(self):
        return self._arch

    def toolbox(self):
        return join(self.location(), self.configurationdir(), 'toolbox', self.arch(), 'tools')

    def config(self):
        return join(self.location(), self.configurationdir())

    def save(self):
        self._SaveEnvFile()

    def scram_version(self):
        with open(join(self.config(), 'scram_version')) as ref:
            return ref.readline().strip()

    # ---- support routines
    def _setAreaArch(self):
        arch = self._forcearch
        if not arch:
            toolbox = join(self.location(), self.configurationdir(), 'toolbox')
            if self._archs is None:
                self._archs = []
                for arch in glob(join(toolbox, '*')):
                    if isdir(join(arch, 'tools')):
                        arch = basename(arch)
                        self._archs.append(arch)
            if (not isdir(join(toolbox, self.arch()))) and (len(self._archs) == 1):
                arch = self._archs[0]
        if not arch:
            arch = self.arch
        self.archname(arch)
        return

    def _SaveEnvFile(self):
        envfile = join(self.location(), self.admindir(), 'Environment')
        with open(envfile, 'w') as ref:
            ref.write('SCRAM_PROJECTNAME=%s\n' % self.name())
            ref.write('SCRAM_PROJECTVERSION=%s\n' % self.version())
            ref.write('SCRAM_CONFIGDIR=%s\n' % self.configurationdir())
            ref.write('SCRAM_SOURCEDIR=%s\n' % self.sourcedir())
            ref.write('SCRAM_SYMLINKS=%s\n' % self.symlinks())
            ref.write('SCRAM_CONFIGCHKSUM=%s\n' % self.configchksum())
        chmod(envfile, 0o644)
        return

    def _readEnvFile(self, envfile):
        with open(envfile, 'r') as ref:
            for line in [l.strip('\n').strip() for l in ref.readlines()]:
                if not line or line.startswith('#'):
                    continue
                (name, value) = line.split('=', 1)
                self.ENV[name] = value
        return

    def _LoadEnvFile(self):
        self.ENV = {}
        envfile = join(self.location(), self.admindir(), 'Environment')
        self._readEnvFile(envfile)
        envfile = join(self.archdir(), 'Environment')
        if exists(envfile):
            self._readEnvFile(envfile)
        if 'SCRAM_PROJECTNAME' in self.ENV:
            self.name(self.ENV['SCRAM_PROJECTNAME'])
        if 'SCRAM_SYMLINKS' in self.ENV:
            self.symlinks(int(self.ENV['SCRAM_SYMLINKS']))
        if 'SCRAM_CONFIGCHKSUM' in self.ENV:
            self.configchksum(self.ENV['SCRAM_CONFIGCHKSUM'])
        if 'SCRAM_PROJECTVERSION' in self.ENV:
            self.version(self.ENV['SCRAM_PROJECTVERSION'])
        if 'SCRAM_CONFIGDIR' in self.ENV:
            self.configurationdir(self.ENV['SCRAM_CONFIGDIR'])
        if 'SCRAM_SOURCEDIR' in self.ENV:
            self.sourcedir(self.ENV['SCRAM_SOURCEDIR'])
        if 'RELEASETOP' in self.ENV:
            self.releasetop(self.ENV['RELEASETOP'])
        return
