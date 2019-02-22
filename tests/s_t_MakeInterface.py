#!/usr/bin/env python3
import os
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from SCRAM.BuildSystem.MakeInterface import MakeInterface
from os import environ

for el in "-f 5 --docs -j -a 10".split(" "):
    sys.argv.append(el)

environ['SCRAM_INTwork'] = "aaaaa"
a = MakeInterface()
a.exec("/tmp/makefile")
