import SCRAM
from SCRAM.BuildSystem.ToolManager import ToolManager
from SCRAM.Core.Core import Core
from SCRAM.Core.Utils import create_productstores
from argparse import ArgumentParser
from os.path import exists, join, abspath, isdir
from os import environ


def process(args):
    parser = ArgumentParser(add_help=False)
    parser.add_argument('-i', '--interactive',
                        dest='interactive',
                        action='store_true',
                        default=False,
                        help='Obsolete command-line argument')
    opts, args = parser.parse_known_args(args)
    if len(args) > 1:
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    area = Core()
    area.checklocal()
    area.init_env()
    larea = area.localarea()
    toolmanager = ToolManager(larea)
    tool = ''
    if args:
        tool = args[0]
    if tool:
        if (not exists(tool)) or (not tool.endswith(".xml")):
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
    selfdata = toolmanager.gettool("self")
    if (not selfdata) or (tool == "self"):
        create_productstores(toolmanager.area)
        toolmanager.setupself()
        selfdata = toolmanager.gettool("self")
    if ('FLAGS' in selfdata) and \
       ('DEFAULT_COMPILER' in selfdata['FLAGS']):
        environ['DEFAULT_COMPILER'] = selfdata['FLAGS']['DEFAULT_COMPILER'][0]
    if tool:
        if tool != 'self':
            toolmanager.coresetup(tool)
    else:
        SCRAM.printmsg("Setting up all tools in current area")
        if not isdir(larea.toolcachename()):
            create_productstores(larea)
            toolmanager.setupself()
        toolmanager.setupalltools()
    if toolmanager.tools_updated:
        SCRAM.run_command("%s build ExternalLinks" % environ["SCRAM"])
    return True
