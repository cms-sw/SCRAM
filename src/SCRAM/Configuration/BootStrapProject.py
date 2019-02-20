"""
no need to use parsing call back functions (project, porject_)
use SimpleDoc class
"""
from SCRAM.BuildSystem.SimpleDoc import SimpleDoc
from SCRAM.Configuration.ConfigArea import ConfigArea
import logging
from os import environ
from re import compile
from SCRAM.Utilities.AddDir import adddir, copydir, copyfile, fixpath
from os.path import isdir, isfile

regex_file = compile("^\s*file:")


def _remove_file(str):
    """
    Removes leading space, 'file:' string and surrounding whitespaces
    """
    return regex_file.sub("", str).strip()


class BootStrapProject:

    def __init__(self, baselocation):
        self.area = ConfigArea()  # sets SCRAM_ARCH env variable by default
        self.baselocation = baselocation

    def parse(self, filename):
        parser = SimpleDoc()
        data = parser.parse(filename)
        self._update_contents(data)
        self._process()  # TODO last function to create directories

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
            print("Creating New Project " + name + " Version " + version + "\n\n")  # TODO scramlog
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
            src_path = fixpath(src_path)
            dest_path = _remove_file(self.area.location() + "/" + data.attrib["name"])
            dest_path = fixpath(dest_path)
            # Generate directories and copy files
            # adddir(dest_path)
            logging.debug("Copy from " + "'{0}'".format(src_path) + " to " + "'{0}'".format(dest_path))
            if isfile(src_path):
                copyfile(src_path, dest_path)
            elif isdir(src_path):
                copydir(src_path, dest_path)
            else:
                logging.debug("Not a file or directory")
        elif data.tag == "root":
            pass  # Do nothing
        else:
            logging.debug("Unknown tag")

        for child in list(data):
            if not self._update_contents(child, base_src_list):
                return False
        return True

    def _process(self):
        pass  # todo
