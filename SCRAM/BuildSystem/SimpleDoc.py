import xml.etree.ElementTree as ET
from os import environ
from re import compile, match, search
from sys import platform
from platform import machine
from copy import deepcopy
from SCRAM import printerror
from SCRAM.BuildSystem.TemplateStash import TemplateStash

reReplaceEnv = compile(r'^(.*)(\$\{(\w+)\})(.*)$')

DEFAULT_ENV_FILTERS = {
    'ifarchitecture': 'SCRAM_ARCH',
    'architecture': 'SCRAM_ARCH',
    'release': 'SCRAM_PROJECTVERSION',
    'compiler': 'DEFAULT_COMPILER',
    'ifrelease': 'SCRAM_PROJECTVERSION',
    'ifcompiler': 'DEFAULT_COMPILER',
    'ifcxx11_abi': 'SCRAM_CXX11_ABI',
    'ifproject': 'SCRAM_PROJECTNAME',
    'ifconfig': 'SCRAM_CONFIGCHKSUM',
    'ifscram': 'SCRAM_VERSION'
}

def replaceVariables(data, variables):
    while '${' in data:
        m = reReplaceEnv.match(data)
        if not m: return data
        value = variables.get(m.group(3), default=None)
        value = m.group(2) if (value is None) else replaceVariables(value, variables)
        xdata = (
            replaceVariables(m.group(1), variables) +
            value +
            replaceVariables(m.group(4), variables)
        )
        if xdata == data: return data
        data = xdata
    return data

def loopData(tag, var, value, stash):
    values = []
    if tag == "foreach":
        values = [replaceVariables(v.strip(), stash)
                  for v in value.split(",") if v.strip()]
    elif tag == "for":
        loops_vals = [v.strip() for v in value.split(",", 2)]
        loop_items = [1, int(loops_vals[-1]), 1]
        if len(loops_vals)>1:
            loop_items[0] = int(loops_vals[0])
            if len(loops_vals)>2:
                loop_items[2] = loop_items[1]
                loop_items[1] = int(loops_vals[1])
        stash.set('step_'+var, str(loop_items[2]))
        stash.set('start_'+var, str(loop_items[0]))
        stash.set('end_'+var, str(loop_items[1]))
        loop_items[1] += loop_items[2]
        values = [str(x) for x in range(*loop_items)]
    return values


