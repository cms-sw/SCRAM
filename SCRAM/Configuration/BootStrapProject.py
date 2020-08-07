"""
no need to use parsing call back functions (project, porject_)
use SimpleDoc class
"""
import logging

from SCRAM.BuildSystem.SimpleDoc import SimpleDoc
from SCRAM.Configuration.ConfigArea import ConfigArea
from os import environ, makedirs, system
from re import compile
from SCRAM import die
from os.path import isdir, isfile, join, normpath

regex_file = compile(r"^\s*file:")


def _remove_file(str):
    """
    Removes leading space, 'file:' string and surrounding whitespaces
    """
    return regex_file.sub("", str).strip()


class BootStrapProject:

    def __init__(self, baselocation):
        """

        :param baselocation: destination where project will be setupped
        """
        self.area = ConfigArea()  # sets SCRAM_ARCH env variable by default
        self.baselocation = baselocation
        self.file_to_parse = None

    def boot(self, filename):
        self.file_to_parse = filename
        parser = SimpleDoc()
        data = parser.parse(filename)
        self._update_contents(data)
        self._process()  # TODO last function to create directories
        return self.area

    def _update_contents(self, data, base_src_list=None):
        if base_src_list is None:  # nested list of baseUrl, last one is important
            base_src_list = []
        if data.tag == "project":
            if 'source' in data.attrib:
                src = data.attrib['source']
            else:
                src = 'src'
            name = data.attrib['name']
            version = data.attrib['version']
            self.area.name(name)
            self.area.version(version)
            self.area.sourcedir(src)
            environ["SCRAM_SOURCEDIR"] = src
            self.area.setup(self.baselocation)
        elif data.tag == "config":
            environ["SCRAM_CONFIGDIR"] = data.attrib['dir']
            self.area.configurationdir(data.attrib['dir'])
        elif data.tag == "toolbox":
            dir_atr = regex_file.sub("", data.attrib['dir'])
            self.toolbox = dir_atr
        elif data.tag == "base":
            base_src_list = list(base_src_list)  # create a copy and modify it
            base_src_list.append(_remove_file(data.attrib['url']))
        elif data.tag == "download":
            base_url = ""
            if len(base_src_list) > 0:
                base_url = base_src_list[-1] + "/"
            src_path = base_url + _remove_file(data.attrib['url'])
            src_path = normpath(src_path)
            dest_path = _remove_file(self.area.location() + "/" + data.attrib["name"])
            dest_path = normpath(dest_path)
            # Generate directories and copy files
            if isfile(src_path):
                system("cp -pf %s %s" % (src_path, dest_path))
            elif isdir(src_path):
                system("cp -Rpf %s %s" % (src_path, dest_path))
            else:
                logging.warning("Not a file or directory: " + src_path)
        elif data.tag == "root":
            pass  # Do nothing
        else:
            logging.debug("Unknown tag")

        for child in list(data):
            if not self._update_contents(child, base_src_list):
                return False
        return True

    def _process(self):
        confdir = normpath(self.area.config())
        conf = join(confdir, "toolbox", environ["SCRAM_ARCH"])
        toolbox = self.toolbox
        logging.debug("confdir: {0},\n conf: {1}, \n toolbox: {2}".format(confdir, conf, toolbox))
        if isdir(toolbox):
            if isdir(toolbox + "/tools"):
                makedirs(conf + "/tools", mode=0o755, exist_ok=True)
                system("cp -Rpf %s %s" % (toolbox + "/tools/selected", conf + "/tools/selected"))
                system("cp -Rpf %s %s" % (toolbox + "/tools/available", conf + "/tools/available"))
            else:
                die(
                    "Project creating error. Missing directory \"{toolbox}/tools\" in the toolbox."
                    " Please fix file \"{boot}\" and set a valid toolbox directory."
                    .format(toolbox=toolbox, boot=self.file_to_parse)
                )
        else:
            die(
                "Project creating error. Missing directory \"{toolbox}/\". Please fix file \"{boot}\" "
                "and set a valid toolbox directory.".format(toolbox=toolbox, boot=self.file_to_parse)
            )
        self.area.configchksum(self.area.calchksum())
        if not isfile(confdir + "/scram_version"):
            try:
                with open(confdir + "/scram_version", 'w+') as f:
                    f.write(environ["SCRAM_VERSION"] + "\n")
            except IOError:
                die("ERROR: Can not open {confdir}/scram_version file for writing.".format(confdir=confdir))
        self.area.save()
