from os import environ, execv
from os.path import exists, join, isdir
from sys import stderr, argv
from re import match
from argparse import ArgumentParser
import SCRAM
from SCRAM.Core.Core import Core
from SCRAM.Core.Utils import create_productstores, spawnversion


def cmd_version(args):
    print("%s" % SCRAM.VERSION)
    return True


def cmd_help(args):
    SCRAM.run_command('man scram')
    return True


def cmd_arch(args):
    c = Core()
    print("%s" % environ['SCRAM_ARCH'])
    return True


def cmd_list(args):
    from SCRAM.Core.ProjectDB import ProjectDB
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
            SCRAM.printerror("You can run \"scram list %s\" to see the available versions." % project)
        elif project:
            SCRAM.scramwarning(">>>> No SCRAM project %s available%s. <<<<" % (project, msg))
            SCRAM.printerror("You can run \"scram list\" to see the available projects and their versions.")
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
    from SCRAM.Core.ProjectDB import ProjectDB
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


def cmd_unsetenv(args):
    from SCRAM.Core.RuntimeEnv import RUNTIME_SHELLS, RuntimeEnv
    if (len(args) != 1) or (args[0] not in RUNTIME_SHELLS):
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    rt = RuntimeEnv(area=None)
    rt.unsetenv(RUNTIME_SHELLS[args[0]])
    return True


def cmd_runtime(args):
    from SCRAM.Core.RuntimeEnv import RUNTIME_SHELLS, RuntimeEnv
    if (len(args) == 0) or (args[0] not in RUNTIME_SHELLS):
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    area = Core()
    area.checklocal()
    area.init_env()
    rt = RuntimeEnv(area.localarea())
    rt.optional_env(args[1:])
    rt.save(RUNTIME_SHELLS[args[0]])
    rt.setenv(RUNTIME_SHELLS[args[0]])
    return True


def _init_self_env(toolmanager, tool):
    selfdata = toolmanager.gettool("self")
    if (not selfdata) or (tool == "self"):
        create_productstores(toolmanager.area)
        toolmanager.setupself()
        selfdata = toolmanager.gettool("self")
    if ('FLAGS' in selfdata) and \
       ('DEFAULT_COMPILER' in selfdata['FLAGS']):
        environ['DEFAULT_COMPILER'] = selfdata['FLAGS']['DEFAULT_COMPILER'][0]


def cmd_setup(args):
    parser = ArgumentParser(add_help=False)
    parser.add_argument('-i', '--interactive',
                        dest='interactive',
                        action='store_true',
                        default=False,
                        help='Obsolete command-line argument')
    opts, args = parser.parse_known_args(args)
    if len(args) > 1:
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    from SCRAM.BuildSystem.ToolManager import ToolManager
    area = Core()
    area.checklocal()
    area.init_env()
    larea = area.localarea()
    toolmanager = ToolManager(larea)
    tool = ''
    if args:
        tool = args[0]
    if tool:
        if not exists(tool):
            toolname = tool.lower()
            if toolname != 'self':
                toolbox = larea.toolbox()
                tool = join(toolbox, 'selected', '%s.xml' % toolname)
                if not exists(tool):
                    tool = join(toolbox, 'available', '%s.xml' % toolname)
                    if not exists(tool):
                        SCRAM.scramfatal('Can not setup tool "%s" because of missing "%s.xml" '
                                         'file under %s directory."' % (toolname, toolname, toolbox))
            else:
                tool = toolname
        else:
            tool = abspath(tool)
    toolmanager = ToolManager(larea)
    _init_self_env(toolmanager, tool)
    if tool:
        if tool != 'self':
            toolmanager.coresetup(tool)
    else:
        SCRAM.printmsg("Setting up all tools in current area")
        if not isdir(larea.toolcachename()):
            create_productstores(larea)
            toolmanager.setupself()
        toolmanager.setupalltools()
    return True


def cmd_project(args):
    from SCRAM.Core.CMD_project import cmd_project as run_project_cmd
    run_project_cmd(args)


def cmd_tool(args):
    from SCRAM.Core.CMD_tool import cmd_tool as run_tool_cmd
    run_tool_cmd(args, Core())
