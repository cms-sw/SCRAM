from glob import glob
from json import load, loads, dumps
from os.path import basename, exists, join, isdir, dirname, abspath
from os import remove, stat, utime, environ, makedirs
from shutil import copy2, move
from SCRAM import run_command, printerror, scramerror, printmsg
from SCRAM.Configuration.ConfigArea import ConfigArea
from SCRAM.BuildSystem.ToolFile import ToolFile


def isnewer(srcfile, desfile):
    return not exists(desfile) or \
        stat(desfile).st_mtime < stat(srcfile).st_mtime


class ToolManager(object):
    def __init__(self, area):
        self.path_variables = ['PATH', 'LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH',
                               'DYLD_FALLBACK_LIBRARY_PATH', 'PYTHONPATH',
                               'PYTHON27PATH', 'PYTHON3PATH']
        self.area = area
        self.tools = {}
        self.loaded = False
        self.xml = None
        return

    def init_path_variables(self):
        self_tool = self.gettool('self')
        if not self_tool:
            return
        if 'FLAGS' in self_tool:
            if 'REM_PATH_VARIABLES' in self_tool['FLAGS']:
                for v in self_tool['FLAGS']['REM_PATH_VARIABLES']:
                    if v in self.path_variables:
                        self.path_variables.remove(v)
            if 'PATH_VARIABLES' in self_tool['FLAGS']:
                for v in self_tool['FLAGS']['PATH_VARIABLES']:
                    if v not in self.path_variables:
                        self.path_variables.append(v)
        return

    def setupself(self, dump=True, dev_area=True):
        selftool = join(self.area.config(), 'Self.xml')
        if not exists(selftool):
            printerror("\nSCRAM: No file config/Self.xml...nothing to do.")
            return False
        if not self.xml:
            self.xml = ToolFile()
        if not self.xml.parse(selftool, self.path_variables):
            scramerror("Failed to setup 'self' tool")
        if dev_area and ('RELEASETOP' in environ) and exists(environ['RELEASETOP']):
            self.addrelease()
        self.tools['self'] = self.xml.contents
        self.init_path_variables()
        tooljson = self.tool_json_path('self')
        if not isnewer(selftool, tooljson):
            return
        self._update_json(tooljson, dump)
        return

    def setupalltools(self, dump=True):
        for toolfile in glob(join(self.area.toolbox(), 'selected', '*.xml')):
            self.coresetup(toolfile, dump)

    def coresetup(self, toolfile, dump=True):
        tname = basename(toolfile)[:-4].lower()
        toolfile = abspath(toolfile)
        if not self.xml:
            self.xml = ToolFile()
        if not self.xml.parse(toolfile, self.path_variables):
            scramerror("Failed to setup '%s' tool" % tname)
        toolname = self.xml.contents['TOOLNAME'].lower()
        if tname != tname:
            scramerror("Tool name '%s' does not match the file name '%s.xml'" % (toolname, tname))
        self.tools[toolname] = self.xml.contents
        selected = join(self.area.toolbox(), 'selected', '%s.xml' % toolname)
        tooljson = self.tool_json_path(toolname)
        if selected != toolfile:
            if dirname(selected) == dirname(toolfile):
                move(toolfile, selected)
            else:
                copy2(toolfile, selected)
        elif not isnewer(selected, tooljson):
            return
        self._update_json(tooljson, dump)
        return

    def _update_json(self, tooljson, dump=True):
        if exists(tooljson):
            old_contents = load(open(tooljson))
            if old_contents == loads(dumps(self.xml.contents)):
                utime(tooljson, None)
                return False
        if not exists(self.area.toolcachename()):
            makedirs(self.area.toolcachename(), mode=0o755, exist_ok=True)
        self.xml.save_json(tooljson)
        utime(self.area.toolcachename(), None)
        tname = basename(tooljson)
        if tname != "self":
            instDir = join(dirname(dirname(tooljson)), "InstalledTools")
            if not exists(instDir):
                makedirs(instDir, exist_ok=True)
            instTool = join(instDir, tname)
            with open(instTool, "w"):
                pass
        if not dump:
            return True
        printmsg("\n%s\n" % ("+" * 40))
        if self.xml.warnings:
            printmsg('%s' % '\n'.join(self.xml.warnings))
        printmsg("Name : %s" % self.xml.contents['TOOLNAME'])
        printmsg("Version : %s" % self.xml.contents['TOOLVERSION'])
        tooldata = ToolFile.summarize_tool(self.xml.contents)
        for tag in sorted(tooldata):
            printmsg('%s=%s' % (tag, tooldata[tag]))
        return True

    def loadtools(self):
        if not self.loaded:
            for tool in glob(join(self.area.toolcachename(), '*')):
                toolname = basename(tool)
                with open(tool) as ref:
                    self.tools[toolname] = load(ref)
            self.loaded = True
        return self.tools

    def toolsdata(self):
        tooldata = []
        cache = {'donetools': {}, 'scram_tools': {}}
        self.loadtools()
        for tool in sorted(list(self.tools)):
            if 'SCRAM_PROJECT' in tool:
                cache['scram_tools'][tool] = 1
            elif tool != 'self':
                self._toolsdata(tool, tooldata, cache)
        for tool in cache['scram_tools']:
            self._toolsdata_scram(tool, tooldata, cache)
        data = []
        for d in tooldata:
            data += d
        return data

    def _toolsdata(self, tool, data, cache):
        order = -1
        if tool in cache['donetools']:
            return cache['donetools'][tool]
        cache['donetools'][tool] = order
        if tool not in self.tools:
            return order
        td = self.tools[tool]
        if 'USE' in td:
            for use in td['USE']:
                o = self._toolsdata(use.lower(), data, cache)
                if o > order:
                    order = o
        order += 1
        while len(data) <= order:
            data.append([])
        td['ORDER'] = order
        data[order].append(td)
        cache['donetools'][tool] = order
        return order

    def _toolsdata_scram(self, tool, data, cache):
        order = -1
        if tool in cache['donetools']:
            return cache['donetools'][tool]
        cache['donetools'][tool] = order
        if tool not in cache['scram_tools']:
            return order
        base_dir = self.tools[tool]['%s_BASE' % tool.upper()]
        if not isdir(base_dir):
            printerror('ERROR: Release area "%s" for "%s" is not available.' %
                       (base_dir, tool))
            return order
        area = ConfigArea()
        area.location(base_dir)
        tm = ToolManager(area)
        tools = tm.loadtools()
        order = len(tools)
        for xtool in tools:
            if 'SCRAM_PROJECT' in xtool:
                o = self._toolsdata_scram(xtool, data, cache)
                if o > order:
                    order = o
        order += 1
        while len(data) <= order:
            data.append([])
        self.tools[tool]['ORDER'] = order
        data[order].append(self.tools[tool])
        cache['donetools'][tool] = order
        return order

    def gettool(self, tool):
        if tool not in self.tools:
            toolfile = self.tool_json_path(tool)
            if exists(toolfile):
                with open(toolfile) as ref:
                    self.tools[tool] = load(ref)
            else:
                self.tools[tool] = {}
        return self.tools[tool]

    def hastool(self, tool):
        return exists(self.tool_json_path(tool))

    def tool_json_path(self, toolname):
        return join(self.area.toolcachename(), toolname.lower())

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

    def _getreleasedata(self, localpath, ltop, rtop):
        if not localpath.startswith(ltop):
            return ""
        relpath = localpath.replace(ltop, rtop)
        return relpath if exists(relpath) else ""

    def addrelease(self):
        ltop = environ['LOCALTOP']
        rtop = environ['RELEASETOP']
        for k in ['INCLUDE', 'LIBDIR']:
            if k not in self.xml.contents:
                continue
            for v in self.xml.contents[k]:
                v = self._getreleasedata(v, ltop, rtop)
                if v and v not in self.xml.contents[k]:
                    self.xml.contents[k].append(v)
        if 'RUNTIME' not in self.xml.contents:
            return
        for var in [v for v in self.xml.contents['RUNTIME'] if v.startswith('PATH:')]:
            for d in self.xml.contents['RUNTIME'][var]:
                d = self._getreleasedata(d, ltop, rtop)
                if d and d not in self.xml.contents['RUNTIME'][var]:
                    self.xml.contents['RUNTIME'][var].append(d)
        return
