from os import environ, getcwd, execv, chdir, makedirs
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
from SCRAM.BuildSystem.ToolManager import ToolManager
from SCRAM.BuildSystem.BuildFile import BuildFile
from SCRAM.BuildSystem.ToolFile import ToolFile


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
    print("%s" % environ['SCRAM_ARCH'])
    return True


def remote_versioncheck(area):
    sversion = area.scram_version()
    if not sversion:
        SCRAM.scramerror("Unable to determine SCRAM version used to config. remote area.")
    spawnversion(sversion)


def spawnversion(newversion='V2_99_99'):
    if SCRAM.VERSION.split("_", 1)[0] != newversion.split("_", 1)[0]:
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
    from SCRAM.Core.SiteConfig import SiteConfig
    conf = SiteConfig()
    if len(args) == 0:
        return conf.dump()
    key = args[0]
    value = ''
    if '=' in key:
        key, value = key.split('=', 1)
    if value:
        return conf.set(key, value)
    value = conf.get(key)
    if value is None:
        return False
    return conf.dump(key)


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


def cmd_runtime(args):
    spawnversion()
    return True


def cmd_setup(args):
    spawnversion()
    return True


def cmd_project(args):
    parser = ArgumentParser(add_help=False)
    parser.add_argument('-l', '--log',
                        dest='log',
                        action='store_true',
                        default=False,
                        help='See the detail log message while creating a dev area')
    parser.add_argument('-s', '--symlinks',
                        dest='symlinks',
                        action='store_true',
                        default=False,
                        help='Creates symlinks for various product build directories.')
    parser.add_argument('-u', '--update',
                        dest='update',
                        action='store_true',
                        default=False,
                        help='Command-line argument -u|--update is no more supported.')
    parser.add_argument('-d', '--dir',
                        dest='install_base_dir',
                        type=str,
                        default=None,
                        help='Project installation base directory.')
    parser.add_argument('-b', '--boot',
                        dest='bootstrap',
                        type=str,
                        default=None,
                        help='Creates a release area using the bootstrap file')
    parser.add_argument('-n', '--name',
                        dest='install_name',
                        type=str,
                        default=None,
                        help='Specify the name of the SCRAM-base development area directory.')
    opts, args = parser.parse_known_args(args)
    if len(args) == 0:
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    SCRAM.INTERACTIVE = True if opts.log else False

    if opts.bootstrap:
        return bootnewproject(opts, args)
    project = args[0]
    version = args[1] if len(args) > 1 else None
    releasePath = None
    if version is None:
        if isdir(project) and project.startswith('/'):
            area = ConfigArea(SCRAM.FORCED_ARCH)
            releasePath = area.searchlocation(project)
            if not releasePath:
                SCRAM.scramerror("Not a valid scram-based release area: %s" % project)
            project = basename(releasePath)
        version = project
        project = project.split('_', 1)[0]
    return project_bootfromrelease(project.upper(), version, releasePath, opts)


