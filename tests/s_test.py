#!/usr/bin/env python3
import sys
sys.path.append("..")
from src.SCRAM.BuildSystem.MakeInterface import MakeInterface
from os import environ

environ['SCRAM_INTwork'] = "aaaaa"
a = MakeInterface()
a.exec("/tmp/makefile")
