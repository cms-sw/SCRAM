from glob import glob
from json import load, loads, dumps
from os.path import basename, exists, join, isdir, dirname, abspath
from os import remove, stat, utime
from glob import glob
from shutil import copy2, move
from SCRAM import run_command, printerror, scramerror, printmsg
from SCRAM.Configuration.ConfigArea import ConfigArea
from SCRAM.BuildSystem.ToolFile import ToolFile
from SCRAM.Utilities.AddDir import adddir, copydir, copyfile


def isnewer(srcfile, desfile):
    return not exists(desfile) or \
        stat(desfile).st_mtime < stat(srcfile).st_mtime


class ToolManager(object):
    def __init__(self, area):
        self.area = area
        self.tools = {}
        self.loaded = False
        self.xml = None
        return

    def setupself(self):
        selftool = join(self.area.config(), 'Self.xml')
        if not exists(selftool):
            printerror("\nSCRAM: No file config/Self.xml...nothing to do.")
            return False
        if not self.xml:
            self.xml = ToolFile()
        if not self.xml.parse(selftool):
            scramerror("Failed to setup 'self' tool")
        self.tools['self'] = self.xml.contents
        tooljson = self.tool_json_path('self')
        if not isnewer(selftool, tooljson):
            return
        self._update_json(tooljson)
        return

    def setupalltools(self):
        for toolfile in glob(join(self.area.toolbox(), 'selected', '*.xml')):
            self.coresetup(toolfile)

    def coresetup(self, toolfile):
        tname = basename(toolfile)[:-4].lower()
        toolfile = abspath(toolfile)
        if not self.xml:
            self.xml = ToolFile()
        if not self.xml.parse(toolfile):
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
        self._update_json(tooljson)
        return

    def _update_json(self, tooljson, dump=True):
        if exists(tooljson):
            old_contents = load(open(tooljson))
            if old_contents == loads(dumps(self.xml.contents)):
                utime(tooljson, None)
                return False
        if not exists(self.area.toolcachename()):
            adddir(self.area.toolcachename())
        self.xml.save_json(tooljson)
        utime(self.area.toolcachename(), None)
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
            for tool in glob(join(self.area.toolcachename(), '*.json')):
                toolname = basename(tool)[:-5]
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
        tooldata = {}
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
        return join(self.area.toolcachename(), toolname.lower() + '.json')

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

    def _getreleasedata(self, localpath):
        ltop = environ['LOCALTOP']
        rtop = environ['RELEASETOP']
        if not localpath.startswith(ltop):
            return ""
        relpath = localpath.replace(ltop, rtop)
        return relpath if exists(relpath) else ""

    def addrelease(self, contents):
        ltop = environ['LOCALTOP']
        rtop = environ['RELEASETOP']
        for k in ['INCLUDE', 'LIBDIR']:
            if k not in contents:
                continue
            for v in contents[k]:
                v = self._getreleasedata(v)
                if v and v not in contents[k]:
                    contents[k].append(v)
        if 'RUNTIME' not in contents:
            return
        for var in [v for v in contents['RUNTIME'] if v.startswith('PATH:')]:
            for d in contents['RUNTIME'][var]:
                d = self._getreleasedata(d)
                if d and d not in contents['RUNTIME'][var]:
                    contents['RUNTIME'][var].append(d)
        return
