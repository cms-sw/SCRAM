#!/usr/bin/env python3
import os
import shutil
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from os import environ
environ['SCRAM_ARCH'] = "SCRAM_ARCH"
environ['SCRAM_VERSION'] = "SCRAM_VERSION"
environ['SCRAM_DEBUG'] = "True"

from SCRAM.Configuration.BootStrapProject import BootStrapProject

filename = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'resource', 'CMSSW_bootsrc_2.xml')

os.chdir(os.path.join(os.path.abspath(os.path.dirname(__file__)), "../"))  # go to project root
tools_path = "/tmp/SCRAM_TEST_src/toolbox/tools"

# Cleanup
for path_to_remove in ['/tmp/SCRAM_TEST', '/tmp/SCRAM_TEST_src']:
    try:
        shutil.rmtree(path_to_remove)
    except BaseException:
        pass  # no directory to remove

# Setup
os.makedirs(tools_path + "/selected")
os.makedirs(tools_path + "/available")
with open(tools_path + "/selected/f", 'w') as f:
    f.write("111\n111\n111\n111\n")
with open(tools_path + "/available/f", 'w') as f:
    f.write("111\n111\n111\n111\n")

project = BootStrapProject("/tmp/SCRAM_TEST/path/to/something")
project.boot(filename)