class SimpleDoc(object):
    def __init__(self, valid_attribs={}):
        self.valid_attribs = {
            "use": ["name", "source_only", "for", "force_link"],
            "lib": ["name", "type"],
            "export": [],
            "include_path": ["path"],
            "bin": ["name", "file", "for", "foreach"],
            "library": ["name", "file", "for", "foreach"],
            "test": ["name", "command", "for", "foreach"],
            "set": ["name", "value"],
            "foreach": ["set", "value"],
            "for": ["set", "value"],
            "environment": [],
            "ifarchitecture": ["name", "match", "value"],
            "compiler": ["name", "match", "value"],
            "ifcompiler": ["name", "match", "value"],
            "ifcxx11_abi": ["value"],
            "ifrelease": ["name", "match", "value"],
            "iftool": ["name", "match", "version"],
            "ifos": ["name", "match", "value"],
            "ifarch": ["name", "match", "value"],
            "release": ["name", "match", "value"],
            "else": [],
            "architecture": ["name", "match", "value"],
            "root": [],
            "productstore": ["name", "type", "swap"],
            "classpath": ["path"],
            "flags": ["*"],
            "client": [],
            "tool": ["name", "version", "type", "revision", "path"],
            "info": ["url"],
            "runtime": ["name", "value", "type", "default", "handler", "join"],
            "project": ["name", "version"],
            "group": ["name"],
            "base": ["url"]
        }
        for tag in valid_attribs:
            self.valid_attribs[tag] = valid_attribs[tag][:]
        self.filters = {}
        self.callbacks = {}
        self.last_filter = []
        self.filename = None
        self.variables = TemplateStash()
        self.add_filter('ifos', platform)
        self.add_filter('ifarch', machine())
        for filt in DEFAULT_ENV_FILTERS:
            value = ""
            filtenv = DEFAULT_ENV_FILTERS[filt]
            if filtenv in environ:
                value = environ[filtenv]
            self.add_filter(filt, value)

    def check_valid_attrib(self, data):
        invalid_attrib = []
        tag = data.tag
        if tag.startswith("iftool_"):
            tag = "iftool"
        if tag not in self.valid_attribs:
            printerror("Invalid tag '%s' found in %s." % (tag, self.filename))
            return []
        valid_attrib = self.valid_attribs[tag]
        if "comment" in data.attrib:
            del data.attrib["comment"]
        if '*' in valid_attrib:
            return invalid_attrib
        for atr in data.attrib:
            if atr not in valid_attrib:
                invalid_attrib.append(atr)
        return invalid_attrib

    def add_callback(self, tag, callback, args=None):
        self.callbacks[tag] = [callback, args]

    def add_filter(self, filter, value, callback=None):
        self.filters[filter] = [value, callback]

    def remove_filter(self, filter):
        if filter in self.filters:
            del self.filters[filter]

    def has_filter(self, filter):
        return filter in self.filters

    def apply_filter(self, node):
        tag = node.tag
        if tag == 'elif':
            tag = self.last_filter[-1]
        if self.filters[tag][1]:
            node = self.filters[tag][1](node)
            tag = node.tag
        filter_value = self.filters[tag][0]
        exact = False
        filter = ""
        if 'value' in node.attrib:
            filter = node.attrib['value']
            exact = True
        elif 'match' in node.attrib:
            filter = node.attrib['match']
        else:
            filter = node.attrib['name']
        ok = False
        if filter.startswith('!'):
            filter = filter[1:]
            if exact and (filter_value != filter):
                ok = True
            if (not exact) and (not search(filter, filter_value)):
                ok = True
        elif exact and (filter_value == filter):
            ok = True
        elif not exact and search(filter, filter_value):
            ok = True
        return ok

    def parse(self, filename):
        self.filename = filename
        self.last_filter = []
        root = None
        with open(filename) as ref:
            xml_data = ref.read()
            try:
                root = ET.fromstringlist(['<root>', xml_data, '</root>'])
            except Exception as e:
                print("ERROR: Failed to parse", filename)
                if hasattr(e, "position"):
                    lines = xml_data.splitlines()
                    lineno = getattr(e, "position", (None, None))[0]
                    print("\nOffending line:")
                    print(lines[lineno - 1])
                    print("\nContext:")
                    for i in range(max(0, lineno - 3), min(len(lines), lineno + 2)):
                        print(f"{i+1}: {lines[i]}")
                printerror("ERROR:\n%s" % e)
        self._expand(root)
        self.process(root)
        return root

    def _expand_product(self, node, child):
        if not child.tag.upper() in ['BIN', 'LIBRARY', 'TEST']: return False
        loop_type = ""
        if 'for' in child.attrib:
            loop_type = "for"
        elif 'foreach' in child.attrib:
            loop_type = "foreach"
        if not loop_type: return False
        self.variables.pushstash()
        var = "value"
        values = loopData(loop_type, var, child.attrib[loop_type], self.variables)
        name = child.attrib['name'] if 'name' in child.attrib else basename(child.attrib['file']).rsplit('.', 1)[0]
        del child.attrib[loop_type]
        idx = list(node).index(child)
        for value in values:
            self.variables.set(var, value)
            new_node = deepcopy(child)
            new_node.attrib['name'] = '%s_%s' % (name, value)
            self._substitute(new_node)
            node.insert(idx, new_node)
            idx += 1
        node.remove(child)
        self.variables.popstash()
        return True

    def _expand(self, node):
        for child in list(node):
            if self._expand_product(node, child): continue
            self._expand(child)
            values = []
            var = None
            if child.tag in ["foreach", "for"]:
                self.variables.pushstash()
                var = child.attrib["set"]
                values = loopData(child.tag, var, child.attrib["value"], self.variables)
            else:
                continue
            idx = list(node).index(child)
            for value in values:
                self.variables.set(var, value)
                for grandchild in child:
                    new_node = deepcopy(grandchild)
                    self._substitute(new_node)
                    node.insert(idx, new_node)
                    idx += 1
            node.remove(child)
            self.variables.popstash()

    def _substitute(self, node):
        for k in list(node.attrib.keys()):
            nk = replaceVariables(k, self.variables)
            nv = replaceVariables(node.attrib[k], self.variables)
            if k != nk:
                del node.attrib[k]
            node.attrib[nk] = nv
        for child in node:
            self._substitute(child)
        return

    def process(self, root):
        keep = True
        filtered = False
        inv = self.check_valid_attrib(root)
        if inv:
            printerror("ERROR: Invalid attribute '%s' in file %s.\n%s" % (inv, self.filename, root))
        if root.tag in self.callbacks:
            self.callbacks[root.tag][0](root=root, start_event=True,
                                        args=self.callbacks[root.tag][1])
        if root.tag in self.filters:
            self.last_filter.append(root.tag)
            keep = self.apply_filter(root)
            root.attrib = {}
            filtered = True
        removeAll = False
        for child in list(root):
            if (not filtered) and child.tag in ['else', 'elif']:
                raise Exception("Invalid tag '%s' found without any conditioanl statement found:\n  %s"
                                % (child.tag, ET.tostring(child)))
            if removeAll:
                root.remove(child)
            elif child.tag not in ['else', 'elif']:
                if not keep:
                    root.remove(child)
                elif list(child):
                    self.process(child)
            else:
                root.remove(child)
                if keep:
                    removeAll = True
                elif child.tag == 'else':
                    keep = True
                else:
                    keep = self.apply_filter(child)

        if root.tag in self.filters:
            del self.last_filter[-1]
        if root.tag in self.callbacks:
            self.callbacks[root.tag][0](root=root, start_event=False,
                                        args=self.callbacks[root.tag][1])
        return
