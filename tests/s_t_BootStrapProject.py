# -*- coding: utf-8 -*-
import os
import sys
import logging

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
from SCRAM.Configuration.BootStrapProject import BootStrapProject
from os import environ

logging.getLogger().setLevel(logging.DEBUG)
environ['SCRAM_ARCH'] = "Placeholder"

print("pwd: " + os.getcwd())
os.chdir("../")
project = BootStrapProject("/tmp/simple/path/to/something")
filename = os.path.join(os.path.dirname(__file__), 'resource', 'CMSSW_bootsrc_2.xml')
project.parse(filename)
