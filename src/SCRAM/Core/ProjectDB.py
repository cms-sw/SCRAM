import re

from __main__ import FORCED_ARCH  # FIXME
from socket import getfqdn
from glob import glob
from os.path import exists, join, abspath, isdir, getmtime, basename
from os import environ, chmod
from re import compile
from sys import stderr
from ..Utilities.AddDir import adddir


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

    to_rename = """
sub getarea ()
{
  my $self=shift;
  my $name=shift;
  my $version=shift;
  my $force=shift;
  my $arch = $ENV{SCRAM_ARCH};
  my $data = $self->_findProjects($name,$version,1,$arch);
  my $selarch=undef;
  delete $self->{deprecated};
  if ((exists $data->{$arch}) && (scalar(@{$data->{$arch}}) == 1)) { 
  $selarch=$arch;}
  elsif ($main::FORCE_SCRAM_ARCH eq "")
  {
    $data = $self->updatearchs($name,$version,{$arch});
    my @archs = keys %{$data};
    if (scalar(@archs)==1){$selarch=$archs[0];}
    elsif((scalar(@archs)>1) && (!$force)){$selarch=$self->productionArch(
    $name,$version,$data->{$archs[0]}[0][2]);}
  }
  my $area=undef;
  if ((defined $selarch) and (exists $data->{$selarch}))
  {
    if (!$force)
    {
      my $tc = $self->getProjectModule($name);
      if (defined $tc)
      {
        $self->{deprecated}=int($tc->getDeprecatedDate($version,$selarch,
        $data->{$selarch}[0][2]));
        my $dep=$self->{deprecated};
        if ($dep>0)
        {
          my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = 
          localtime();
          $mon+=1;
          $year+=1900;
          if ($mon<10){$mon="0${mon}";}
          if ($mday<10){$mday="0${mday}";}
          if (($dep-int("${year}${mon}${mday}"))<=0){$self->{deprecated}=0;}
          else
          {
            $dep=~/^(\d\d\d\d)(\d\d)(\d\d)$/o;
            print STDERR "WARNING: Release $version will be deprecated on ${
            3}/${2}/${1}.\n",
                         "         It is better to use a newer version.\n";
          }
        }
        if ($self->{deprecated}==0)
        {
          print STDERR "ERROR: Project \"$name\" version \"$version\" has 
          been deprecated.\n",
                       "       Please use a different non-deprecated 
                       release.\n";
          return $area;
        }
      }
    }
    $area=$self->getAreaObject($data->{$selarch}[0], $selarch);
  }
  return $area;
}
"""

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
        if eval('import SCRAM.Plugins.%s as ProjectModule' % project.upper()):
            self.project_module = ProjectModule()
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
        # FIXME:
        area = Configuration.ConfigArea(arch)
        loc = data[2]
        if not area.bootstrapfromlocation(loc):
            area = None
            err = "ERROR: Attempt to ressurect %s %s from $loc " \
                  "unsuccessful\n" \
                  % (data[0], data[1])
            err += "ERROR: %s does not look like a valid release area for " \
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

    def _findProjects(self, project='.+', version='.+', exact_match=False,
                      arch=None, valid=False, xdata={}):
        if not arch: arch = environ['SCRAM_ARCH']
        data = {}
        uniq = {}
        if not arch in self.archs: return xdata;
        xdata[arch] = []
        projRE = re.compile('^%s$' % project)
        verRE = re.compile(version)
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
