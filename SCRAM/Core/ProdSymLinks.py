from os import environ, unlink, makedirs, symlink
from os.path import dirname, exists, isdir, join
import re
import tempfile

"""
This class is supposed to make symlinks from your home directory (ex. /afs) to
a faster directory ( local /tmp).
"""
regex = re.compile('^(.*)\$\((.+?)\)(.*)$')


class ProdSymLinks():

    def __init__(self):
        self.symlinks = {}
        self.readlinks()

    def readlinks(self):
        """
        Will read 'symlink' file from home directory, parse it and expand it.
        Will store results in self.symlink for later use.
        """
        file = join(environ["HOME"], ".scramrc", "symlinks")
        with open(file) as f_in:
            for line in f_in.readlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                items = line.split(":")
                link = dirname(items[0])
                if not link:
                    link = items[0]
                m = regex.match(link)
                while m:
                    link = m.group(1) + environ[m.group(2)] + m.group(3)
                    m = regex.match(link)
                self.symlinks[link] = items[1]
        return

    def mklink(self, localtop, store):
        link = dirname(store)
        path_to_check = join(localtop, link)
        if not exists(path_to_check):
            try:
                unlink(path_to_check)
            except:
                pass
            if link in self.symlinks:
                path = self.symlinks[link]
                m = regex.match(path)
                while m:
                    path = m.group(1) + environ[m.group(2)] + m.group(3)
                    m = regex.match(path)
                makedirs(path, 0o755, True)
                path = tempfile.mkdtemp(prefix=link + '.', dir=path)
                if path and isdir(path):
                    symlink(path, path_to_check)
        makedirs(join(localtop, store), 0o755)
        return
