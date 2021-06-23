from SCRAM import printerror
from SCRAM.BuildSystem.SimpleDoc import SimpleDoc
from os.path import basename
from json import dump
import xml.etree.ElementTree as ET


class BuildFile(object):
    def __init__(self, toolmanager=None, contents={}):
        self.contents = contents
        self.tools = {}
        self.flags = {}
        self.selected = {}
        self.toolmanager = toolmanager
        self.parser = SimpleDoc()
        self.parser.add_filter('iftool', '', self._check_iftool)
        return

    def save_json(self, outfile):
        with open(outfile, 'w') as ref:
            dump(self.contents, ref, sort_keys=True, indent=2)
        return True

    def set_contents(self, contents):
        self.contents = contents

    def parse(self, filename):
        self._clean(filename)
        data = self.parser.parse(filename)
        self.product = self.contents
        if not self._update_contents(data):
            return False
        for key in list(self.contents):
            if not self.contents[key]:
                del self.contents[key]
        return True

    def get_flags(self):
        if self.flags:
            return self.flags
        data = self.get_data("FLAGS")
        if not data:
            return {}
        vals = {}
        for x in data:
            for f in x:
                if f not in vals:
                    vals[f] = []
                if f == "CPPDEFINES":
                    vals[f] += ["-D%s" % i for i in x[f]]
                else:
                    vals[f] += x[f]
        self.flags = vals
        return vals

    def get_data(self, key, toplevel=False):
        topdata = {}
        data = []
        if key in self.contents:
            topdata = self.contents[key]
            data.append(topdata)
        if toplevel:
            return topdata
        if self.selected and key in self.selected:
            data.append(self.selected[key])
        return data

    def get_flag_value(self, flag, as_string=True):
        flags = self.get_flags()
        val = []
        if flags and (flag in flags):
            val = flags[flag]
        if as_string:
            return " ".join(val)
        return val

    def add_build_product(self, name, files, type, typename):
        if "BUILDPRODUCTS" not in self.contents:
            self.contents["BUILDPRODUCTS"] = {}
        if typename not in self.contents["BUILDPRODUCTS"]:
            self.contents["BUILDPRODUCTS"][typename] = {}
        self.contents["BUILDPRODUCTS"][typename][name] = {"FILES": files,
                                                          "TYPE": type}

    def get_build_products(self):
        prods = {}
        if "BUILDPRODUCTS" in self.contents:
            prods = self.contents["BUILDPRODUCTS"]
        return prods

    def get_products(self, type):
        if "BUILDPRODUCTS" in self.contents:
            if type in self.contents["BUILDPRODUCTS"][type]:
                return self.contents["BUILDPRODUCTS"][type]
        return {}

    def set_build_product(self, prodtype, name):
        self.flags = {}
        self.selected = self.contents["BUILDPRODUCTS"][prodtype][name]

    def get_product_files(self):
        if "FILES" in self.selected:
            return [f for fs in self.selected["FILES"].split(",") for f in fs.split(" ") if f]
        return []

    def _clean(self, filename=None):
        self.filename = filename
        self.flags = {}
        self.selected = {}
        self.contents = {'USE': [], 'EXPORT': {}, 'FLAGS': {}, 'BUILDPRODUCTS': {}}

    def _update_contents(self, data):
        inv = self.parser.check_valid_attrib(data)
        if inv:
            printerror("ERROR: Invalid attribute '%s' in file %s.\n%s" % (inv, self.filename, data))
        tag = data.tag.upper()
        if tag == 'USE':
            use = data.attrib['name'].lower()
            if use == "self":
                return True
            if use not in self.tools:
                self.tools[use] = self.toolmanager.hastool(use)
            if not self.tools[use]:
                use = data.attrib['name']
            if ('source_only' in data.attrib) and (data.attrib['source_only'] in ["1", "true"]):
                self._update_contents(ET.Element("flags", {'USE_SOURCE_ONLY': use}))
            else:
                if tag not in self.product:
                    self.product[tag] = []
                self.product[tag].append(use)
        elif tag == 'LIB':
            if tag not in self.product:
                self.product[tag] = []
            self.product[tag].append(data.attrib['name'])
        elif tag == 'INCLUDE_PATH':
            tag = 'INCLUDE'
            if tag not in self.product:
                self.product[tag] = []
            self.product[tag].append(data.attrib['path'])
        elif tag == 'FLAGS':
            if tag not in self.product:
                self.product[tag] = {}
            flag_name = list(data.attrib)[0]
            value = data.attrib[flag_name]
            flag_name = flag_name.upper()
            if flag_name not in self.product[tag]:
                self.product[tag][flag_name] = []
            self.product[tag][flag_name].append(value)
        elif tag == 'EXPORT':
            self.contents[tag] = {'LIB': []}
            self.product = self.contents[tag]
        elif tag in ['BIN', 'LIBRARY']:
            if tag not in self.contents['BUILDPRODUCTS']:
                self.contents['BUILDPRODUCTS'][tag] = {}
            name = data.attrib['name'] if 'name' in data.attrib \
                                          else basename(data.attrib['file']).rsplit('.', 1)[0]
            self.contents['BUILDPRODUCTS'][tag][name] = {'USE': [], 'EXPORT': {}, 'FLAGS': {}}
            self.product = self.contents['BUILDPRODUCTS'][tag][name]
            self.product['FILES'] = data.attrib['file']
            self.product['TYPE'] = 'bin' if tag == 'BIN' else 'lib'
        elif tag == 'TEST':
            tag = 'BIN'
            if tag not in self.contents['BUILDPRODUCTS']:
                self.contents['BUILDPRODUCTS'][tag] = {}
            loop_items = [1,2,1]
            loop_test = False
            if 'loop' in data.attrib:
                loop_test = True
                loops_vals = data.attrib['loop'].split(",", 2)
                loop_items[1] = int(loops_vals[-1])
                if len(loops_vals)>1:
                    loop_items[0] = int(loops_vals[0])
                    if len(loops_vals)>2:
                        loop_items[2] = loop_items[1]
                        loop_items[1] = int(loops_vals[1])
                loop_items[1] += loop_items[2]
            xname = data.attrib['name']
            xcmd = data.attrib['command']
            for i in range(*loop_items):
                name = xname
                cmd = xcmd
                if loop_test:
                    name = xname.replace("${loop}",str(i))
                    name = name.replace("${step}",str(loop_items[2]))
                    cmd = xcmd.replace("${loop}",str(i))
                    cmd = cmd.replace("${step}",str(loop_items[2]))
                self.contents['BUILDPRODUCTS'][tag][name] = {'USE': [], 'EXPORT': {}, 'FLAGS': {}}
                self.product = self.contents['BUILDPRODUCTS'][tag][name]
                self.product['TYPE'] = 'test'
                self.product['COMMAND'] = cmd
        elif tag in ['ROOT', 'ENVIRONMENT'] or self.parser.has_filter(data.tag):
            pass
        elif tag == 'PRODUCTSTORE':
            if tag not in self.contents:
                self.contents[tag] = []
            self.contents[tag].append(data.attrib)
        elif tag == 'CLASSPATH':
            if tag not in self.contents:
                self.contents[tag] = []
            self.contents[tag].append(data.attrib['path'])
        else:
            printerror('ERROR: Unknown tag %s found in %s.' % (data.tag, self.filename))
        for child in list(data):
            if not self._update_contents(child):
                return False
        if tag in ['BIN', 'LIBRARY']:
            for key in list(self.product):
                if not self.product[key]:
                    del self.product[key]
            self.product = self.contents
        elif tag in ["EXPORT"]:
            self.product = self.contents
        return True

    def _check_iftool(self, node):
        toolname = node.attrib['name'].lower()
        tool_filter = 'iftool_%s' % toolname
        if node.tag == 'elif':
            del self.parser.last_filter[-1]
        if not self.parser.has_filter(tool_filter):
            tooldata = self.toolmanager.gettool(toolname)
            toolver = ''
            if tooldata:
                toolver = tooldata['TOOLVERSION']
            self.parser.add_filter(tool_filter, toolver)
        version = '.+'
        if 'version' in node.attrib:
            version = node.attrib['version']
        node.tag = tool_filter
        node.attrib = {'match': version}
        return node
