import xml.etree.ElementTree as ET
from os import environ
from re import search


class SimpleDoc(object):
    def __init__(self):
        self.filters = {}
        self.callbacks = {}
        self.last_filter = []
        if 'SCRAM_ARCH' in environ:
            self.add_filter('architecture', environ['SCRAM_ARCH'])
            self.add_filter('ifarchitecture', environ['SCRAM_ARCH'])
        if 'SCRAM_PROJECTVERSION' in environ:
            self.add_filter("release", environ['SCRAM_PROJECTVERSION'])
            self.add_filter("compiler", environ['DEFAULT_COMPILER'])
            self.add_filter("ifrelease", environ['SCRAM_PROJECTVERSION'])
            self.add_filter("ifcompiler", environ['DEFAULT_COMPILER'])
            self.add_filter("ifcxx11_abi", environ['SCRAM_CXX11_ABI'])
            self.add_filter("ifproject", environ['SCRAM_PROJECTNAME'])
            self.add_filter("ifconfig", environ['SCRAM_CONFIGCHKSUM'])
            self.add_filter("ifscram", environ['SCRAM_VERSION'])

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
        self.last_filter = []
        root = None
        with open(filename) as ref:
            root = ET.fromstringlist(['<root>', ref.read(), '</root>'])
        self.process(root)
        if 'SCRAM_DEBUG' in environ:
            ET.dump(root)
        return root

    def process(self, root):
        keep = True
        filtered = False
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
