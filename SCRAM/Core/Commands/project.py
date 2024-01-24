import SCRAM
from SCRAM.BuildSystem.ToolManager import ToolManager
from SCRAM.Core.Core import Core
from SCRAM.Core.Utils import create_productstores, cmsos, remote_versioncheck
from argparse import ArgumentParser
from os.path import exists, join, isdir, basename
from os import environ, getcwd, chdir
import re

SCRAM_OS_MAP = [['cs', 'cc', 'alma','rhel', 'rocky', 'el']]

def checkScramOSCompatibility(os1, os2):
  os1 = re.sub('[0-9]*$', '', os1.split('_')[0])
  for item in SCRAM_OS_MAP:
    if os1 in item:
      return re.sub('[0-9]*$', '', os2.split('_')[0]) in item
  return False

def process(args):
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
    SCRAM.INTERACTIVE = True if opts.log else False

    if opts.bootstrap:
        return project_bootnewproject(opts, args)
    if len(args) == 0:
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    project = args[0]
    version = args[1] if len(args) > 1 else None
    releasePath = None
    if version is None:
        if isdir(project) and project.startswith('/'):
            from SCRAM.Configuration.ConfigArea import ConfigArea
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
    from SCRAM.Core.ProjectDB import ProjectDB
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
    remote_versioncheck(relarea)

    SCRAM.printmsg("Creating a developer area based on project %s version %s"
                   % (project, version), SCRAM.INTERACTIVE)
    environ['RELEASETOP'] = relarea.location()
    symlink = 1 if opts.symlinks else 0
    area = relarea.satellite(installdir, installname, symlink, Core().localarea())
    chdir(area.location())
    area = Core()
    area.init_env()
    localarea = area.localarea()
    create_productstores(localarea)
    if relarea.basedir:
        with open(join(localarea.config(), 'scram_basedir'), 'w') as ref:
            ref.write(relarea.basedir)
    toolmanager = ToolManager(localarea)
    toolmanager.setupself(dump=False, force_save=True)
    if not exists(localarea.toolcachename()):
        toolmanager.setupalltools(dump=False)
    SCRAM.printmsg("\n\nInstallation procedure complete.", SCRAM.INTERACTIVE)
    SCRAM.printmsg("Developer area located at:\n\n\t\t%s\n\n" % localarea.location(), SCRAM.INTERACTIVE)
    if xarch != arch:
        SCRAM.printmsg("WARNING: Release %s is not available for architecture %s" %
                       (version, xarch))
        SCRAM.printmsg("         Developer's area is created for available architecture %s." %
                       (arch))
    os = cmsos()
    if not arch.startswith(os) and not checkScramOSCompatibility(os, arch):
        SCRAM.printmsg("WARNING: Developer's area is created for architecture %s while your current OS is %s." %
                       (arch, os))
    if not SCRAM.COMMANDS_OPTS.force:
        os = db.productionArch(project, version, relarea.location())
        if os and os != arch:
            msg = "WARNING: Developer's area is created for non-production architecture %s. " \
                  "Production architecture for this release is %s" % (arch, os)
            SCRAM.printmsg(msg)
    tc = db.getProjectModule(project)
    if tc:
        tc.getData(version, relarea.location())
    if 'SCRAM_IGNORE_PROJECT_HOOK' not in environ:
        hook_dir = join(localarea.config(), 'SCRAM', 'hooks')
        proj_hook = join(hook_dir, 'project-hook')
        if exists(proj_hook):
            SCRAM.run_command(proj_hook)
        if 'SCRAM_IGNORE_SITE_PROJECT_HOOK' not in environ:
            proj_hook = join(SCRAM.get_site_hooks(), 'SCRAM', 'hooks', 'project-hook')
            if exists(proj_hook):
                ignore_hooks_file = join(hook_dir, 'ignore-site-hooks')
                if not exists(ignore_hooks_file):
                    ignore_hooks_file=""
                err, out = SCRAM.run_command("SCRAM_IGNORE_HOOKS=%s %s" % (ignore_hooks_file, proj_hook))
                if out:
                    SCRAM.printmsg(out)
    if '/afs/cern.ch/' in environ['SCRAM_TOOL_HOME']:
        msg = "****************************** WARNING ******************************\n" \
              "You are using CMSSW from CERN AFS space. Please note that, by the start of 2017, " \
              "new CMSSW releases shall only be available via CVMFS.\n" \
              "See the announcement https://hypernews.cern.ch/HyperNews/CMS/get/swDevelopment/3374.html"
        SCRAM.printmsg(msg)
    return True


def project_bootnewproject(opts, args):
    if len(args) != 0:
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    from SCRAM.Configuration.BootStrapProject import BootStrapProject
    bootstrapfile = opts.bootstrap
    if opts.install_base_dir is None:
        opts.install_base_dir = getcwd()
    installarea = opts.install_base_dir
    bs = BootStrapProject(installarea)
    area = bs.boot(bootstrapfile)
    chdir(area.location())
    c = Core()
    c.init_env()
    area = c.localarea()
    toolmanager = ToolManager(area)
    create_productstores(area)
    toolmanager.setupself(dump=False, dev_area=False)
    toolmanager.setupalltools(dump=False, )
    toolmanager.setupself(dump=False, dev_area=False)
    return True
