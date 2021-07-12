from SCRAM import printerror, scramerror
from SCRAM.BuildSystem.SimpleDoc import SimpleDoc
from SCRAM.BuildSystem.TemplateStash import TemplateStash
from os.path import basename
from json import dump
from re import compile,match,search
import xml.etree.ElementTree as ET

reReplaceEnv = compile(r'^(.*)(\$\{(\w+)\})(.*)$')


class BuildFile(object):
    def __init__(self, toolmanager=None, contents={}):
        self.contents = contents
        self.tag = ""
        self.tools = {}
        self.flags = {}
        self.selected = {}
        self.loop_products = []
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
        self.loop_products = []
        self.variables = TemplateStash()
        self.contents = {'USE': [], 'EXPORT': {}, 'FLAGS': {}, 'BUILDPRODUCTS': {}}

    def _update_product(self, tag, value, key=None):
        for (prod,index) in self.loop_products if self.loop_products else [(self.product,None)]:
            if tag not in prod:
                prod[tag] = [] if key is None else {}
            pre_data = {} if index is None else {"value": index}
            if key is None:
                prod[tag].append(self._replace_variables(value, pre_data))
            else:
                key = self._replace_variables(key, pre_data)
                if key not in prod[tag]:
                    prod[tag][key] = []
                prod[tag][key].append(self._replace_variables(value, pre_data))
        return

    def _check_value(self, data):
        if search('[$][(]+[^)]+\s', data) or search('[$][{]+[^}]+\s', data):
            scramerror("Invalid attribute value '%s' found for tag '%s' in %s." % (data, self.tag, self.filename))
        return data

    def _replace_variables(self, data, pre_data, recursive=False):
        if not data: return data
        m = reReplaceEnv.match(data)
        if not m: return self._check_value(data)
        value = pre_data[m.group(3)] if (m.group(3) in pre_data) else self.variables.get(m.group(3), default=None)
        value = m.group(2) if (value is None) else self._replace_variables(value, pre_data, recursive=True)
        xdata = "%s%s%s" % (self._replace_variables(m.group(1), pre_data, recursive=True), \
                            value, \
                            self._replace_variables(m.group(4), pre_data, recursive=True))
        data = data if (xdata == data) else self._replace_variables(xdata, pre_data, recursive=True)
        if not recursive:
            data = self._check_value(data)
        return data

    def _add_loop_products(self, data, tag_name, prod_type):
        loop_data = []
        if 'for' in data.attrib:
            loops_vals = data.attrib['for'].split(",", 2)
            loop_items = [1, int(loops_vals[-1]), 1]
            if len(loops_vals)>1:
                loop_items[0] = int(loops_vals[0])
                if len(loops_vals)>2:
                    loop_items[2] = loop_items[1]
                    loop_items[1] = int(loops_vals[1])
            self.variables.set('step_value', str(loop_items[2]))
            self.variables.set('start_value', str(loop_items[0]))
            self.variables.set('end_value', str(loop_items[1]))
            loop_items[1] += loop_items[2]
            loop_data = [str(x) for x in range(*loop_items)]
        elif 'foreach' in data.attrib:
            for item in [x.strip() for x in data.attrib['foreach'].split(",")]:
                if (not item) or (not match('^[a-zA-Z0-9_.+-]+$', item)):
                    scramerror("ERROR: Invalid 'foreach' item '%s' found in file %s.\n%s" % (item, self.filename, ET.tostring(data)))
                else:
                    loop_data.append(item)
        if not loop_data:
            loop_data = [""]
        tag = 'BIN' if tag_name=='TEST' else tag_name
        if tag not in self.contents['BUILDPRODUCTS']:
            self.contents['BUILDPRODUCTS'][tag] = {}
        xname = data.attrib['name'] if ((tag_name == 'TEST') or ('name' in data.attrib)) \
                                       else basename(data.attrib['file']).rsplit('.', 1)[0]
        pre_data = {}
        for value in loop_data:
            name = xname
            if value:
                pre_data['value'] = value
                name = "%s_%s" % (xname, value)
            self.contents['BUILDPRODUCTS'][tag][name] = {'USE': [], 'EXPORT': {}, 'FLAGS': {}}
            self.product = self.contents['BUILDPRODUCTS'][tag][name]
            self.product['TYPE'] = prod_type
            if tag_name == 'TEST':
                self.product['COMMAND'] = self._replace_variables(data.attrib['command'], pre_data)
            else:
                self.product['FILES'] = self._replace_variables(data.attrib['file'], pre_data)
            if value:
                self.loop_products.append((self.product,value))
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
            if use not in self.tools:
                self.tools[use] = self.toolmanager.hastool(use)
            if not self.tools[use]:
                use = data.attrib['name']
            if ('source_only' in data.attrib) and (data.attrib['source_only'] in ["1", "true"]):
                self._update_contents(ET.Element("flags", {'USE_SOURCE_ONLY': use}))
            else:
                self._update_product(tag, use)
        elif tag == 'LIB':
            self._update_product(tag, data.attrib['name'])
        elif tag == 'INCLUDE_PATH':
            tag = 'INCLUDE'
            self._update_product(tag, data.attrib['path'])
        elif tag == 'FLAGS':
            flag_name = list(data.attrib)[0]
            self._update_product(tag, data.attrib[flag_name], flag_name.upper())
        elif tag == 'EXPORT':
            self.contents[tag] = {'LIB': []}
            self.product = self.contents[tag]
        elif tag in ['BIN', 'LIBRARY', 'TEST']:
            self.loop_products = []
            self.variables.pushstash()
            if tag == 'TEST':
                self._add_loop_products(data, tag, 'test')
            else:
              self._add_loop_products(data, tag, 'bin' if tag == 'BIN' else 'lib')
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
        else:
            printerror('ERROR: Unknown tag %s found in %s.' % (data.tag, self.filename))
        for child in list(data):
            if not self._update_contents(child):
                return False
        if tag in ['BIN', 'LIBRARY', 'TEST']:
            for prod,index in self.loop_products if self.loop_products else [(self.product,None)]:
                for key in list(prod):
                    if not prod[key]:
                        del prod[key]
            self.loop_products = []
            self.variables.popstash()
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
