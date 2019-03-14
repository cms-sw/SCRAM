from SCRAM.BuildSystem.SimpleDoc import SimpleDoc
from os.path import exists, join, basename
from json import load, dump


class BuildFile(object):
    def __init__(self, toolmanager):
        self.tools = {}
        self.toolmanager = toolmanager
        self.parser = SimpleDoc()
        self.parser.add_filter('iftool', '', self._check_iftool)
        return

    def save_on_change(self, outfile):
        if exists(outfile):
            old = load(open(outfile))
            if old == self.contents:
                return
        self.save_json(outfile)

    def save_json(self, outfile):
        with open(outfile, 'w') as ref:
            dump(self.contents, ref, sort_keys=True, indent=2)
        return

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

    def _clean(self, filename=None):
        self.filename = filename
        self.contents = {'USE': [], 'EXPORT': {}, 'FLAGS': {}, 'BUILDPRODUCTS': {}}

    def _update_contents(self, data):
        tag = data.tag.upper()
        if tag == 'USE':
            if 'name' not in data.attrib:
                return True
            use = data.attrib['name'].lower()
            if use not in self.tools:
                self.tools[use] = self.toolmanager.hastool(use)
            if not self.tools[use]:
                use = data.attrib['name']
            if tag not in self.product:
                self.product[tag] = []
            if use not in self.product[tag]:
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
                self.product[tag] = []
            flag_name = list(data.attrib)[0]
            value = data.attrib[flag_name]
            flag_name = flag_name.upper()
            if flag_name not in self.product[tag]:
                self.product[tag][flag_name] = []
            self.product[tag][flag_name].append(value)
        elif tag == 'EXPORT':
            self.contents[tag] = {'USE': [], 'FLAGS': {}}
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
            name = data.attrib['name']
            self.contents['BUILDPRODUCTS'][tag][name] = {'USE': [], 'EXPORT': {}, 'FLAGS': {}}
            self.product = self.contents['BUILDPRODUCTS'][tag][name]
            self.product['TYPE'] = 'test'
            self.product['COMMAND'] = data.attrib['command']
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
            print('ERROR: Unknown tag %s found in %s.' % (data.tag, self.filename))
        for child in list(data):
            if not self._update_contents(child):
                return False
        if tag in ['EXPORT', 'BIN', 'LIBRARY']:
            for key in list(self.product):
                if not self.product[key]:
                    del self.product[key]
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
