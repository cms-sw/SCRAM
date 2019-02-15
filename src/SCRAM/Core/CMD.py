from os import environ, getcwd, execv
from os.path import exists, join, isdir
from sys import stderr, argv
from re import match
from argparse import ArgumentParser
try:
    from subprocess import run as run_cmd
except:
    from subprocess import call as run_cmd
import SCRAM
from SCRAM.Configuration.ConfigArea import ConfigArea
from SCRAM.Core.ProjectDB import ProjectDB


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
    execv(SCRAM.BASEPATH + "/common/scram", argv)


def cmd_unsetenv(args):
    spawnversion()
    return True


def cmd_list(args):
    parser = ArgumentParser(add_help=False)
    parser.add_argument('-A', '--all',
                        dest='all',
                        action='store_true',
                        default=False,
                        help='List all release for all available architectures.')
    parser.add_argument('-c', '--compact',
                        dest='compact',
                        action='store_true',
                        default=False,
                        help='Show compact results.')
    parser.add_argument('-e', '--exists',
                        dest='exists',
                        action='store_true',
                        default=False,
                        help='Show only valid projects.')
    opts, args = parser.parse_known_args(args)
    db = ProjectDB()
    project = args[0] if len(args) > 0 else ''
    version = args[1] if len(args) > 1 else ''
    if version == '':
        version = project
        project = project.split('_', 1)[0]
        if not db.hasProject(project):
            project = ''
    projects = db.listall(project.upper(), version, opts.exists, opts.all)
    if not projects:
        msg = ""
        if not SCRAM.FORCED_ARCH:
            msg = " for architecture %s" % environ['SCRAM_ARCH']
        if not version:
            SCRAM.scramwarning(">>>> No SCRAM project %s version %s available%s. <<<<" % (project, version, msg))
            SCRAM.printrror("You can run \"scram list %s\" to see the available versions." % project)
        elif project:
            SCRAM.scramwarning(">>>> No SCRAM project %s available%s. <<<<" % (project, msg))
            SCRAM.printrror("You can run \"scram list\" to see the available projects and their versions.")
        else:
            SCRAM.scramwarning(">>>> There are no SCRAM project yet installed%s. <<<<" % msg)
        return False
    headstring = "| {:12s}  | {:24s} | {:33} |".format("Project Name", "Project Version", "Project Location")
    for arch in projects:
        if not opts.compact:
            print("\nListing installed projects available for platform >> %s\n" % arch)
            print(headstring)
        for item in projects[arch]:
            pstring = ""
            if opts.compact:
                pstring = "{:15s} {:25s} {:50s}".format(item[0], item[1], item[2])
            else:
                pstring = "  {:15s} {:25s}  \n{:41s}--> {:30s}".format(item[0], item[1], "", item[2])
            print(pstring)
    return True


def cmd_build(args):
    spawnversion()
    return True


def cmd_config(args):
    spawnversion()
    return True


def cmd_db(args):
    parser = ArgumentParser(add_help=False)
    parser.add_argument('-s', '--show',
                        dest='show',
                        action='store_true',
                        default=False,
                        help='Show all the external databases linked in to your SCRAM db')
    parser.add_argument('-l', '--link',
                        dest='link',
                        type=str,
                        default=None,
                        help='Link/Add an external scram db <path> in to local scram db.')
    parser.add_argument('-u', '--unlink',
                        dest='unlink',
                        type=str,
                        default=None,
                        help='Unlink/Remove an already linked external db <path> from the local scram db.')
    opts, args = parser.parse_known_args(args)
    db = ProjectDB()
    if opts.link:
        environ['SCRAM_LOOKUPDB'] = environ['SCRAM_LOOKUPDB_WRITE']
        if isdir(opts.link):
            if not db.link(opts.link):
                SCRAM.scramerror("Can not link to SCRAM-DB. No such directory: %s" % opts.link)
            else:
                SCRAM.printmsg("Current SCRAM database: %s" % environ['SCRAM_LOOKUPDB'])
                SCRAM.printmsg("Linked \"%s\" to current SCRAM database." % opts.link)
    elif opts.unlink:
        environ['SCRAM_LOOKUPDB'] = environ['SCRAM_LOOKUPDB_WRITE']
        if db.unlink(opts.unlink):
            SCRAM.printmsg("Current SCRAM database: %s" % environ['SCRAM_LOOKUPDB'])
            SCRAM.printmsg("Unlinked \"%s\" from current SCRAM database." % opts.unlink)
    else:
        SCRAM.printmsg("Current SCRAM database: %s" % environ['SCRAM_LOOKUPDB'])
        links = db.listlinks()
        flag = False
        for db_type in ["local", "linked"]:
            if db_type not in links or not links[db_type]:
                continue
            flag = True
            msg = "The following SCRAM databases are linked "
            if 'local' == db_type:
                msg += "directly:"
            else:
                msg += "in-directly:"
            SCRAM.printmsg(msg)
            for extdb in links[db_type]:
                SCRAM.printmsg("\t%s" % extdb)
            SCRAM.printmsg("")
        if not flag:
            SCRAM.printmsg("There are no SCRAM databases linked.")
    return True


def cmd_project(args):
    db = ProjectDB()
    db.getarea('CMSSW', 'CMSSW_10_5_0_pre1')
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
