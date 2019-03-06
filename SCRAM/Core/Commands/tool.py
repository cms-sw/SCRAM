import SCRAM
from SCRAM.BuildSystem.ToolManager import ToolManager
from operator import itemgetter


def process(args, area):
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
    for tool in sorted(tools, key=itemgetter('TOOLNAME')):
        SCRAM.printmsg(" {:40s} {:20s}".format(tool['TOOLNAME'], tool['TOOLVERSION']))
    SCRAM.printmsg("")
    return True


def tool_info(args, area):
    if not args:
        SCRAM.scramfatal("No tool name given: see \"scram tool -help\" for usage info.")

    from SCRAM.BuildSystem.ToolFile import ToolFile
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
