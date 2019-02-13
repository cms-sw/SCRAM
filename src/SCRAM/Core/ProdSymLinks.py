from os import environ
import re
from os.path import dirname
"""
This class is supposed to make symlinks from your home directory (ex. /afs) to
a faster directory ( local /tmp). 
"""


class ProdSymLinks():

    def __init__(self):
        self.symlinks = {}
        self.readlinks()
        pass

    def readlinks(self):
        """
        Will read 'symlink' file from home directory, parse it and expand it.
        Will store results in self.symlink for later use.
        :return:
        """
        file = environ["HOME"] + "/.scramrc/symlinks"
        with open(file) as f_in:
            for line in f_in.readlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                print(line)
                link, path, _ = line.split(":", 2)
                link = dirname(link)
                regex = re.compile("^(.*)\$\((.+?)\)(.*)$")
                m = regex.match(link)
                while m:
                    print(m.groups())
                    link = m.group(1) + environ[m.group(2)] + m.group(3)
                    m = regex.match(link)
                self.symlinks[link] = path
                print(link)
        return

    def mklink(self, store):
        permissions = 755
        link = store
        """
        my $link=$store;
        $link=~s/^(.*?)\/.*$/$1/;
        use File::Path;
        if (!-e "$ENV{LOCALTOP}/${link}")
        {
            unlink "$ENV{LOCALTOP}/${link}";
            if (exists $self->{symlinks}{$link})
            {
                my $path=$self->{symlinks}{$link};
                while($path=~/^(.*)\$\((.+?)\)(.*)$/){$path="$1$ENV{$2}$3";}
                mkpath($path,0,$prems);
                $path = File::Temp::tempdir ( "${link}.XXXXXXXX", DIR => $path);
                if (($path ne "") && (-d $path))
                {symlink($path,"$ENV{LOCALTOP}/${link}");}
            }
        }
        mkpath("$ENV{LOCALTOP}/${store}",0,$prems);
        """

        return  # TODO
