import xml.etree.ElementTree as ET
from os import environ
from re import search
from SCRAM import printerror

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


class SimpleDoc(object):
    def __init__(self, valid_attribs={}):
        self.valid_attribs = {
            "use": ["name", "source_only"],
            "lib": ["name", "type"],
            "export": [],
            "include_path": ["path"],
            "bin": ["name", "file"],
            "library": ["name", "file"],
            "test": ["name", "command"],
            "environment": [],
            "ifarchitecture": ["name", "match", "value"],
            "ifcxx11_abi": ["value"],
            "ifrelease": ["name", "match", "value"],
            "iftool": ["name", "match", "version"],
            "release": ["name", "match", "value"],
            "else": [],
            "architecture": ["name", "match", "value"],
            "root": [],
            "productstore": ["name", "type", "swap"],
            "classpath": ["path"],
            "flags": ["*"],
            "client": [],
            "tool": ["name", "version", "type"],
            "info": ["url"],
            "runtime": ["name", "value", "type", "default", "handler"],
            "project": ["name", "version"],
            "base": ["url"]
        }
        for tag in valid_attribs:
            self.valid_attribs[tag] = valid_attribs[tag][:]
        self.filters = {}
        self.callbacks = {}
        self.last_filter = []
        self.filename = None
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
            root = ET.fromstringlist(['<root>', ref.read(), '</root>'])
        self.process(root)
        return root

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
