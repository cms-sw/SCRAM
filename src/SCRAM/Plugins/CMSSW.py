from SCRAM import INTERACTIVE, SCRAM_VERSION
from sys import stderr
from os import environ
from re import match
from SCRAM.Core.SiteConfig import SiteConfig
from subprocess import getstatusoutput as run_cmd


class CMSSW(object):
    def __init__(self):
        self.data = None
        if not INTERACTIVE:
            warn = "WARNING: In non-interactive mode release checks e.g. " \
                   "deprecated releases, production architectures are " \
                   "disabled."
            print(warn, file=stderr)
            self.data = []
        return

    def releaseArchs(self, version, default, reldir):
        prod = ';prodarch='
        if default:
            prod = ';prodarch=1;'
        data = self.getData(version, reldir)
        archs = []
        xarch = None
        for line in data:
            if prod not in line:
                continue
            items = dict(t.split('=', 1) for t in line.split(';') if '=' in t)
            if 'architecture' not in items:
                continue
            arch = items['architecture']
            if ('state' in items) and (items['state'] == 'IB'):
                if xarch:
                    continue
                if 'label' in items:
                    if (version == items['label']):
                        xarch = arch
            else:
                archs.append(arch)
        if (len(archs) == 0) and xarch:
            archs.append(xarch)
        return archs

    def getData(self, version, reldir):
        if self.data is None:
            self.data = []
            siteconf = SiteConfig()
            if siteconf.get("release-checks") in ["1", "y", "yes"]:
                url = "https://cmssdt.cern.ch/SDT/releases.map?release=%s&" \
                      "architecture=%s&scram=%s&releasetop=%s" \
                      % (version, environ['SCRAM_ARCH'],
                         SCRAM_VERSION, reldir)
                cmd = 'wget  --no-check-certificate -nv -o /dev/null -O- '
                e, out = run_cmd('which wget')
                if e:
                    cmd = 'curl -L -k --stderr /dev/null'
                cmd = '%s "%s"' % (cmd, url)
                cmd = 'cat /afs/cern.ch/user/m/muzaffar/public/git/cms-bot/releases.map'
                maxwait = siteconf.get("release-checks-timeout")
                e, out = run_cmd('timeout %s %s |  grep ";label=%s;\|;state=IB;"' % (maxwait, cmd, version))
                if e:
                    return self.data
                for line in out.split('\n'):
                    self.data.append(line)
        return self.data

    def getDeprecatedDate(self, version, arch, reldir):
        data = self.getData(version, reldir)
        for line in data:
            items = dict(t.split('=', 1) for t in line.split(';') if '=' in t)
            if ('label' not in items) or (items['label'] != version):
                continue
            if ('architecture' not in items) or (items['architecture'] != arch):
                continue
            if ('state' in items) and (items['state'] == 'Deprecated'):
                return 0
            if ('deprecate_date' in items) and match('^\d{8}$', items['deprecate_date']):
                return items['deprecate_date']
        return -1