def project_bootfromrelease(project, version, releasePath, opts):
    installdir = opts.install_base_dir if opts.install_base_dir else getcwd()
    installname = opts.install_name if opts.install_name else version
    relarea = None
    if not (project and version):
        SCRAM.scramfatal("Insufficient arguments: see \"scram project -help\" for usage info.")
    db = ProjectDB()
    relarea = None
    if releasePath:
        relarea = db.getAreaObject([project, version, releasePath, None], SCRAM.FORCED_ARCH)
    else:
        relarea = db.getarea(project, version, force=SCRAM.COMMANDS_OPTS.force)
    xarch = environ['SCRAM_ARCH']
    if not relarea or not isdir(relarea.archdir()):
        if db.deprecated:
            return False
        archs = list(db.listcache)
        errmsg = 'ERROR: Project "%s" version "%s" is not available for arch %s.\n' % (project, version, xarch)
        if len(archs) > 1:
            errmsg += '       "%s" is currently available for following archs.\n' % (project)
            errmsg += '       Please set SCRAM_ARCH properly and re-run the command.\n    %s' % '\n    '.join(archs)
        else:
            errmsg += '       Please make sure you have used the correct name/version.\n'
            errmsg += '       You can run \"scram list $projectname\" to get the list of available versions.'
        SCRAM.printerror(errmsg)
        return False
    arch = relarea.arch()
    SCRAM.FORCED_ARCH = arch
    environ['SCRAM_ARCH'] = arch
    if isdir(join(installdir, installname, relarea.admindir(), arch)):
        SCRAM.printerror("WARNING: There already exists %s/%s area for SCRAM_ARCH %s." %
                         (installdir, installname, arch))
        return True

    # Re-run if different SCRAM version is needed to bootstrap the area.
    # remote_versioncheck(relarea)

    SCRAM.printmsg("Creating a developer area based on project %s version %s"
                   % (project, version), SCRAM.INTERACTIVE)
    environ['RELEASETOP'] = relarea.location()
    locarea = Core()
    symlink = 1 if opts.symlinks else 0
    area = relarea.satellite(installdir, installname, symlink, locarea.localarea())
    chdir(area.location())
    c = Core()
    c.init_env()
    create_productstores(c.localarea())
    if relarea.basedir:
        with open(join(area.config(), 'scram_basedir'), 'w') as ref:
            ref.write(relarea.basedir)
    XXX = """
    my $toolmanager = $self->toolmanager($area);
    $toolmanager->update ($area);

    # Write the cached info:
    $toolmanager->writecache();

        my $temp=$area->location()."/".$area->{admindir}."/".$ENV{SCRAM_ARCH};
        if (-f "${temp}/MakeData/Tools.mk")
           {
           my $t1=(stat("${temp}/MakeData/Tools.mk"))[9];
           utime $t1-1,$t1-1,"${temp}/MakeData/Tools.mk";
           if (-f "${temp}/timestamps/self")
              {
              utime $t1,$t1,"${temp}/timestamps/self";
              }
           }
"""
    SCRAM.printmsg("\n\nInstallation procedure complete.", SCRAM.INTERACTIVE)
    SCRAM.printmsg("Developer area located at:\n\n\t\t%s\n\n" % area.location(), SCRAM.INTERACTIVE)
    if xarch != arch:
        SCRAM.printmsg("WARNING: Release %s is not available for architecture %s" %
                       (version, xarch))
        SCRAM.printmsg("         Developer's area is created for available architecture %s." %
                       (arch))
    os = cmsos()
    if not arch.startswith(os):
        SCRAM.printmsg("WARNING: Developer's area is created for architecture %s while your current OS is %s." %
                       (arch, os))
    if not SCRAM.COMMANDS_OPTS.force:
        os = db.productionArch(project, version, area.location())
        if os and os != arch:
            msg = "WARNING: Developer's area is created for non-production architecture $ENV{SCRAM_ARCH}. " \
                  "Production architecture for this release is %s" % (arch, os)
            SCRAM.printmsg(msg)
    tc = db.getProjectModule(project)
    if tc:
        tc.getData(version, relarea.location())
    if 'SCRAM_IGNORE_PROJECT_HOOK' not in environ:
        proj_hook = join(area.config(), 'SCRAM', 'hooks', 'project-hook')
        if exists(proj_hook):
            SCRAM.run_command(proj_hook)
    if '/afs/cern.ch/' in environ['SCRAM_TOOL_HOME']:
        msg = "****************************** WARNING ******************************\n" \
              "You are using CMSSW from CERN AFS space. Please note that, by the start of 2017, " \
              "new CMSSW releases shall only be available via CVMFS.\n" \
              "See the announcement https://hypernews.cern.ch/HyperNews/CMS/get/swDevelopment/3374.html"
        SCRAM.printmsg(msg)
    return True


def cmsos():
    e, os = SCRAM.run_command('cmsos')
    if e:
        return None
    return '_'.join(os.split('_', 2)[:2])


