from sys import stderr
from os.path import join, exists
from re import match
from os import environ


class SiteConfig(object):
    def __init__(self):
        self.siteconf = 'etc/scramrc/site.cfg'
        self.site = {'release-checks': {}, 'release-checks-timeout': {}}
        self.site['release-checks']['value'] = "1"
        self.site['release-checks']['valid_values'] = '0|1|yes|no'
        self.site['release-checks']['help'] = "Enable/disable release checks e.g. " \
                                              "production architectures, deprecated releases. This avoids " \
                                              "accessing releases information from internet."
        self.site['release-checks-timeout']['value'] = "10"
        self.site['release-checks-timeout']['valid_values'] = '[3-9]|[1-9][0-9]+'
        self.site['release-checks-timeout']['help'] = "Time in seconds after which " \
                                                      "a request to get release information should be timed out " \
                                                      "(min. value 3s)."
        self.readSiteConfig()
        return

    def readSiteConfig(self):
        conf = join(environ['SCRAM_LOOKUPDB'], self.siteconf)
        if not exists(conf):
            return
        with open(conf, 'r') as ref:
            for line in [l.strip('\n').strip() for l in ref.readlines() if '=' in l]:
                if line.startswith('#'):
                    continue
                data = [x.strip() for x in line.split('=', 1)]
                if not data[0] in self.site:
                    self.site[data[0]] = {}
                self.site[data[0]]['value'] = data[1]
        return

    def dump(self, key=""):
        data = []
        if key and (key in self.site) and ('valid_values' in self.site[key]):
            data.append(key)
        else:
            data = sorted(list(self.site))
            print("Following SCRAM site configuration parameters are available:")
        for key in data:
            if 'valid_values' in self.site[key]:
                print("  Name        : %s" % key)
                print("  Value       : %s" % self.site[key]['value'])
                print("  Valid values: %s" % self.site[key]['valid_values'])
                print("  Purpose     : %s\n" % self.site[key]['help'])
        return True

    def get(self, key):
        if (key not in self.site) or ('valid_values' not in self.site[key]):
            print("ERROR: Unknown site configuration parameter '%s'. "
                  "Known parameters are" % key, file=stderr)
            for key in self.site:
                if 'valid_values' not in self.site[key]:
                    continue
                print("  * %s" % key, file=stderr)
            return None
        return self.site[key]['value']

    def set(self, key, value):
        cvalue = self.get(key)
        if cvalue is None:
            return False
        valid_value = self.site[key]['valid_values']
        if not match('^%s$' % valid_value, value):
            print("ERROR: Invalid value '%s' provided. Valid value for %s "
                  "should match '%s'" % (value, key, valid_value), file=stderr)
            return False
        print('%s=%s' % (key, value))
        if cvalue == value:
            return True
        self.site[key]['value'] = value
        conf = join(environ['SCRAM_LOOKUPDB'], self.siteconf)
        with open(conf, 'w') as ref:
            for key in self.site:
                ref.write('%s=%s\n' % (key, self.site[key]['value']))
        return True
