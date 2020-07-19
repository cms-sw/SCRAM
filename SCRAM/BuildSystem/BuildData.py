from os.path import dirname
from os import environ
from SCRAM.BuildSystem import get_safename


class BuildData(object):
    def __init__(self, bf, cdata):
        self.branch = {}
        self.branch["template"] = cdata[0]
        self.branch["name"] = get_safename(cdata[1])
        self.branch["class"] = cdata[0].upper()
        self.branch["safepath"] = get_safename(cdata[1])
        self.branch["classdir"] = cdata[1]
        self.branch["path"] = cdata[1]
        self.branch["parent"] = dirname(cdata[1])[len(environ['SCRAM_SOURCEDIR']) + 1:]
        if bf:
            self.branch["metabf"] = [bf]
        self.branch["suffix"] = cdata[2]
        self.branch["context"] = {}

    def name(self):
        return self.branch['name']

    def variables(self):
        return ""

    def branchdata(self):
        return self.branch

    def parent(self):
        return self.branch['parent']