def create_productstores(area):
    sym = None
    if area.symlinks() > 0:
        from SCRAM.Core.ProdSymLinks import ProdSymLinks
        sym = ProdSymLinks()
    location = area.location()
    bf = BuildFile(location)
    bf.parse(join(area.config(), 'BuildFile.xml'))
    arch = area.arch()
    for store in bf.contents['PRODUCTSTORE']:
        storename = None
        if ('type' in store) and (store['type'] == 'arch'):
            if ('swap' in store) and (store['swap'] == 'true'):
                storename = join(store['name'], arch)
            else:
                storename = join(arch, store['name'])
        else:
            storename = store['name']
        if not exists(storename):
            if not sym:
                makedirs(join(location, storename), 0o755)
            else:
                sym.mklink(location, storename)
    src = join(location, area.sourcedir())
    if not exists(src):
        makedirs(src)
    tmp = join(area.tmp(), arch)
    if not sym:
        tmp = join(location, tmp)
        if not exists(tmp):
            makedirs(tmp, 0o755)
    else:
        sym.mklink(location, tmp)
    return


def project_bootnewproject(opts, args):
    return True


def cmd_tool(args):
    area = Core()
    area.checklocal()
    if not args or args[0].lower() not in ['list', 'info', 'tag', 'remove']:
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    return eval('tool_%s' % args[0].lower())(args[1:], area.localarea())


def tool_list(args, area):
    toolmanager = ToolManager(area)
    tools = toolmanager.toolsdata()
    if not tools:
        SCRAM.scramerror(">>>> No tools set up for current arch or area! <<<<")

    msg = "Tool list for location %s" % area.location()
    msglen = len(msg)
    msg += "\n%s\n" % ("+" * len(msg))
    SCRAM.printmsg("\n%s" % msg)
    for tool in sorted(tools):
        SCRAM.printmsg(" {:40s} {:20s}".format(tool, tools[tool]['TOOLVERSION']))
    SCRAM.printmsg("")
    return True


def tool_info(args, area):
    if not args:
        SCRAM.scramfatal("No tool name given: see \"scram tool -help\" for usage info.")

    toolmanager = ToolManager(area)
    toolname = args[0].lower()
    tool = toolmanager.gettool(toolname)
    if not tool:
        SCRAM.scramerror(">>>> Tool %s is not setup for this project area. <<<<" % toolname)
    msg = "Tool info as configured in location %s" % area.location()
    msglen = len(msg)
    msg += "\n%s\n" % ("+" * len(msg))
    msg += "Name : %s\n" % toolname
    msg += "Version : %s\n" % tool['TOOLVERSION']
    msg += "%s\n" % ("+" * 20)
    SCRAM.printmsg(msg)
    tooldata = ToolFile.summarize_tool(tool)
    for tag in sorted(tooldata):
        SCRAM.printmsg('%s=%s' % (tag, tooldata[tag]))
    SCRAM.printmsg("")
    return True


def tool_tag(args, area):
    if len(args) < 1:
        SCRAM.scramfatal("No tool name given: see \"scram tool -help\" for usage info.")

    toolmanager = ToolManager(area)
    toolname = args[0].lower()
    tool = toolmanager.gettool(toolname)
    if not tool:
        SCRAM.scramerror(">>>> Tool %s is not setup for this project area. <<<<" % toolname)
    tag = None if len(args) == 1 else args[1]
    msg = ToolFile.get_feature(tool, tag)
    if msg:
        SCRAM.printmsg(msg)
    return True


def tool_remove(args, area):
    if len(args) < 1:
        SCRAM.scramfatal("No tool name given: see \"scram tool -help\" for usage info.")

    toolname = args[0].lower()
    toolmanager = ToolManager(area)
    if not toolmanager.hastool(toolname):
        SCRAM.errormsg(">>>> Tool %s is not defined for this project area. <<<<" % toolname)
    SCRAM.printmsg("Removing tool %s from current project area configuration." % toolname)
    toolmanager.remove_tool(toolname)
    return True
