from glob import glob
from json import load
from os.path import basename, exists, join
from os import remove
from shutil import copy2
from SCRAM import run_command


class ToolManager(object):
    def __init__(self, area):
        self.area = area
        self.tools = {}
        return

    def toolsdata(self):
        if not self.tools:
            for tool in glob(join(self.area.archdir(), 'tools', '*.json')):
                toolname = basename(tool)[:-5]
                with open(tool) as ref:
                    self.tools[toolname] = load(ref)
        return self.tools

    def gettool(self, tool):
        tooldata = {}
        if tool in self.tools:
            tooldata = self.tools[tool]
        else:
            toolfile = self.tool_json_path(tool)
            if exists(toolfile):
                with open(toolfile) as ref:
                    tooldata = load(ref)
        return tooldata

    def hastool(self, tool):
        return exists(self.tool_json_path(tool))

    def tool_json_path(self, toolname):
        return join(self.area.archdir(), 'tools', toolname.lower() + '.json')

    def remove_tool(self, tool):
        tool = tool.lower()
        json = self.tool_json_path(tool)
        remove(json)
        toolbox = self.area.toolbox()
        select = join(toolbox, 'selected', '%s.xml' % tool)
        avail = join(toolbox, 'available', '%s.xml' % tool)
        if not exists(avail) and exists(select):
            copy2(select, avail)
        remove(select)
        self.update_external_files()
        return

    def update_external_files(self):
        linkexternal = join(self.area.config(), 'SCRAM', 'linkexternal.py')
        if exists(linkexternal):
            run_command('%s --arch %s' % (linkexternal, self.area.arch()), fail_on_error=True)
