import re

from socket import getfqdn
from glob import glob
from os.path import exists, join, abspath, isdir, getmtime, basename
from os import environ, chmod
from re import compile
from sys import stderr
from time import localtime
from SCRAM import FORCED_ARCH
from SCRAM.Utilities.AddDir import adddir
from SCRAM.Configuration.ConfigArea import ConfigArea

class ProjectDB(object):
    def __init__(self):
        self.scramrc = 'etc/scramrc'
        self.linkfile = 'links.db'
        self.archs = {}
        self.listcache = {}
        self.projects = {};
        self.domain = getfqdn().split('.', 1)[1];
        self.prodarch = {};
        self.project_module = None
        self._initDB()

    def getarea(self, name, version, force=False):
        arch = environ['SCRAM_ARCH']
        data = self._findProjects(name,version,True,arch)
        selarch = None
        if (arch in data) and (len(data[arch])==1): selarch = arch
        elif FORCED_ARCH == "":
            data = self.updatearchs(name, version, [arch])
            archs = list(data)
            if len(archs)==1:
                selarch=archs[0]
            elif (len(archs)>1) and (not force):
                selarch = self.productionArch(name, version, data[archs[0]][0][2])
        area = None
        self.deprecated=False
        if selarch and (selarch in data):
            if not force:
                project_module = self.getProjectModule(name)
                if project_module:
                    dep_date = project_module.getDeprecatedDate(version, selarch, data[selarch][0][2])
                    dep_int = int(dep_date)
                    if dep_int==0:
                        self.deprecated=True
                    elif dep_int > 0:
                        (year, mon, mday, hour, min, src, wday, yday, isdst) = localtime()
                        if mon<10:mon="0%s" % mon
                        if mday<10:mday="0%s" % mday
                        if int('%s%s%s' % (year,mon,mday))<dep_int:
                            self.deprecated=True
                        else:
                            dep_date = '%s/%s/%s' % (dep_date[6:8], dep_date[4:6], dep_date[0:4])
                            err = "WARNING: Release $version will be deprecated on %s.\n" % dep_date
                            err+= "         It is better to use a newer version."
                            print(err, file=stderr)
                    if self.deprecated:
                        err  = "ERROR: Project \"%s\" version \"%s\" has been deprecated.\n" % (name, version)
                        err += "       Please use a different non-deprecated release."
                        print(err, file=stderr)
                        return area
            area = self.getAreaObject(data[selarch][0], selarch)
        return area

    def productionArch(self, project, version, release):
        rel_id = '%s:%s' % (project, version)
        if rel_id in self.prodarch: return self.prodarch[rel_id]
        archs = []
        if release and exists('%s/.SCRAM/production_arch' % release):
            with open('%s/.SCRAM/production_arch' % release, 'r') as ref:
                arch = ref.readline().strip('\n')
                if arch: archs.append(arch)
        if not archs:
            project_module = self.getProjectModule(project)
            if project_module: archs = project_module.releaseArch(version, 1,
                                                                  release)
        arch = ""
        if len(archs) == 1: arch = archs[0]
        self.prodarch[rel_id] = arch
        return arch

    def getProjectModule(self, project):
        if self.project_module is not None: return self.project_module
        self.project_module = False
        try:
            if eval('import SCRAM.Plugins.%s as ProjectModule' % project.upper()):
                self.project_module = ProjectModule()
        except:
            pass
        return self.project_module

    def listlinks(self):
        links = {'local': [], 'linked': []}
        links['local'] = self.LocalLinks[:]
        for d in self.DBS['order']:
            if not d in links['local']: links['linked'].append(d)
        return links

    def listall(self, project, version, valid, all):
        oarch = environ['SCRAM_ARCH']
        xdata = self._findProjects(project, version, exact_match=False,
                                   arch=oarch, valid=valid)
        if all or ((not oarch in xdata) and (FORCED_ARCH == "")):
            for arch in self.archs:
                if arch == oarch: continue
                xdata = self._findProjects(project, version, exact_match=False,
                                           arch=arch, valid=valid, xdata=xdata)
        return xdata

    def updatearchs(self, name, version, skiparch):
        self.listcache = {}
        for arch in self.archs:
            if arch in skiparch: continue
            data = self._findProjects(name, version, exact_match=True,
                                      arch=arch)
            if (arch in data) and (len(data[arch]) == 1):
                self.lichcache[arch] = data[arch]
        return self.listcache

    def link(self, db):
        db = abspath(db.replace(' ', ''))
        if db.startswith('file:'): db = db[5:]
        if not isdir(db): return False
        if db == environ['SCRAM_LOOKUPDB']: return False
        if db in self.LocalLinks: return True
        self.LocalLinks.append(db)
        self._save()
        return True

    def unlink(self, db):
        db = abspath(db.replace(' ', ''))
        if db.startswith('file:'): db = db[5:]
        if db in self.LocalLinks:
            self.LocalLinks.remove(db)
            self._save()
        return True

    def getAreaObject(self, data, arch):
        area = ConfigArea(arch)
        loc = data[2]
        if not area.bootstrapfromlocation(loc):
            area = None
            err = "ERROR: Attempt to ressurect %s %s from $loc " \
                  "unsuccessful\n" % (data[0], data[1])
            err += "ERROR: %s does not look like a valid release area for" \
                   "SCRAM_ARCH %s." % (loc, arch)
            print(err, file=stderr)
        elif data[3]:
            area.basedir = data[3]
        return area

    def hasProject(self, project):
        return project.upper() in self.projects

    ##################################################
    def _save(self):
        filename = join(environ['SCRAM_LOOKUPDB_WRITE'], self.scramrc)
        adddir(filename)
        filename = self._getLinkDBFile(filename);
        with open(filename, 'w') as ref:
            for db in self.LocalLinks:
                if db: ref.write(db + "\n")
        chmod(filename, 644)
        return


    # FIXME mutable default parameter {}
    def _initDB(self, scramdb=None, cache={}):
        local = False
        localdb = environ['SCRAM_LOOKUPDB'];
        if not scramdb:
            scramdb = localdb
            self.DBS = {'order': [], 'uniq': {}}
            self.LocalLinks = []
            local = True

        if scramdb in self.DBS['uniq']: return
        self.DBS['uniq'][scramdb] = {}
        self.DBS['order'].append(scramdb)
        db = '%s/%s' % (scramdb, self.scramrc)
        for mapfile in glob('%s/*.map' % db):
            if not exists(mapfile): continue
            with open(mapfile, 'r') as ref:
                for line in [l.strip('\n').strip() for l in ref.readlines()]:
                    if not '=' in line: continue
                    proj, value = line.split('=', 1)
                    proj = proj.upper()
                    self.projects[proj] = 1
                    if not proj in self.DBS['uniq'][scramdb]:
                    self.DBS['uniq'][scramdb][proj] = {}
                    self.DBS['uniq'][scramdb][proj][value] = 1

        if not local:
            for proj in self.DBS['uniq'][localdb]:
                if proj in self.DBS['uniq'][scramdb]: continue
                self.DBS['uniq'][scramdb][proj] = {}
                for path in self.DBS['uniq'][localdb][proj]:
                    self.DBS['uniq'][scramdb][proj][path] = 1

        varch = '_'.join(environ['SCRAM_ARCH'].split('_', 2)[:2])
        for common in glob('%s/%s_*/cms/cms-common' % (scramdb, varch)):
            self.archs[common.replace(scramdb, '').split("/", 2)[1]] = 1
        linkdb = self._getLinkDBFile(db)
        if not exists(linkdb): return
        with open(linkdb, 'r') as ref:
            uniq = {}
            for line in [l.strip('\n').strip() for l in ref.readlines()]:
                if not line: continue
                line = abspath(line)
                if line in uniq: continue
                uniq[line] = 1
                self._initDB(line, cache)
                if localdb: self.LocalLinks.append(line)
        return

    # FIXME mutable default parameter {}
    def _findProjects(self, project='.+', version='.+', exact_match=False,
                      arch=None, valid=False, xdata={}):
        if not arch: arch = environ['SCRAM_ARCH']
        data = {}
        uniq = {}
        if not arch in self.archs: return xdata;
        xdata[arch] = []
        projRE = compile('^%s$' % project)
        verRE  = compile(version)
        for base in self.DBS['order']:
            for p in self.DBS['uniq'][base]:
                if not projRE.match(p): continue
                proj_dirs = []
                for x in self.DBS['uniq'][base][p]:
                    proj_dirs += glob(
                        '%s/%s' % (base, x.replace('$SCRAM_ARCH', arch)))
                for fd in proj_dirs:
                    if not isdir(fd): continue
                    if valid and (not exists(
                        join(fd, '.SCRAM', arch, 'timestamp',
                             'self'))): continue
                    ver = basename(fd)
                    if exact_match:
                        if ver == version:
                            xdata[arch].append([p, ver, fd, base])
                            return xdata
                    elif verRE.match(version) and (not p + ':' + ver in uniq):
                        uniq[p + ':' + ver] = 1
                        mtime = getmtime(fd)
                        if not mtime in data: data[mtime] = {}
                        if not p in data[mtime]: data[mtime][p] = {}
                        data[mtime][p][ver] = [fd, base]
        for mtime in sorted(data):
            for p in data[mtime]:
                for ver in data[mtime][p]:
                    xdata[arch].append([p, ver] + data[mtime][p][ver])
        if len(xdata[arch]) == 0: del xdata[arch]
        return xdata

    def _getLinkDBFile(self, dir):
        linkfile = join(dir, '%s-%s' % (self.domain, self.linkfile))
        if not exists(linkfile): linkfile = join(dir, self.linkfile)
        return linkfile
