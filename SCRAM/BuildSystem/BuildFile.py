from SCRAM import printerror, scramerror
from SCRAM.BuildSystem.SimpleDoc import SimpleDoc, replaceVariables, loopData
from SCRAM.BuildSystem.TemplateStash import TemplateStash
from os.path import basename
from json import dump
from re import compile,match,search,sub
import xml.etree.ElementTree as ET

reReplaceEnv = compile(r'^(.*)(\$\{(\w+)\})(.*)$')


class BuildFile(object):
    def __init__(self, toolmanager=None, contents={}):
        self.contents = contents
        self.tag = ""
        self.tools = {}
        self.flags = {}
        self.selected = {}
        self.group = []
        self.product = None
        self.variables = TemplateStash()
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
        self.group = []
        self.variables = TemplateStash()
        self.contents = {'USE': [], 'EXPORT': {}, 'FLAGS': {}, 'BUILDPRODUCTS': {}}

    def _update_product(self, tag, value, key=None):
        if tag not in self.product:
            self.product[tag] = [] if key is None else {}
        if key is None:
            self.product[tag].append(replaceVariables(value, self.variables))
        else:
            key = replaceVariables(key, self.variables)
            if key not in self.product[tag]:
                self.product[tag][key] = []
            self.product[tag][key].append(replaceVariables(value, self.variables))
        return

    def _add_product(self, data, tag_name, prod_type):
        tag = 'BIN' if tag_name=='TEST' else tag_name
        if tag not in self.contents['BUILDPRODUCTS']:
            self.contents['BUILDPRODUCTS'][tag] = {}
        name = data.attrib['name'] if ((tag_name == 'TEST') or ('name' in data.attrib)) \
                                       else basename(data.attrib['file']).rsplit('.', 1)[0]
        self.contents['BUILDPRODUCTS'][tag][name] = {'USE': [], 'EXPORT': {}, 'FLAGS': {}}
        self.product = self.contents['BUILDPRODUCTS'][tag][name]
        self.product['TYPE'] = prod_type
        if tag_name == 'TEST':
            self.product['COMMAND'] = replaceVariables(data.attrib['command'], self.variables)
        else:
            self.product['FILES'] = replaceVariables(data.attrib['file'], self.variables)
        return

    def _update_contents(self, data):
        inv = self.parser.check_valid_attrib(data)
        if inv:
            printerror("ERROR: Invalid attribute '%s' in file %s.\n%s" % (inv, self.filename, ET.tostring(data)))
            return False
        tag = data.tag.upper()
        self.tag = tag
        if tag == 'USE':
            use = data.attrib['name'].lower()
            if use == "self":
                return True
            group = ""
            if "for" in data.attrib:
                group = data.attrib["for"]
            elif self.group:
                group = "_".join(self.group)
            if use not in self.tools:
                self.tools[use] = self.toolmanager.hastool(use)
            if not self.tools[use]:
                use = data.attrib['name']
            if ('force_link' in data.attrib) and (data.attrib['force_link'] in ["1", "true"]):
                self._update_contents(ET.Element("flags", {'FORCE_LINK': use}))
            if ('source_only' in data.attrib) and (data.attrib['source_only'] in ["1", "true"]):
                self._update_contents(ET.Element("flags", {'USE_SOURCE_ONLY': use}))
            elif group:
                self._update_contents(ET.Element("flags", {'USE_%s' % sub("[-/]", "_", group): use}))
            else:
                self._update_product(tag, use)
        elif tag == 'LIB':
            self._update_product(tag, data.attrib['name'])
        elif tag == 'INCLUDE_PATH':
            tag = 'INCLUDE'
            self._update_product(tag, data.attrib['path'])
        elif tag == 'FLAGS':
            fname = ""
            if 'file' in data.attrib:
                fname = "FILE"+data.attrib['file']+"_"
                del data.attrib['file']
            flag_name = list(data.attrib)[0]
            self._update_product(tag, data.attrib[flag_name], "%s%s" % (fname, flag_name.upper()))
        elif tag == 'EXPORT':
            self.contents[tag] = {'LIB': []}
            self.product = self.contents[tag]
        elif tag in ['BIN', 'LIBRARY', 'TEST']:
            self.variables.pushstash()
            self._add_product(data, tag, tag.lower() if tag in ('BIN', 'TEST') else 'lib')
        elif tag == 'SET':
            self.variables.set(data.attrib['name'], data.attrib['value'])
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
        elif tag == 'GROUP':
            self.group.append(data.attrib['name'])
        else:
            printerror('ERROR: Unknown tag %s found in %s.' % (data.tag, self.filename))
        for child in list(data):
            if not self._update_contents(child):
                return False
        if tag in ['BIN', 'LIBRARY', 'TEST']:
            self.variables.popstash()
            for key in list(self.product):
                if not self.product[key]:
                    del self.product[key]
            self.product = self.contents
        elif tag in ["EXPORT"]:
            self.product = self.contents
        elif tag == 'GROUP':
            self.group.pop()
        return True

    def _check_iftool(self, node):
        toolname = node.attrib['name'].lower()
        pre = ""
        if toolname[0]=='!':
          pre = '!'
          toolname = toolname[1:]
        tool_filter = 'iftool_%s' % toolname
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
        node.attrib = {'match': pre+version}
        return node
